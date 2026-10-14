import argparse
import hashlib
import os
from pathlib import Path
import plistlib


def write_build_identity(app, architecture, diagnostics=None):
    app = Path(app)
    path = app / 'Info.plist'
    info = plistlib.loads(path.read_bytes())
    binary = app / info['CFBundleExecutable']
    info['OGOnegramBuildIdentifier'] = hashlib.sha256(binary.read_bytes()).hexdigest()[:16]
    info['OGOnegramBuildArchitecture'] = architecture
    if diagnostics is None:
        diagnostics = info.get('OGOnegramBuildDiagnostics', os.environ.get('ONEGRAM_DIAGNOSTICS') == '1')
    info['OGOnegramBuildDiagnostics'] = bool(diagnostics)
    path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY, sort_keys=False))
    return info['OGOnegramBuildIdentifier']


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--architecture', required=True)
    arguments = parser.parse_args()
    print(write_build_identity(arguments.app, arguments.architecture))
