#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path

from generate import OUT
from xcode_graph import ROOT


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sdk', required=True, type=Path)
    parser.add_argument('--toolchain', required=True, type=Path)
    parser.add_argument('--deployment', required=True)
    args = parser.parse_args()
    if sys.platform == 'darwin':
        def find_tool(name):
            return subprocess.check_output(['xcrun', '--find', name], text=True).strip()
        clang = find_tool('clang')
        libtool = find_tool('libtool')
        lipo = find_tool('lipo')
    else:
        tools = args.toolchain / 'bin'
        clang = str(tools / 'clang')
        libtool = str(tools / 'libtool')
        lipo = str(tools / 'lipo')
    pst = ROOT / 'thirdparty/PSTCollectionView'
    if "s.source_files = 'PSTCollectionView/'" not in (pst / 'PSTCollectionView.podspec').read_text():
        raise SystemExit('PSTCollectionView source specification changed')
    products = OUT / 'products'
    products.mkdir(parents=True, exist_ok=True)
    archive = products / 'libPSTCollectionView.a'
    sources = sorted((pst / 'PSTCollectionView').glob('*.m'))
    release_logging = ROOT / 'OnegramRuntime/OGReleaseLogging.h'
    inputs = sources + sorted((pst / 'PSTCollectionView').glob('*.h')) + [Path(__file__), release_logging]
    newest = max(path.stat().st_mtime for path in inputs)
    if archive.is_file() and archive.stat().st_mtime >= newest:
        return
    output = OUT / 'pst-armv7'
    output.mkdir(parents=True, exist_ok=True)
    compiler = [clang, '-arch', 'armv7', '-isysroot', str(args.sdk), '-miphoneos-version-min=' + args.deployment,
                '-fobjc-arc', '-std=gnu99', '-Os', '-Wno-everything', '-include', str(release_logging)]
    if sys.platform != 'darwin':
        compiler += ['-target', 'armv7-apple-ios' + args.deployment]
    objects = []
    for source in sources:
        obj = output / (source.stem + '.o')
        subprocess.run(compiler + ['-c', str(source), '-o', str(obj)], check=True)
        objects.append(str(obj))
    subprocess.run([libtool, '-static', '-o', str(archive)] + objects, check=True)
    subprocess.run([lipo, str(archive), '-verify_arch', 'armv7'], check=True)
    print('Built ' + str(archive))


if __name__ == '__main__':
    main()
