#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from bootstrap_build import download, safe_unpack, validate_sha256

REVISION = 'df82634ce7c3eddba9722e881433fbe357396e16'
ARCHIVE_SHA256 = 'f137bf519be7f08303923b28bdc0fdfd87ca0533e15ad9050eedda2f6d59b420'

def ensure_linux_linker(toolchain, jobs=4):
    root = toolchain / '.onegram-linker'
    marker = root / 'installed.json'
    binary = toolchain / 'bin/ld'
    recipe = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    if marker.is_file() and binary.is_file():
        try:
            data = json.loads(marker.read_text())
            if data.get('recipe') == recipe and data.get('binary') == hashlib.sha256(binary.read_bytes()).hexdigest():
                return
        except (OSError, ValueError):
            pass
    root.mkdir(parents=True, exist_ok=True)
    archive = root / 'cctools.tar.gz'
    if not archive.is_file():
        download('https://codeload.github.com/tpoechtrager/cctools-port/tar.gz/' + REVISION, archive)
    validate_sha256(archive, ARCHIVE_SHA256)
    checkout = root / ('cctools-port-' + REVISION)
    if not checkout.is_dir():
        safe_unpack(archive, root)
    source = checkout / 'cctools'
    objc = source / 'ld64/src/ld/passes/objc.cpp'
    original = 'return strcmp(left->name(), right->name());'
    corrected = 'return strcmp(left->name(), right->name()) < 0;'
    contents = objc.read_text()
    if original in contents:
        if contents.count(original) != 1:
            raise RuntimeError('Unexpected ld64 Objective-C comparator source')
        objc.write_text(contents.replace(original, corrected, 1))
    elif corrected not in contents:
        raise RuntimeError('ld64 Objective-C comparator was not found')
    cc = shutil.which('clang')
    cxx = shutil.which('clang++')
    llvm_config = shutil.which('llvm-config')
    if cc is None or cxx is None or llvm_config is None:
        raise RuntimeError('Native clang, clang++ and LLVM development tools are required to build the linker')
    env = os.environ.copy()
    for variable in ('MAKEFLAGS', 'GNUMAKEFLAGS', 'MFLAGS', 'MAKELEVEL', 'MAKE', 'CFLAGS', 'CXXFLAGS', 'CPPFLAGS', 'LDFLAGS', 'LIBS', 'LD', 'AR', 'RANLIB'):
        env.pop(variable, None)
    env.update(CC=cc, CXX=cxx, CFLAGS='-O2', CXXFLAGS='-O2 -include cstdint',
               LDFLAGS='-Wl,--allow-shlib-undefined', CCACHE_DIR=str(root/'ccache'))
    log = root / 'build.log'
    commands = [
        ['bash', str(source / 'autogen.sh')],
        [str(source / 'configure'), '--target=arm-apple-darwin11',
         '--with-libtapi=' + str(toolchain),
         '--with-llvm-config=' + llvm_config],
        ['make', '-C', 'ld64', '-j' + str(max(1, jobs))]
    ]
    print('[Onegram setup] Building corrected Linux iOS linker', flush=True)
    with log.open('w') as output:
        for command in commands:
            result = subprocess.run(command, cwd=source, env=env, stdout=output, stderr=subprocess.STDOUT)
            if result.returncode:
                raise RuntimeError('Linker preparation failed; full log: ' + str(log))
    configuration = (source / 'Makefile').read_text()
    if 'TAPI_DEF = -DTAPI_SUPPORT' not in configuration or 'LTO_DEF = -DLTO_SUPPORT' not in configuration:
        raise RuntimeError('Corrected linker must retain TAPI and LTO support; log: ' + str(log))
    built = source / 'ld64/src/ld/ld'
    if not built.is_file():
        raise RuntimeError('Corrected linker was not produced; log: ' + str(log))
    staged = toolchain / 'bin/onegram-ld-install'
    shutil.copy2(built, staged)
    os.replace(staged, binary)
    marker.write_text(json.dumps({'recipe': recipe, 'binary': hashlib.sha256(binary.read_bytes()).hexdigest()}, sort_keys=True) + '\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--toolchain', type=Path, required=True)
    parser.add_argument('--jobs', type=int, default=4)
    args = parser.parse_args()
    try:
        ensure_linux_linker(args.toolchain.resolve(), args.jobs)
    except (OSError, RuntimeError) as error:
        print('[Onegram setup] ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
