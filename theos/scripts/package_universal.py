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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ldid', required=True)
    parser.add_argument('--toolchain', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    legacy = root / 'build/Payload/Telegram.app'
    modern = root / 'build/arm64/Payload/Telegram.app'
    for arch, app in [('armv7', legacy), ('arm64', modern)]:
        env = dict(os.environ, ONEGRAM_ARCH=arch, ONEGRAM_GENERATED_DIR='generated/arm64' if arch == 'arm64' else 'generated')
        subprocess.run(['python3', str(root / 'scripts/verify_binary.py'), str(app / 'Telegram'), '--tools', str(args.toolchain / 'bin')], env=env, check=True)
    def resources(app):
        return {str(p.relative_to(app)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in app.rglob('*') if p.is_file() and p.name not in ('Telegram', 'Info.plist') and '_CodeSignature' not in p.parts}
    if resources(legacy) != resources(modern):
        raise SystemExit('Architecture resource sets differ')
    legacy_info = plistlib.loads((legacy / 'Info.plist').read_bytes())
    modern_info = plistlib.loads((modern / 'Info.plist').read_bytes())
    modern_info['MinimumOSVersion'] = legacy_info['MinimumOSVersion']
    if legacy_info != modern_info:
        raise SystemExit('Architecture application metadata differs')
    output = root / 'build/universal'
    app = output / 'Payload/Telegram.app'
    if app.exists():
        shutil.rmtree(app)
    shutil.copytree(legacy, app)
    lipo = str(args.toolchain / 'bin/lipo')
    subprocess.run([lipo, '-create', str(legacy / 'Telegram'), str(modern / 'Telegram'), '-output', str(app / 'Telegram')], check=True)
    subprocess.run(shlex.split(args.ldid) + ['-S' + str(root / 'generated/signing.entitlements'), str(app / 'Telegram')], check=True)
    subprocess.run([lipo, str(app / 'Telegram'), '-verify_arch', 'armv7', 'arm64'], check=True)
    subprocess.run([lipo, '-info', str(app / 'Telegram')], check=True)
    with zipfile.ZipFile(output / 'Onegram.ipa', 'w', zipfile.ZIP_DEFLATED) as package:
        for path in sorted(app.rglob('*')):
            if path.is_file():
                package.write(path, path.relative_to(output))
    print(output / 'Onegram.ipa')


if __name__ == '__main__':
    main()
