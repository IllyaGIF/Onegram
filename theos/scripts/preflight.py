#!/usr/bin/env python3
import argparse
import json
import os
import plistlib
import subprocess
import sys
from pathlib import Path

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--toolchain',required=True,type=Path)
    p.add_argument('--sdk',required=True,type=Path)
    p.add_argument('--sdk-version',required=True)
    p.add_argument('--arclite',type=Path)
    p.add_argument('--compiler-rt',required=True,type=Path)
    args=p.parse_args()
    if os.environ.get('ONEGRAM_ARCH') == 'arm64':
        for relative in ['usr/lib/libstdc++.tbd','usr/include/c++/4.2.1/vector']:
            if not (args.sdk/relative).is_file():raise SystemExit('Missing arm64 SDK input: '+relative)
        metadata=args.sdk/'SDKSettings.json'
        if metadata.is_file():
            try:data=json.loads(metadata.read_text())
            except Exception as exc:raise SystemExit('Invalid arm64 SDK metadata: '+str(exc))
            if str(data.get('Version',''))!=args.sdk_version:
                raise SystemExit('arm64 SDK metadata version is '+str(data.get('Version'))+', expected '+args.sdk_version)
        else:
            legacy={}
            legacy_path=args.sdk/'SDKSettings.plist'
            if legacy_path.is_file():
                try:legacy=plistlib.loads(legacy_path.read_bytes())
                except Exception as exc:raise SystemExit('Invalid SDKSettings.plist: '+str(exc))
            def text(key,fallback):
                value=legacy.get(key)
                return str(value) if isinstance(value,(str,int,float)) else fallback
            version=text('Version',args.sdk_version)
            canonical=text('CanonicalName','iphoneos'+version)
            if canonical.lower()=='iphoneos':canonical+=''+version
            data={
                'CanonicalName':canonical,
                'DefaultDeploymentTarget':text('DefaultDeploymentTarget',version),
                'DisplayName':text('DisplayName','iOS '+version),
                'MaximumDeploymentTarget':text('MaximumDeploymentTarget',version),
                'Version':version
            }
            if version!=args.sdk_version:
                raise SystemExit('SDKSettings.plist version is '+version+', expected '+args.sdk_version)
            try:metadata.write_text(json.dumps(data,indent=2,sort_keys=True)+'\n')
            except OSError as exc:raise SystemExit('Unable to write '+str(metadata)+': '+str(exc))
            print('Generated clang SDK metadata: '+str(metadata))
        print('arm64 SDK inputs: OK')
        return 0
    arch=os.environ.get('ONEGRAM_ARCH','armv7')
    missing=[]
    arclite=args.arclite or args.toolchain/'usr/lib/arc/libarclite_iphoneos.a'
    stdlib_candidates=[args.sdk/'usr/lib/libstdc++.dylib',args.sdk/'usr/lib/libstdc++.6.dylib',args.sdk/'usr/lib/libstdc++.6.0.9.dylib']
    stdlib=next((path for path in stdlib_candidates if path.is_file()),stdlib_candidates[0])
    runtime_paths=[stdlib,arclite,args.compiler_rt]
    if arch=='armv6':
        runtime_paths += [Path(__file__).resolve().parents[1]/'generated/armv6/products/libdispatch.a',
                          Path(__file__).resolve().parents[1]/'generated/armv6/products/libopus.a',
                          Path(__file__).resolve().parents[1]/'generated/armv6/products/libWebP.a',
                          Path(__file__).resolve().parents[1]/'generated/armv6/products/libssl.a',
                          Path(__file__).resolve().parents[1]/'generated/armv6/products/libcrypto.a',
                          Path(__file__).resolve().parents[1]/'generated/armv6/products/libPSTCollectionView.a']
    for path in runtime_paths:
        if not path.is_file():missing.append(str(path))
    for value in missing:print('Unavailable: '+value)
    if missing:return 1
    lipo=str(args.toolchain/'bin/lipo')
    nm=str(args.toolchain/'bin/nm')
    for archive in runtime_paths:
        subprocess.run([lipo,str(archive),'-verify_arch',arch],check=True)
        print('Runtime '+arch+': '+str(archive))
    symbols=subprocess.run([nm,'-arch',arch,'-g',str(args.compiler_rt)],check=True,capture_output=True,text=True).stdout
    defined={line.split()[-1] for line in symbols.splitlines() if len(line.split())>=3 and line.split()[-2]!='U'}
    for symbol in ('___divmodsi4','___udivmodsi4'):
        if symbol not in defined:raise SystemExit('Compiler runtime lacks '+symbol)
    if arch=='armv6':
        metadata=args.sdk/'SDKSettings.plist'
        if metadata.is_file():
            data=plistlib.loads(metadata.read_bytes())
            version=str(data.get('Version',''))
            if version and version!=args.sdk_version:raise SystemExit('armv6 SDK version is '+version+', expected '+args.sdk_version)
        system=args.sdk/'usr/lib/libSystem.dylib'
        if not system.is_file():raise SystemExit('Missing iOS 3.1.3 libSystem.dylib')
        subprocess.run([lipo,str(system),'-verify_arch','armv6'],check=True)
    print('Legacy SDK and runtime inputs: OK')
    return 0

if __name__=='__main__':sys.exit(main())
