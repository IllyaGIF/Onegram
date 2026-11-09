#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path

from generate import OUT
from toolchain_flags import codegen_flags
from xcode_graph import ROOT
from build_pst import build_pst
from build_webp_demux import build_webp_demux, plugins_enabled


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sdk', required=True, type=Path)
    parser.add_argument('--toolchain', required=True, type=Path)
    parser.add_argument('--deployment', required=True)
    args = parser.parse_args()
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
    diagnostics_logging = ROOT / 'OnegramRuntime/OGDiagnosticsLogging.h'
    inputs = sorted((pst / 'PSTCollectionView').glob('*.h')) + [diagnostics_logging, pst / 'PSTCollectionView.podspec']
    output = OUT / 'pst-armv7'
    output.mkdir(parents=True, exist_ok=True)
    compiler = [clang, '-arch', 'armv7', '-isysroot', str(args.sdk), '-miphoneos-version-min=' + args.deployment,
                '-fobjc-arc', '-std=gnu99', '-Os', '-Wno-everything', '-include', str(diagnostics_logging)]
    compiler += ['-target', 'armv7-apple-ios' + args.deployment] + codegen_flags('armv7')
    build_pst(sources, compiler, libtool, lipo, 'armv7', archive, output, inputs)
    if plugins_enabled():
        build_webp_demux(OUT, [clang, '-arch', 'armv7', '-isysroot', str(args.sdk), '-miphoneos-version-min=' + args.deployment,
                               '-target', 'armv7-apple-ios' + args.deployment] + codegen_flags('armv7'),
                         libtool, lipo, 'armv7')


if __name__ == '__main__':
    main()
