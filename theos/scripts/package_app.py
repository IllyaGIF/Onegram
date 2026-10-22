#!/usr/bin/env python3
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
from build_identity import write_build_identity
from artifact_cache import cache_matches, cache_record, fingerprint
from app_signing import sign_app, verify_app, verify_ipa

STARTUP_LOCALIZATION_KEYS = (
    'Contacts.TabTitle',
    'DialogList.TabTitle',
    'Settings.TabTitle',
    'Calls.TabTitle',
    'DialogList.Title',
    'DialogList.SearchLabel',
    'Common.Back',
    'Common.Edit',
    'Common.Done',
    'Common.OK',
    'DialogList.PinLimitError',
    'DialogList.SavedMessages',
    'DialogList.SavedMessagesHelp',
    'DialogList.You',
    'Message.ImageExpired',
    'Message.Photo',
    'Message.VideoExpired',
    'Message.VideoMessage',
    'Message.Video',
    'Message.LiveLocation',
    'Message.Location',
    'Message.Contact',
    'Message.Sticker',
    'Message.Animation',
    'Message.Audio',
    'Message.File',
    'DialogList.AwaitingEncryption',
    'DialogList.EncryptionProcessing',
    'DialogList.EncryptionRejected',
    'DialogList.EncryptedChatStartedOutgoing',
    'DialogList.EncryptedChatStartedIncoming',
)

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--app',required=True,type=Path)
    p.add_argument('--ldid',required=True)
    p.add_argument('--resources-only',action='store_true')
    p.add_argument('--stage-only',action='store_true')
    args=p.parse_args()
    target=next(t for t in json.loads((OUT/'manifest.json').read_text())['targets'] if t['instance']=='Telegram')
    settings=dict(target['settings'], EXECUTABLE_NAME='Telegram', PRODUCT_NAME='Telegram')
    source_app=args.app.resolve()
    if not args.resources_only and not (source_app/'Telegram').is_file():raise SystemExit('No linked Telegram executable; packaging refused')
    arch=os.environ.get('ONEGRAM_ARCH','armv7')
    output=ROOT/'theos/build'
    if arch!='armv7':output=output/arch
    app=source_app if args.resources_only else output/'Payload/Telegram.app'
    if args.resources_only and OUT not in app.parents:raise ValueError('Resource audit must be inside generated/')
    ipa=output/'Onegram.ipa'
    state=OUT/'package-state.json'
    entitlement=settings.get('CODE_SIGN_ENTITLEMENTS','') or 'theos/Telegram.entitlements'
    package_outputs=[app] + ([OUT/'signing.entitlements'] if entitlement else [])
    def finish_package():
        verify_app(app, OUT/'signing.entitlements' if entitlement else None)
        if args.stage_only:
            print('Staged '+str(app))
            return
        zip_state=OUT/'ipa-state.json'
        zip_signature=fingerprint([app,Path(__file__)])
        needs_archive=not cache_matches(zip_state,zip_signature,[ipa])
        if needs_archive:
            with zipfile.ZipFile(ipa,'w',zipfile.ZIP_DEFLATED) as z:
                for path in sorted(app.rglob('*')):
                    if path.is_file():z.write(path,path.relative_to(output))
        verify_ipa(ipa, OUT/'signing.entitlements' if entitlement else None)
        if needs_archive:
            cache_record(zip_state,zip_signature,[ipa])
        print('IPA ready: '+str(ipa))
    if not args.resources_only:
        inputs=[source_app/'Telegram',ROOT/settings['INFOPLIST_FILE'],
                ROOT/'thirdparty/quirc/LICENSE',ROOT/'OnegramDante/LICENSE.Monocypher',
                Path(__file__),ROOT/'theos/scripts/generate.py',ROOT/'theos/scripts/xcode_graph.py',
                ROOT/'theos/scripts/build_identity.py',ROOT/'theos/scripts/artifact_cache.py',
                ROOT/'theos/scripts/app_signing.py',
                ROOT/'tools/patch_ios7_sdk_version.py',
                Path(shutil.which(shlex.split(args.ldid)[0]) or shlex.split(args.ldid)[0])]
        inputs += [actual_path(ROOT/entry['path']) for entry in target['resources'] if entry['path'] is not None]
        if entitlement:inputs.append(ROOT/entitlement)
        signature=fingerprint(inputs,values=[settings,target['resources'],arch,args.ldid,
                                            os.environ.get('ONEGRAM_DEPLOYMENT'),os.environ.get('ONEGRAM_DIAGNOSTICS')=='1',
                                            os.environ.get('IBTOOL')])
        if cache_matches(state,signature,package_outputs):
            finish_package()
            return
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
            if source.name == 'Localizable.strings' and localization is not None:
                startup_strings = {key: strings[key] for key in STARTUP_LOCALIZATION_KEYS if key in strings}
                (dest.parent/'OnegramStartup.strings').write_bytes(plistlib.dumps(startup_strings,fmt=plistlib.FMT_BINARY,sort_keys=False))
                startup_lines = []
                for key, value in startup_strings.items():
                    if '\n' in value or '\r' in value or '\t' in value:
                        raise ValueError('Unsupported startup localization value for '+key)
                    startup_lines.append(key+'\t'+value)
                (dest.parent/'OnegramStartup.txt').write_text('\n'.join(startup_lines)+'\n', encoding='utf-8')
        elif source.suffix=='.plist':
            dest.write_bytes(plistlib.dumps(plistlib.loads(source.read_bytes()),fmt=plistlib.FMT_BINARY,sort_keys=False))
        elif source.is_dir():
            shutil.copytree(source,dest,dirs_exist_ok=True,
                            ignore=shutil.ignore_patterns('.DS_Store','CVS','.svn','.git','.hg'))
        else:shutil.copy2(source,dest)
    licenses=app/'Licenses'
    licenses.mkdir(exist_ok=True)
    for source,name in ((ROOT/'thirdparty/quirc/LICENSE','LICENSE.quirc'),
                        (ROOT/'OnegramDante/LICENSE.Monocypher','LICENSE.Monocypher')):
        shutil.copy2(source,licenses/name)
    for lproj in app.glob('*.lproj'):
        source_strings=lproj/'Localizable.strings'
        if not source_strings.is_file():
            continue
        data=source_strings.read_bytes()
        if data.startswith(b'bplist') or data.lstrip().startswith(b'<?xml'):
            strings=plistlib.loads(data)
        else:
            text=data.decode('utf-16' if data.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
            strings=parse_text('{'+text+'}',allow_duplicates=True)
        startup_strings={key:strings[key] for key in STARTUP_LOCALIZATION_KEYS if key in strings}
        (lproj/'OnegramStartup.strings').write_bytes(plistlib.dumps(startup_strings,fmt=plistlib.FMT_BINARY,sort_keys=False))
        startup_lines=[]
        for key,value in startup_strings.items():
            if '\n' in value or '\r' in value or '\t' in value:
                raise ValueError('Unsupported startup localization value for '+key)
            startup_lines.append(key+'\t'+value)
        (lproj/'OnegramStartup.txt').write_text('\n'.join(startup_lines)+'\n',encoding='utf-8')
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
    plist['MinimumOSVersion']=os.environ.get('ONEGRAM_DEPLOYMENT',settings['IPHONEOS_DEPLOYMENT_TARGET'])
    plist['UIDeviceFamily']=[int(x) for x in settings['TARGETED_DEVICE_FAMILY'].split(',')]
    if arch=='armv6':plist.pop('UIRequiredDeviceCapabilities',None)
    if plist['CFBundleIdentifier']!='dev.IllyaGIF.Onegram' or plist['CFBundleExecutable']!='Telegram':
        raise ValueError('Unexpected application identity')
    (app/'Info.plist').write_bytes(plistlib.dumps(plist,fmt=plistlib.FMT_BINARY,sort_keys=False))
    (app/'PkgInfo').write_bytes((plist['CFBundlePackageType']+plist['CFBundleSignature']).encode())
    if args.resources_only:
        print('Staged complete resource phase and expanded Info.plist: '+str(app))
        return
    if os.environ.get('ONEGRAM_ARCH','armv7')=='armv7':
        subprocess.run(['python3',str(ROOT/'tools/patch_ios7_sdk_version.py'),str(app/'Telegram')],check=True)
    build_identifier = write_build_identity(app, arch, os.environ.get('ONEGRAM_DIAGNOSTICS') == '1')
    signing_entitlements=None
    if entitlement:
        original=plistlib.loads((ROOT/entitlement).read_bytes())
        processed=resolve(original)
        path=OUT/'signing.entitlements'
        path.write_bytes(plistlib.dumps(processed))
        signing_entitlements=path
    sign_app(app,args.ldid,signing_entitlements)
    cache_record(state,signature,package_outputs)
    finish_package()

if __name__=='__main__':main()
