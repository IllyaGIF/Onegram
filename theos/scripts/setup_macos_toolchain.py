#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import subprocess
import sys
import tempfile


RECIPE = Path(__file__).resolve().parents[1] / 'native-toolchain.json'


def native_root():
    return Path(os.environ.get('ONEGRAM_NATIVE_ROOT', str(Path.home() / '.cache/onegram/macos'))).expanduser()


def native_tool(tools, name):
    candidates = sorted((tools / 'bin').glob('*-apple-darwin*-' + name))
    candidates.append(tools / 'bin' / name)
    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate
    raise RuntimeError('Missing native tool: ' + name)


def ensure_native_packages():
    root = native_root()
    tools = root / 'tools'
    marker = tools / '.onegram-packages.sha256'
    digest = hashlib.sha256(RECIPE.read_bytes()).hexdigest()
    required = ('python3', 'clang', 'clang++', 'llvm-config', 'make', 'ccache', 'ldid', 'git', 'perl', 'awk', 'autoconf', 'automake', 'libtoolize')
    if marker.is_file() and marker.read_text().strip() == digest and all((tools / 'bin' / name).is_file() for name in required):
        return tools
    conda = root / 'bootstrap/bin/conda'
    if not conda.is_file():
        raise RuntimeError('Native package bootstrap is missing; run ./build.sh')
    recipe = json.loads(RECIPE.read_text())
    print('[Onegram setup] Installing native macOS build tools', flush=True)
    environment = os.environ.copy()
    environment['CONDA_PKGS_DIRS'] = str(root / 'packages')
    for name in ('CONDA_SUBDIR', 'CONDA_OVERRIDE_OSX', 'CONDA_OVERRIDE_ARCHSPEC', 'DEVELOPER_DIR', 'SDKROOT'):
        environment.pop(name, None)
    action = 'install' if (tools / 'conda-meta/history').is_file() else 'create'
    subprocess.run([str(conda), action, '--yes', '--prefix', str(tools), '--override-channels',
                    '--channel', 'https://conda.anaconda.org/conda-forge', '--strict-channel-priority'] + recipe['packages'],
                   env=environment, check=True)
    for name in required:
        if not (tools / 'bin' / name).is_file():
            raise RuntimeError('Native package installation lacks ' + name)
    marker.write_text(digest + '\n')
    return tools


def link_tool(path, target):
    relative = os.path.relpath(target, path.parent)
    if path.is_symlink() and os.readlink(path) == relative:
        return
    if path.exists() or path.is_symlink():
        path.unlink()
    path.symlink_to(relative)


def ensure_macos_toolchain(theos, versions):
    from bootstrap_build import download, safe_unpack, validate_sha256
    from setup_linux_linker import ensure_linker
    tools = ensure_native_packages()
    root = native_root()
    recipe = json.loads(RECIPE.read_text())
    sdk = root / recipe['host_sdk']['name']
    if not (sdk / 'usr/include/stdio.h').is_file():
        with tempfile.TemporaryDirectory(prefix='onegram-macos-sdk-', dir=str(root)) as temporary:
            archive = Path(temporary) / 'host-sdk.tar.xz'
            download(recipe['host_sdk']['url'], archive)
            validate_sha256(archive, recipe['host_sdk']['sha256'])
            safe_unpack(archive, root)
        if not (sdk / 'usr/include/stdio.h').is_file():
            raise RuntimeError('Native host SDK installation is incomplete')
    toolchain = theos / 'toolchain/macos/iphone'
    binary_dir = toolchain / 'bin'
    binary_dir.mkdir(parents=True, exist_ok=True)
    for name in ('ar', 'ranlib', 'libtool', 'lipo', 'nm', 'otool', 'size', 'strip', 'codesign_allocate'):
        link_tool(binary_dir / name, native_tool(tools, name))
    for name in ('ldid', 'llvm-ar', 'llvm-config', 'dsymutil'):
        link_tool(binary_dir / name, tools / 'bin' / name)
    marker = toolchain / '.onegram-linker/installed.json'
    if not marker.is_file() or not (binary_dir / 'ld').is_file():
        link_tool(binary_dir / 'ld', native_tool(tools, 'ld'))
    resource = toolchain / 'lib/clang/11.1.0'
    resource.mkdir(parents=True, exist_ok=True)
    resource_dir = subprocess.check_output([str(tools / 'bin/clang'), '-print-resource-dir'], text=True).strip()
    link_tool(resource / 'include', Path(resource_dir) / 'include')
    runtime = resource / 'lib/darwin'
    runtime.mkdir(parents=True, exist_ok=True)
    project = Path(__file__).resolve().parents[2]
    arc = toolchain / 'lib/arc'
    arc.mkdir(parents=True, exist_ok=True)
    link_tool(arc / 'libarclite_iphoneos.a', project / 'theos/lib/libarclite_iphoneos.a')
    for name in ('clang', 'clang++'):
        wrapper = binary_dir / name
        contents = '#!/bin/sh\nexec ' + shlex.join([str(tools / 'bin' / name), '-B' + str(binary_dir), '-resource-dir', str(resource)]) + ' "$@"\n'
        if not wrapper.is_file() or wrapper.read_text() != contents:
            wrapper.write_text(contents)
            wrapper.chmod(0o755)
    ensure_linker(toolchain, jobs=min(4, os.cpu_count() or 2), host_sdk=sdk, build_tools=tools)
    from build_macos_runtime import ensure_ios_runtime
    ensure_ios_runtime(toolchain, theos, versions, recipe['runtime'])
    architectures = {'3.1.3': ('armv6', '3.1.3'), '6.1': ('armv7', '4.3'), '11.2': ('arm64', '7.0')}
    for version in versions:
        architecture, deployment = architectures[version]
        target_sdk = theos / ('sdks/iPhoneOS' + version + '.sdk')
        with tempfile.TemporaryDirectory(prefix='onegram-native-probe-') as temporary:
            output = Path(temporary) / 'probe'
            obj = Path(temporary) / 'probe.o'
            command = [str(binary_dir / 'clang'), '-target', architecture + '-apple-ios' + deployment,
                       '-miphoneos-version-min=' + deployment, '-isysroot', str(target_sdk), '-x', 'c', '-', '-c', '-o', str(obj)]
            result = subprocess.run(command, input='#include <unistd.h>\nint main(void) { return getpid() == 0; }\n', text=True, capture_output=True)
            if result.returncode:
                raise RuntimeError('Native ' + architecture + ' compiler probe failed:\n' + result.stderr)
            result = subprocess.run([str(binary_dir / 'ld'), '-arch', architecture, '-iphoneos_version_min', deployment,
                                     '-syslibroot', str(target_sdk), '-e', '_main', '-o', str(output), str(obj), '-lSystem'],
                                    text=True, capture_output=True)
            if result.returncode:
                raise RuntimeError('Native ' + architecture + ' linker probe failed:\n' + result.stderr)
            subprocess.run([str(binary_dir / 'lipo'), str(output), '-verify_arch', architecture], check=True)
    print('[Onegram setup] Native macOS toolchain ready: ' + str(toolchain), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--tools-only', action='store_true', required=True)
    parser.parse_args()
    try:
        ensure_native_packages()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print('[Onegram setup] ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
