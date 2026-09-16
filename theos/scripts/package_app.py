#!/usr/bin/env python3
"""Process the full resource phase, preserve the plist, patch, sign and zip."""
import argparse
import importlib.util
import json
import os
import plistlib
import shlex
import shutil
import subprocess
import zipfile
from pathlib import Path
from generate import OUT, expand, VARIABLE
from xcode_graph import ROOT, actual_path, parse_text

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--app',required=True,type=Path)
    p.add_argument('--ldid',required=True)
    p.add_argument('--resources-only',action='store_true')
    args=p.parse_args()
    target=next(t for t in json.loads((OUT/'manifest.json').read_text())['targets'] if t['instance']=='Telegram')
    settings=dict(target['settings'], EXECUTABLE_NAME='Telegram', PRODUCT_NAME='Telegram')
    source_app=args.app.resolve()
    if not args.resources_only and not (source_app/'Telegram').is_file():raise SystemExit('No linked Telegram executable; packaging refused')
    output=ROOT/'theos/build'
    if os.environ.get('ONEGRAM_ARCH')=='arm64':output=output/'arm64'
    app=source_app if args.resources_only else output/'Payload/Telegram.app'
    if args.resources_only and OUT not in app.parents:raise ValueError('Resource audit must be inside generated/')
    if app.exists():shutil.rmtree(app)
    app.mkdir(parents=True)
    if not args.resources_only:shutil.copy2(source_app/'Telegram',app/'Telegram')
    destinations={}
    partial={}
    for entry in target['resources']:
        if entry['path'] is None:continue
        source=actual_path(ROOT/entry['path'])
        if not source.exists():raise FileNotFoundError(source)
        localization=next((part for part in source.parts if part.endswith('.lproj')),None)
        relative=Path(localization)/source.name if localization else Path(source.name)
        if relative in destinations and destinations[relative]!=source:
            if source.is_dir() or destinations[relative].read_bytes()!=source.read_bytes():
                raise ValueError('Conflicting Xcode resources for '+str(relative))
        destinations[relative]=source
        dest=app/relative
        dest.parent.mkdir(parents=True,exist_ok=True)
        if source.suffix in ('.xib','.storyboard'):
            ibtool=os.environ.get('IBTOOL') or shutil.which('ibtool')
            if not ibtool:raise SystemExit('IBTOOL required for '+str(source))
            subprocess.run([ibtool,'--compile',str(dest.with_suffix('.nib' if source.suffix=='.xib' else '.storyboardc')),str(source)],check=True)
        elif source.suffix=='.strings':
            data=source.read_bytes()
            if data.startswith(b'bplist') or data.lstrip().startswith(b'<?xml'):
                strings=plistlib.loads(data)
            else:
                text=data.decode('utf-16' if data.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
                strings=parse_text('{'+text+'}',allow_duplicates=True)
            dest.write_bytes(plistlib.dumps(strings,fmt=plistlib.FMT_BINARY,sort_keys=False))
        elif source.suffix=='.plist':
            dest.write_bytes(plistlib.dumps(plistlib.loads(source.read_bytes()),fmt=plistlib.FMT_BINARY,sort_keys=False))
        elif source.is_dir():
            shutil.copytree(source,dest,dirs_exist_ok=True,
                            ignore=shutil.ignore_patterns('.DS_Store','CVS','.svn','.git','.hg'))
        else:shutil.copy2(source,dest)
    plist=plistlib.loads((ROOT/settings['INFOPLIST_FILE']).read_bytes())
    def resolve(value):
        if isinstance(value,str):
            result=expand(value,settings)
            if VARIABLE.search(result):raise ValueError('Unresolved Info.plist variable: '+result)
            return result
        if isinstance(value,list):return [resolve(x) for x in value]
        if isinstance(value,dict):return {k:resolve(v) for k,v in value.items()}
        return value
    plist=resolve(plist)
    plist.update(partial)
    plist['MinimumOSVersion']=settings['IPHONEOS_DEPLOYMENT_TARGET']
    plist['UIDeviceFamily']=[int(x) for x in settings['TARGETED_DEVICE_FAMILY'].split(',')]
    if plist['CFBundleIdentifier']!='dev.IllyaGIF.Onegram' or plist['CFBundleExecutable']!='Telegram':
        raise ValueError('Unexpected application identity')
    (app/'Info.plist').write_bytes(plistlib.dumps(plist,fmt=plistlib.FMT_BINARY,sort_keys=False))
    (app/'PkgInfo').write_bytes((plist['CFBundlePackageType']+plist['CFBundleSignature']).encode())
    if args.resources_only:
        print('Staged complete resource phase and expanded Info.plist: '+str(app))
        return
    if os.environ.get('ONEGRAM_ARCH','armv7')=='armv7':
        subprocess.run(['python3',str(ROOT/'tools/patch_ios7_sdk_version.py'),str(app/'Telegram')],check=True)
    entitlement=settings.get('CODE_SIGN_ENTITLEMENTS','') or 'theos/Telegram.entitlements'
    signing_flag='-S'
    if entitlement:
        original=plistlib.loads((ROOT/entitlement).read_bytes())
        processed=resolve(original)
        path=OUT/'signing.entitlements'
        path.write_bytes(plistlib.dumps(processed))
        signing_flag+=''+str(path)
    subprocess.run(shlex.split(args.ldid)+[signing_flag,str(app/'Telegram')],check=True)
    ipa=app.parents[1]/'Onegram.ipa'
    with zipfile.ZipFile(ipa,'w',zipfile.ZIP_DEFLATED) as z:
        for path in sorted(app.rglob('*')):
            if path.is_file():z.write(path,path.relative_to(app.parents[1]))
    print('Created '+str(app)+' and '+str(ipa))

if __name__=='__main__':main()
