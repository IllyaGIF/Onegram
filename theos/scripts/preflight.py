#!/usr/bin/env python3
"""Report unavailable exact-build prerequisites without substituting them."""
import argparse
import os
import subprocess
import sys
from pathlib import Path

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--toolchain',required=True,type=Path)
    p.add_argument('--sdk',required=True,type=Path)
    p.add_argument('--arclite',type=Path)
    p.add_argument('--compiler-rt',required=True,type=Path)
    args=p.parse_args()
    if os.environ.get('ONEGRAM_ARCH') == 'arm64':
        for relative in ['usr/lib/libstdc++.tbd','usr/include/c++/4.2.1/vector']:
            if not (args.sdk/relative).is_file():raise SystemExit('Missing arm64 SDK input: '+relative)
        print('arm64 SDK inputs: OK')
        return 0
    missing=[]
    arclite=args.arclite or args.toolchain/'usr/lib/arc/libarclite_iphoneos.a'
    for path in (args.sdk/'usr/lib/libstdc++.dylib',arclite,args.compiler_rt):
        if not path.is_file():missing.append(str(path))
    for value in missing:print('Unavailable: '+value)
    if missing:return 1
    for archive in (arclite,args.compiler_rt):
        subprocess.run([str(args.toolchain/'bin/lipo'),str(archive),'-verify_arch','armv7'],check=True)
        print('Runtime armv7: '+str(archive))
    symbols=subprocess.run([str(args.toolchain/'bin/nm'),'-arch','armv7','-g',str(args.compiler_rt)],check=True,capture_output=True,text=True).stdout
    defined={line.split()[-1] for line in symbols.splitlines() if len(line.split())>=3 and line.split()[-2]!='U'}
    for symbol in ('___divmodsi4','___udivmodsi4'):
        if symbol not in defined:raise SystemExit('Compiler runtime lacks '+symbol)
    print('Legacy SDK and runtime inputs: OK')
    return 0

if __name__=='__main__':sys.exit(main())
