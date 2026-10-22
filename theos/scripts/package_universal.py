#!/usr/bin/env python3
import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import shlex
import shutil
import subprocess
import zipfile
from build_identity import write_build_identity
from artifact_cache import cache_matches, cache_record, fingerprint
from app_signing import sign_app, verify_app, verify_ipa

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ldid', required=True)
    parser.add_argument('--toolchain', required=True, type=Path)
    parser.add_argument('--architectures', nargs='+', choices=('armv6', 'armv7', 'arm64'), default=['armv7', 'arm64'])
    args = parser.parse_args()
    architectures = args.architectures
    if architectures not in (['armv7', 'arm64'], ['armv6', 'armv7', 'arm64']):
        parser.error('Expected armv7 arm64 or armv6 armv7 arm64')
    root = Path(__file__).resolve().parents[1]
    apps = {arch: root / 'build' / ('' if arch == 'armv7' else arch) / 'Payload/Telegram.app' for arch in architectures}
    for arch, app in apps.items():
        env = dict(os.environ, ONEGRAM_ARCH=arch, ONEGRAM_GENERATED_DIR='generated' if arch == 'armv7' else 'generated/' + arch)
        subprocess.run(['python3', str(root / 'scripts/verify_binary.py'), str(app / 'Telegram'), '--tools', str(args.toolchain / 'bin')], env=env, check=True)
    triple = 'armv6' in apps
    output = root / ('build/universal3' if triple else 'build/universal')
    app = output / 'Payload/Telegram.app'
    ipa = output / ('Onegram-armv6-armv7-arm64.ipa' if triple else 'Onegram.ipa')
    entitlements = root / 'generated/signing.entitlements'
    lipo = str(args.toolchain / 'bin/lipo')
    inputs = list(apps.values()) + [entitlements, Path(lipo),
             Path(shutil.which(shlex.split(args.ldid)[0]) or shlex.split(args.ldid)[0]),
             Path(__file__), root / 'scripts/build_identity.py', root / 'scripts/artifact_cache.py',
             root / 'scripts/verify_binary.py', root / 'scripts/app_signing.py']
    signature = fingerprint(inputs, values=[architectures, args.ldid])
    stamp = output / 'package-state.json'
    if cache_matches(stamp, signature, [app, ipa]):
        verify_app(app, entitlements)
        verify_ipa(ipa, entitlements)
        print('IPA up to date: ' + str(ipa))
        return
    legacy = apps['armv7']
    def resources(app):
        return {str(p.relative_to(app)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in app.rglob('*') if p.is_file() and p.name not in ('Telegram', 'Info.plist') and '_CodeSignature' not in p.parts}
    def metadata(source):
        info = plistlib.loads((source / 'Info.plist').read_bytes())
        info['MinimumOSVersion'] = '3.1.3' if triple else '4.3'
        for key in ('OGOnegramBuildIdentifier', 'OGOnegramBuildArchitecture'):
            info.pop(key, None)
        if triple:
            info.pop('UIRequiredDeviceCapabilities', None)
        return info
    expected_resources = resources(legacy)
    expected_info = metadata(legacy)
    for source in apps.values():
        if expected_resources != resources(source):
            raise SystemExit('Architecture resource sets differ')
        if expected_info != metadata(source):
            raise SystemExit('Architecture application metadata differs')
    if app.exists():
        shutil.rmtree(app)
    shutil.copytree(legacy, app)
    (app / 'Info.plist').write_bytes(plistlib.dumps(expected_info, fmt=plistlib.FMT_BINARY, sort_keys=False))
    subprocess.run([lipo, '-create'] + [str(source / 'Telegram') for source in apps.values()] + ['-output', str(app / 'Telegram')], check=True)
    write_build_identity(app, '+'.join(architectures))
    shutil.rmtree(app / '_CodeSignature', ignore_errors=True)
    (app / 'CodeResources').unlink(missing_ok=True)
    sign_app(app, args.ldid, entitlements)
    subprocess.run([lipo, str(app / 'Telegram'), '-verify_arch'] + architectures, check=True)
    subprocess.run([lipo, '-info', str(app / 'Telegram')], check=True)
    with zipfile.ZipFile(ipa, 'w', zipfile.ZIP_DEFLATED) as package:
        for path in sorted(app.rglob('*')):
            if path.is_file():
                package.write(path, path.relative_to(output))
    verify_ipa(ipa, entitlements)
    cache_record(stamp, signature, [app, ipa])
    print(ipa)


if __name__ == '__main__':
    main()
