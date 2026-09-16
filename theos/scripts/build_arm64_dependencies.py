#!/usr/bin/env python3
import argparse
import hashlib
import os
from pathlib import Path
import shlex
import subprocess
import tarfile
import urllib.request
from generate import OUT
from xcode_graph import ROOT


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sdk', required=True, type=Path)
    parser.add_argument('--toolchain', required=True, type=Path)
    args = parser.parse_args()
    tools = args.toolchain / 'bin'
    sources = OUT / 'dependency-sources'
    sources.mkdir(parents=True, exist_ok=True)
    archive = sources / 'openssl-1.0.2h.tar.gz'
    if not archive.exists():
        urllib.request.urlretrieve('https://codeload.github.com/openssl/openssl/tar.gz/refs/tags/OpenSSL_1_0_2h', archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != '2cadf888883690320fb638b651ee4d1cf90ec656a0e3b89ba3419592c2080e9f':
        raise SystemExit('OpenSSL source checksum mismatch')
    openssl = sources / 'openssl-OpenSSL_1_0_2h'
    if not openssl.exists():
        with tarfile.open(archive) as package:
            package.extractall(sources, filter='data')
    configure = openssl / 'Configure'
    text = configure.read_text(encoding="latin-1")
    for before, after in [('rename($Makefile,"$Makefile.bak")', 'unlink($Makefile)'),
                          ('rename("crypto/opensslconf.h","crypto/opensslconf.h.bak")', 'unlink("crypto/opensslconf.h")'),
                          ('rename($f,"$f.bak")', 'unlink($f)')]:
        text = text.replace(before, after)
    configure.write_text(text, encoding="latin-1")
    compiler = [str(tools / 'clang'), '-target', 'arm64-apple-ios7.0', '-isysroot', str(args.sdk)]
    products = OUT / 'products'
    products.mkdir(parents=True, exist_ok=True)
    signature = hashlib.sha256((str(args) + Path(__file__).read_text()).encode()).hexdigest()
    stamp = openssl / 'onegram-signature'
    if not stamp.exists() or stamp.read_text() != signature:
        for name in ('libssl.a', 'libcrypto.a'):
            (openssl / name).unlink(missing_ok=True)
        subprocess.run(['perl', 'Configure', 'BSD-generic64', 'no-shared', 'no-asm'], cwd=openssl, check=True)
        subprocess.run(['make', '-j4', 'build_libs', 'CC=' + shlex.join(compiler),
                        'AR=' + str(tools / 'llvm-ar') + ' --format=darwin r', 'RANLIB=' + str(tools / 'ranlib')], cwd=openssl, check=True)
        stamp.write_text(signature)
    for name in ('libssl.a', 'libcrypto.a'):
        subprocess.run([str(tools / 'llvm-ar'), '--format=darwin', 's', str(openssl / name)], check=True)
        destination = products / name
        if not destination.exists():
            destination.symlink_to(os.path.relpath(openssl / name, products))
        subprocess.run([str(tools / 'lipo'), str(destination), '-verify_arch', 'arm64'], check=True)
    pst = ROOT / 'thirdparty/PSTCollectionView'
    if "s.source_files = 'PSTCollectionView/'" not in (pst / 'PSTCollectionView.podspec').read_text():
        raise SystemExit('PSTCollectionView source specification changed')
    objects = []
    output = OUT / 'pst'
    output.mkdir(parents=True, exist_ok=True)
    for source in sorted((pst / 'PSTCollectionView').glob('*.m')):
        obj = output / (source.stem + '.o')
        subprocess.run(compiler + ['-fobjc-arc', '-std=gnu99', '-Os', '-c', str(source), '-o', str(obj)], check=True)
        objects.append(str(obj))
    subprocess.run([str(tools / 'libtool'), '-static', '-o', str(products / 'libPSTCollectionView.a')] + objects, check=True)


if __name__ == '__main__':
    main()
