#!/usr/bin/env python3
import sys
"""Inspect the completed application and optionally compare a known build."""
import argparse
import os
import json
import re
import subprocess
from pathlib import Path
from generate import OUT

def main():
    p=argparse.ArgumentParser()
    p.add_argument('binary',type=Path)
    p.add_argument('--reference',type=Path)
    p.add_argument('--tools',type=Path,default=Path.home()/'theos/toolchain/linux/iphone/bin')
    args=p.parse_args()
    if not args.binary.is_file():raise SystemExit('Theos executable does not exist: '+str(args.binary))
    reports=OUT/'verification'
    reports.mkdir(parents=True,exist_ok=True)
    def inspect(path,label):
        result={}
        for tool,flags in [('file',[]),('lipo',['-info']),('otool',['-L']),('otool',['-l']),('nm',[]),('size',[])]:
            if tool == 'file':
                command='file'
            elif sys.platform == 'darwin':
                command=subprocess.check_output(['xcrun','--find',tool],text=True).strip()
            else:
                command=str(args.tools/tool)
            cmd=[command]+flags+[str(path)]
            output=subprocess.run(cmd,check=True,capture_output=True,text=True).stdout
            key=tool+''.join(flags)
            result[key]=output
            (reports/(label+'-'+key+'.txt')).write_text(output)
        return result
    actual=inspect(args.binary,'theos')
    print(actual['file']+actual['lipo-info'])
    arch=os.environ.get('ONEGRAM_ARCH','armv7')
    if 'Non-fat file:' not in actual['lipo-info'] or 'architecture: '+arch not in actual['lipo-info']:
        raise SystemExit('Expected a thin '+arch+' executable')
    minimum=r'7\.0' if arch=='arm64' else r'4\.3'
    sdk=r'11\.2' if arch=='arm64' else r'7\.0'
    if not re.search(r'LC_VERSION_MIN_IPHONEOS\s+cmdsize 16\s+version '+minimum+r'\s+sdk '+sdk,actual['otool-l']):
        raise SystemExit('Deployment or SDK marker differs from legacy Xcode output')
    if arch == 'arm64':
        native_classes = {'NSURLSession', 'NSURLSessionConfiguration', 'NSURLSessionTask',
                          'NSURLSessionDataTask', 'WKWebView', 'WKWebViewConfiguration',
                          'PHAsset', 'PHImageManager', 'PHPhotoLibrary', 'CNContactFormatter',
                          'CNMutableContact', 'UIImpactFeedbackGenerator'}
        definitions = {line.split()[-1] for line in actual['nm'].splitlines()
                       if len(line.split()) >= 3 and line.split()[-2] != 'U'}
        collisions = sorted(name for name in native_classes if '_OBJC_CLASS_$_' + name in definitions)
        if collisions:
            raise SystemExit('Application redefines native classes: ' + ', '.join(collisions))
        if '/usr/lib/libstdc++.6.dylib' not in actual['otool-L'] or '/usr/lib/libc++.' in actual['otool-L']:
            raise SystemExit('Unexpected arm64 C++ runtime')
        print('Native class definitions and libstdc++: OK')
    if args.reference:
        reference=inspect(args.reference,'reference')
        def libraries(report):return {line.strip() for line in report['otool-L'].splitlines()[1:]}
        print('Additional link commands:',sorted(libraries(actual)-libraries(reference)))
        print('Missing link commands:',sorted(libraries(reference)-libraries(actual)))
    print('Reports: '+str(reports))

if __name__=='__main__':main()
