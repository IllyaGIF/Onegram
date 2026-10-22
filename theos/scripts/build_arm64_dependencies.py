#!/usr/bin/env python3
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import urllib.request
from generate import OUT
from xcode_graph import ROOT
from build_pst import build_pst


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sdk', required=True, type=Path)
    parser.add_argument('--toolchain', required=True, type=Path)
    args = parser.parse_args()
    tools = args.toolchain / 'bin'
    make_env = os.environ.copy()
    for name in ('MAKEFLAGS', 'GNUMAKEFLAGS', 'MFLAGS', 'MAKELEVEL', 'MAKE'):
        make_env.pop(name, None)
    if sys.platform == 'darwin':
        def find_tool(name):
            return str(tools / name)
        clang = find_tool('clang')
        archive_tool = find_tool('ar')
        ranlib = find_tool('ranlib')
        libtool = find_tool('libtool')
        lipo = find_tool('lipo')
        archive_command = archive_tool + ' r'
    else:
        clang = str(tools / 'clang')
        archive_tool = str(tools / 'llvm-ar')
        ranlib = str(tools / 'ranlib')
        libtool = str(tools / 'libtool')
        lipo = str(tools / 'lipo')
        archive_command = archive_tool + ' --format=darwin r'
    sources = OUT / 'dependency-sources'
    sources.mkdir(parents=True, exist_ok=True)
    archive = sources / 'openssl-1.0.2h.tar.gz'
    if not archive.exists():
        urllib.request.urlretrieve('https://codeload.github.com/openssl/openssl/tar.gz/refs/tags/OpenSSL_1_0_2h', archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != '2cadf888883690320fb638b651ee4d1cf90ec656a0e3b89ba3419592c2080e9f':
        raise SystemExit('OpenSSL source checksum mismatch')
    openssl = sources / 'openssl-OpenSSL_1_0_2h'

    def prepare_openssl():
        if openssl.exists():
            shutil.rmtree(openssl)
        with tarfile.open(archive) as package:
            package.extractall(sources, filter='data')
        configure = openssl / 'Configure'
        text = configure.read_text(encoding="latin-1")
        for before, after in [('rename($Makefile,"$Makefile.bak")', 'unlink($Makefile)'),
                              ('rename("crypto/opensslconf.h","crypto/opensslconf.h.bak")', 'unlink("crypto/opensslconf.h")'),
                              ('rename($f,"$f.bak")', 'unlink($f)')]:
            text = text.replace(before, after)
        lines = text.splitlines()
        if not any(line.startswith('"ios64-cross","') for line in lines):
            for index, line in enumerate(lines):
                if line.startswith('"iphoneos-cross","'):
                    lines.insert(index + 1, (
                        '"ios64-cross","' + clang +
                        ':-O3 -target arm64-apple-ios7.0 -isysroot ' + str(args.sdk) +
                        ' -fno-common::-D_REENTRANT:iOS:-Wl,-search_paths_first%:'
                        'SIXTY_FOUR_BIT_LONG RC4_CHAR -RC4_CHUNK DES_INT DES_UNROLL -BF_PTR:'
                        '${no_asm}:dlfcn:darwin-shared:-fPIC -fno-common:-dynamiclib:.'
                        r'\$(SHLIB_MAJOR).\$(SHLIB_MINOR).dylib",'
                    ))
                    break
            else:
                raise SystemExit('OpenSSL iphoneos-cross target not found')
        text = '\n'.join(lines) + '\n'
        configure.write_text(text, encoding="latin-1")
        makefile_org = openssl / 'Makefile.org'
        makefile_org_text = makefile_org.read_text(encoding="latin-1")
        marker = 'build_libs: build_libcrypto build_libssl openssl.pc\n'
        phony = '.PHONY: build_libs build_libcrypto build_libssl build_crypto build_ssl build_engines\n\n'
        if marker not in makefile_org_text:
            raise SystemExit('OpenSSL build_libs target not found')
        if phony not in makefile_org_text:
            makefile_org_text = makefile_org_text.replace(marker, phony + marker, 1)
        makefile_org.write_text(makefile_org_text, encoding="latin-1")

    compiler = [clang, '-target', 'arm64-apple-ios7.0', '-isysroot', str(args.sdk)]
    products = OUT / 'products'
    products.mkdir(parents=True, exist_ok=True)
    signature = hashlib.sha256((str(args) + Path(__file__).read_text()).encode()).hexdigest()
    stamp = openssl / 'onegram-signature'
    rebuilt = not stamp.exists() or stamp.read_text() != signature or any(not (openssl / name).is_file() for name in ('libssl.a', 'libcrypto.a'))
    if rebuilt:
        prepare_openssl()
        stamp = openssl / 'onegram-signature'
        subprocess.run([
            'perl', 'Configure', 'ios64-cross',
            'no-shared', 'no-asm', 'no-dso', 'no-hw', 'no-engine'
        ], cwd=openssl, check=True, env=make_env)
        makefile = openssl / 'Makefile'
        makefile_text = makefile.read_text()
        required = ('ios64-cross', '-target arm64-apple-ios7.0', '-isysroot')
        if not all(value in makefile_text for value in required):
            raise SystemExit('OpenSSL arm64 iOS configuration was not generated')
        phony_required = '.PHONY: build_libs build_libcrypto build_libssl build_crypto build_ssl build_engines'
        if phony_required not in makefile_text:
            raise SystemExit('OpenSSL build targets were not marked phony')
        make_variables = ['AR=' + archive_command, 'RANLIB=' + ranlib]
        subprocess.run(['make', 'depend'] + make_variables, cwd=openssl, check=True, env=make_env)
        subprocess.run(['make', '-j4', 'build_libs'] + make_variables, cwd=openssl, check=True, env=make_env)
        for name in ('libssl.a', 'libcrypto.a'):
            if not (openssl / name).is_file():
                raise SystemExit('OpenSSL build did not produce ' + name)
        stamp.write_text(signature)
    for name in ('libssl.a', 'libcrypto.a'):
        if rebuilt:
            if sys.platform == 'darwin':
                subprocess.run([ranlib, str(openssl / name)], check=True)
            else:
                subprocess.run([archive_tool, '--format=darwin', 's', str(openssl / name)], check=True)
        destination = products / name
        if destination.is_symlink() and not destination.exists():
            destination.unlink()
        if not destination.exists():
            destination.symlink_to(os.path.relpath(openssl / name, products))
        subprocess.run([lipo, str(destination), '-verify_arch', 'arm64'], check=True)
    pst = ROOT / 'thirdparty/PSTCollectionView'
    if "s.source_files = 'PSTCollectionView/'" not in (pst / 'PSTCollectionView.podspec').read_text():
        raise SystemExit('PSTCollectionView source specification changed')
    output = OUT / 'pst'
    build_pst(sorted((pst / 'PSTCollectionView').glob('*.m')),
              compiler + ['-fobjc-arc', '-std=gnu99', '-Os'], libtool, lipo, 'arm64',
              products / 'libPSTCollectionView.a', output,
              sorted((pst / 'PSTCollectionView').glob('*.h')) + [pst / 'PSTCollectionView.podspec'])


if __name__ == '__main__':
    main()
