#!/usr/bin/env python3
import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

SDK_BY_ARCH = {
    'armv6': ('3.1.3',),
    'armv7': ('6.1',),
    'universal3': ('3.1.3', '6.1', '11.2'),
}
SDK_ARCHIVE_URLS = {
    '3.1.3': 'https://raw.githubusercontent.com/qianjigui/iOS-sdks/master/iPhoneOS3.1.3.sdk.tbz2',
    '6.1': 'https://github.com/GrowtopiaJaw/iPhoneOS-SDK/releases/download/v1.0/iPhoneOS6.1.sdk.zip',
}
SDK_REPOSITORIES = {
    '11.2': ('xybp888/iOS-SDKs', 'iPhoneOS11.2.sdk'),
}
LINUX_TOOLCHAIN_URL = 'https://github.com/L1ghtmann/llvm-project/releases/download/test-210562a/iOSToolchain-x86_64.tar.xz'
LINUX_TOOLCHAIN_SHA256 = 'a72a7a577e2fbe2838b6b5e9c72034fa7d114af96f0e1d4b016f18730ce4056e'
THEOS_REPOSITORY = 'https://github.com/theos/theos.git'


def report(message):
    print('[Onegram setup] ' + message, flush=True)


def run(args, **kwargs):
    report('Running: ' + ' '.join(str(arg) for arg in args))
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def available(name):
    return shutil.which(name) is not None


def package_manager():
    for binary in ('apt-get', 'pacman', 'dnf', 'zypper', 'apk', 'xbps-install', 'emerge', 'eopkg', 'yum'):
        if available(binary):
            return binary
    return None


def package_definitions(manager):
    commands = {
        'git': 'git', 'make': 'make', 'perl': 'perl', 'rsync': 'rsync',
        'zip': 'zip', 'unzip': 'unzip', 'ccache': 'ccache', 'patch': 'patch',
        'tar': 'tar', 'clang': 'clang', 'gcc': 'gcc', 'g++': 'g++',
        'ar': 'binutils', 'curl': 'curl', 'pkg-config': 'pkg-config',
        'fakeroot': 'fakeroot', 'xz': 'xz-utils',
        'autoconf': 'autoconf', 'automake': 'automake', 'libtoolize': 'libtool',
        'llvm-config': 'llvm-dev',
    }
    platform_names = {
        'apt-get': {'pkg-config': 'pkg-config', 'idevice_id': 'libimobiledevice-utils', 'ideviceinfo': 'libimobiledevice-utils', 'ideviceinstaller': 'ideviceinstaller', 'usbmuxd': 'usbmuxd'},
        'pacman': {'pkg-config': 'pkgconf', 'xz': 'xz', 'g++': 'gcc', 'ar': 'binutils', 'idevice_id': 'libimobiledevice', 'ideviceinfo': 'libimobiledevice', 'ideviceinstaller': 'ideviceinstaller', 'usbmuxd': 'usbmuxd'},
        'dnf': {'pkg-config': 'pkgconf-pkg-config', 'xz': 'xz', 'g++': 'gcc-c++', 'idevice_id': 'libimobiledevice-utils', 'ideviceinfo': 'libimobiledevice-utils', 'ideviceinstaller': 'ideviceinstaller', 'usbmuxd': 'usbmuxd'},
        'yum': {'pkg-config': 'pkgconfig', 'xz': 'xz', 'g++': 'gcc-c++', 'idevice_id': 'libimobiledevice-utils', 'ideviceinfo': 'libimobiledevice-utils', 'ideviceinstaller': 'ideviceinstaller', 'usbmuxd': 'usbmuxd'},
        'zypper': {'pkg-config': 'pkg-config', 'xz': 'xz', 'g++': 'gcc-c++', 'idevice_id': 'libimobiledevice-utils', 'ideviceinfo': 'libimobiledevice-utils', 'ideviceinstaller': 'ideviceinstaller', 'usbmuxd': 'usbmuxd'},
        'apk': {'pkg-config': 'pkgconf', 'xz': 'xz', 'g++': 'g++', 'ar': 'binutils', 'idevice_id': 'libimobiledevice-utils', 'ideviceinfo': 'libimobiledevice-utils', 'ideviceinstaller': 'ideviceinstaller', 'usbmuxd': 'usbmuxd'},
        'xbps-install': {'pkg-config': 'pkg-config', 'xz': 'xz', 'g++': 'gcc', 'idevice_id': 'libimobiledevice', 'ideviceinfo': 'libimobiledevice', 'ideviceinstaller': 'ideviceinstaller', 'usbmuxd': 'usbmuxd'},
        'emerge': {'pkg-config': 'dev-util/pkgconf', 'xz': 'app-arch/xz-utils', 'clang': 'llvm-core/clang', 'fakeroot': 'sys-apps/fakeroot', 'idevice_id': 'app-pda/libimobiledevice', 'ideviceinfo': 'app-pda/libimobiledevice', 'ideviceinstaller': 'app-pda/ideviceinstaller', 'usbmuxd': 'app-pda/usbmuxd'},
        'eopkg': {'pkg-config': 'pkg-config', 'xz': 'xz', 'g++': 'gcc', 'idevice_id': 'libimobiledevice', 'ideviceinfo': 'libimobiledevice', 'ideviceinstaller': 'ideviceinstaller', 'usbmuxd': 'usbmuxd'},
    }
    commands.update(platform_names.get(manager, {}))
    llvm_packages = {'pacman': 'llvm', 'dnf': 'llvm-devel', 'yum': 'llvm-devel',
                     'zypper': 'llvm-devel', 'apk': 'llvm-dev', 'xbps-install': 'llvm-devel',
                     'emerge': 'llvm-core/llvm', 'eopkg': 'llvm-devel'}
    commands['llvm-config'] = llvm_packages.get(manager, 'llvm-dev')
    if os.environ.get('ONEGRAM_SKIP_DEVICE_INSTALL') == '1':
        for command in ('idevice_id', 'ideviceinfo', 'ideviceinstaller', 'usbmuxd'):
            commands.pop(command, None)
    return commands


def missing_packages():
    if sys.platform == 'darwin':
        commands = {'make': 'make', 'git': 'git', 'rsync': 'rsync', 'ccache': 'ccache', 'ldid': 'ldid', 'xz': 'xz', 'pkg-config': 'pkg-config'}
        return sorted({pkg for cmd, pkg in commands.items() if not available(cmd)})
    mapping = package_definitions(package_manager())
    return sorted({pkg for cmd, pkg in mapping.items() if not available(cmd)})


def as_admin(command):
    if os.geteuid() == 0:
        return command
    if not available('sudo'):
        raise RuntimeError('sudo is needed to install missing system packages')
    return ['sudo'] + command


def install_system_packages(packages, dry_run):
    if not packages:
        report('System build utilities: available')
        return
    if sys.platform == 'darwin':
        if available('brew'):
            command = ['brew', 'install'] + packages
        elif available('port'):
            command = as_admin(['port', 'install'] + packages)
        else:
            raise RuntimeError('Homebrew or MacPorts is required to install missing macOS tools: ' + ', '.join(packages))
    else:
        manager = package_manager()
        if manager is None:
            raise RuntimeError('No supported package manager detected. Missing: ' + ', '.join(packages))
        commands = {
            'apt-get': ['apt-get', 'install', '-y'],
            'pacman': ['pacman', '-S', '--needed', '--noconfirm'],
            'dnf': ['dnf', 'install', '-y'],
            'yum': ['yum', 'install', '-y'],
            'zypper': ['zypper', '--non-interactive', 'install'],
            'apk': ['apk', 'add', '--no-cache'],
            'xbps-install': ['xbps-install', '-Sy'],
            'emerge': ['emerge', '--noreplace', '--quiet'],
            'eopkg': ['eopkg', 'install', '-y'],
        }
        command = as_admin(commands[manager] + packages)
    report('Missing system packages: ' + ', '.join(packages))
    if dry_run:
        report('Dry run: would execute ' + ' '.join(command))
        return
    if sys.platform == 'linux' and manager == 'apt-get':
        run(as_admin(['apt-get', 'update']))
    run(command)
    still_missing = [pkg for pkg in missing_packages() if pkg in packages]
    if still_missing:
        raise RuntimeError('Packages remain unavailable after installation: ' + ', '.join(still_missing))


def validate_toolchain(root):
    tools = root / 'toolchain/linux/iphone/bin'
    required = ('clang', 'clang++', 'lipo', 'ld', 'libtool', 'llvm-ar', 'ranlib', 'nm', 'hmaptool', 'ldid')
    return all((tools / name).is_file() and os.access(tools / name, os.X_OK) for name in required)


def validate_linker(root, sdk, architecture, deployment):
    tools = root / 'toolchain/linux/iphone/bin'
    crt = sdk / 'usr/lib/crt1.3.1.o'
    if not crt.is_file():
        return False
    with tempfile.TemporaryDirectory(prefix='onegram-linker-check-') as temp:
        output = Path(temp) / 'probe'
        command = [
            tools / 'clang', '-target', architecture + '-apple-ios' + deployment,
            '-miphoneos-version-min=' + deployment, '-isysroot', sdk,
            '-nostartfiles', crt, '-x', 'c', '-', '-o', output
        ]
        result = subprocess.run(
            [str(item) for item in command], input='int main(void) { return 0; }\n',
            text=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE
        )
        return result.returncode == 0 and output.is_file()


def download(url, output):
    if not url.startswith('https://'):
        raise RuntimeError('Only HTTPS downloads are supported: ' + url)
    report('Downloading ' + url)
    request = urllib.request.Request(url, headers={'User-Agent': 'Onegram-build-bootstrap/2.0'})
    with urllib.request.urlopen(request, timeout=120) as response, output.open('wb') as destination:
        shutil.copyfileobj(response, destination)


def validate_sha256(path, checksum):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    if h.hexdigest().lower() != checksum.lower():
        raise RuntimeError('SHA256 mismatch for ' + str(path))


def contained(path, root):
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def check_member(name, destination, link=None):
    path = PurePosixPath(name)
    if not name or path.is_absolute() or '..' in path.parts or not contained(destination / name, destination):
        raise RuntimeError('Unsafe archive entry: ' + name)
    if link:
        target = (destination / name).parent / link
        if PurePosixPath(link).is_absolute() or not contained(target, destination):
            raise RuntimeError('Unsafe archive link: ' + name)


def safe_unpack(archive, destination, omit_toolchain_sdk_link=False):
    if tarfile.is_tarfile(archive):
        with tarfile.open(archive, 'r:*') as handle:
            members = handle.getmembers()
            ignored_path = PurePosixPath('ios-arm64e-clang-toolchain/sdks')
            selected = []
            for member in members:
                path = PurePosixPath(member.name)
                if omit_toolchain_sdk_link and path == ignored_path and member.issym():
                    report('Ignoring optional toolchain SDK link; Onegram manages SDKs in $THEOS/sdks')
                    continue
                if omit_toolchain_sdk_link and ignored_path in path.parents:
                    raise RuntimeError('Unexpected archive content under optional SDK link: ' + member.name)
                if not (member.isdir() or member.isfile() or member.issym() or member.islnk()):
                    raise RuntimeError('Unexpected archive member type: ' + member.name)
                if member.islnk():
                    check_member(member.name, destination)
                    check_member(member.linkname, destination)
                else:
                    check_member(member.name, destination, member.linkname if member.issym() else None)
                selected.append(member)
            links = {PurePosixPath(item.name) for item in selected if item.issym()}
            for member in selected:
                path = PurePosixPath(member.name)
                if any(parent in links for parent in path.parents):
                    raise RuntimeError('Archive entry traverses a symbolic link: ' + member.name)
            ordinary = [member for member in selected if member.isfile() or member.isdir()]
            hardlinks = [member for member in selected if member.islnk()]
            symlinks = [member for member in selected if member.issym()]
            handle.extractall(destination, members=ordinary)
            handle.extractall(destination, members=hardlinks)
            handle.extractall(destination, members=symlinks)
    elif zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as handle:
            ordinary = []
            symlinks = []
            for member in handle.infolist():
                check_member(member.filename, destination)
                mode = (member.external_attr >> 16) & 0o170000
                if mode == 0o120000:
                    if member.file_size > 4096:
                        raise RuntimeError('Oversized ZIP symbolic link: ' + member.filename)
                    link = handle.read(member).decode('utf-8', 'surrogateescape')
                    if not link or '\x00' in link:
                        raise RuntimeError('Invalid ZIP symbolic link: ' + member.filename)
                    check_member(member.filename, destination, link)
                    symlinks.append((member, link))
                elif mode in (0, 0o100000, 0o040000):
                    ordinary.append(member)
                else:
                    raise RuntimeError('Unexpected ZIP member type: ' + member.filename)
            link_paths = {PurePosixPath(member.filename) for member, _ in symlinks}
            for member in handle.infolist():
                path = PurePosixPath(member.filename)
                if any(parent in link_paths for parent in path.parents):
                    raise RuntimeError('ZIP entry traverses a symbolic link: ' + member.filename)
            handle.extractall(destination, members=ordinary)
            for member, link in symlinks:
                path = destination / member.filename
                path.parent.mkdir(parents=True, exist_ok=True)
                check_member(member.filename, destination, link)
                os.symlink(link, path)
    else:
        raise RuntimeError('Unsupported archive format: ' + str(archive))


def install_theos(theos, dry_run):
    if (theos / 'makefiles/common.mk').is_file():
        report('Theos: ' + str(theos))
        return
    if theos.exists() and any(theos.iterdir()):
        raise RuntimeError(str(theos) + ' exists but is not a valid Theos checkout')
    report('Theos is missing; cloning the official repository')
    if dry_run:
        return
    theos.parent.mkdir(parents=True, exist_ok=True)
    run(['git', 'clone', '--recursive', '--depth', '1', THEOS_REPOSITORY, theos])
    if not (theos / 'makefiles/common.mk').is_file():
        raise RuntimeError('Theos checkout is missing makefiles/common.mk')


def install_linux_toolchain(theos, sdk, architecture, deployment, dry_run):
    complete = validate_toolchain(theos)
    compatible = complete and validate_linker(theos, sdk, architecture, deployment)
    if compatible:
        report('Linux iOS toolchain: available')
        return
    host = platform.machine().lower()
    if host != 'x86_64':
        raise RuntimeError('Automatic Linux toolchain setup is verified for x86_64 only. Supply a working $THEOS/toolchain/linux/iphone for ' + host)
    url = os.environ.get('ONEGRAM_TOOLCHAIN_URL', LINUX_TOOLCHAIN_URL)
    if complete:
        report('Installed Linux iOS toolchain cannot link ' + architecture + ' for iOS ' + deployment + '; replacing it')
    else:
        report('Linux iOS toolchain is missing or incomplete')
    report('Linux iOS toolchain source: ' + url)
    if dry_run:
        return
    target = theos / 'toolchain/linux/iphone'
    with tempfile.TemporaryDirectory(prefix='onegram-toolchain-') as temp:
        archive = Path(temp) / 'toolchain.tar.xz'
        download(url, archive)
        checksum = os.environ.get('ONEGRAM_TOOLCHAIN_SHA256')
        if checksum is None and url == LINUX_TOOLCHAIN_URL:
            checksum = LINUX_TOOLCHAIN_SHA256
        if checksum is None:
            raise RuntimeError('ONEGRAM_TOOLCHAIN_SHA256 is required with a custom toolchain URL')
        validate_sha256(archive, checksum)
        unpacked = Path(temp) / 'unpacked'
        unpacked.mkdir()
        safe_unpack(archive, unpacked, omit_toolchain_sdk_link=True)
        matches = [candidate for candidate in unpacked.rglob('bin/clang') if candidate.is_file()]
        valid = [candidate.parent.parent for candidate in matches if (candidate.parent / 'clang++').is_file() and (candidate.parent / 'lipo').is_file()]
        if len(valid) != 1:
            raise RuntimeError('Toolchain archive must contain exactly one bin/{clang,clang++,lipo} toolchain')
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            if target.is_dir() and not target.is_symlink():
                shutil.rmtree(target)
            else:
                target.unlink()
        shutil.move(str(valid[0]), str(target))
    if not validate_toolchain(theos):
        raise RuntimeError('Linux iOS toolchain is incomplete after installation')
    if not validate_linker(theos, sdk, architecture, deployment):
        raise RuntimeError('Installed Linux iOS toolchain cannot link ' + architecture + ' for iOS ' + deployment)


def ensure_signer(theos, dry_run):
    host = 'macos' if sys.platform == 'darwin' else 'linux'
    for candidate in (theos / ('toolchain/' + host + '/iphone/bin/ldid'), theos / 'bin/ldid'):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            report('Code signer: ' + str(candidate))
            return
    if available('ldid'):
        report('Code signer: ' + str(shutil.which('ldid')))
        return
    if dry_run:
        report('Code signer ldid: would check after installing the iOS toolchain')
        return
    if sys.platform == 'darwin':
        install_system_packages(['ldid'], dry_run)
    else:
        raise RuntimeError('ldid is missing. The downloaded Linux toolchain did not include it. Install a real ldid binary or set $THEOS/bin/ldid')


def sdk_label(version):
    return 'iPhoneOS' + version + '.sdk'


def sdk_available(sdk):
    return sdk.is_dir() and (sdk / 'System/Library/Frameworks/Foundation.framework/Headers/Foundation.h').is_file()


def sdk_source_dir(version):
    roots = []
    if os.environ.get('ONEGRAM_SDK_DIR'):
        roots.append(Path(os.environ['ONEGRAM_SDK_DIR']).expanduser())
    roots.extend(Path(base) for base in ('/opt/theos/sdks', '/usr/local/theos/sdks'))
    if sys.platform == 'darwin' and available('xcode-select'):
        result = subprocess.run(['xcode-select', '-p'], capture_output=True, text=True)
        if result.returncode == 0:
            roots.append(Path(result.stdout.strip()) / 'Platforms/iPhoneOS.platform/Developer/SDKs')
    return next((candidate for root in roots for candidate in [root / sdk_label(version)] if sdk_available(candidate)), None)


def sdk_archive_source(version):
    key = 'ONEGRAM_SDK_' + version.replace('.', '_')
    return os.environ.get(key + '_URL'), os.environ.get(key + '_SHA256')


def install_sdk_archive(archive, version, destination):
    with tempfile.TemporaryDirectory(prefix='onegram-sdk-unpack-') as temp:
        extracted = Path(temp)
        safe_unpack(archive, extracted)
        candidates = [path for path in extracted.rglob(sdk_label(version)) if sdk_available(path)]
        if len(candidates) != 1:
            raise RuntimeError('Archive must contain exactly one complete ' + sdk_label(version))
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(candidates[0]), str(destination))


def install_sdk_from_git(version, destination):
    repository, sdk_path = SDK_REPOSITORIES[version]
    url = 'https://github.com/' + repository + '.git'
    report('Installing ' + sdk_label(version) + ' from ' + url)
    with tempfile.TemporaryDirectory(prefix='onegram-sdk-git-') as temp:
        checkout = Path(temp) / 'repository'
        run(['git', 'clone', '--depth', '1', '--filter=blob:none', '--sparse', '--branch', 'master', url, checkout])
        run(['git', '-C', checkout, 'sparse-checkout', 'set', sdk_path])
        source = checkout / sdk_path
        if not sdk_available(source):
            raise RuntimeError('GitHub source lacks required SDK headers: ' + str(source))
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(source), str(destination))


def install_sdk_from_github_archive(version, destination):
    url = SDK_ARCHIVE_URLS[version]
    report('Installing ' + sdk_label(version) + ' from ' + url)
    with tempfile.TemporaryDirectory(prefix='onegram-sdk-download-') as temp:
        archive = Path(temp) / url.rsplit('/', 1)[-1]
        download(url, archive)
        checksum = os.environ.get('ONEGRAM_SDK_' + version.replace('.', '_') + '_SHA256')
        if checksum:
            validate_sha256(archive, checksum)
        install_sdk_archive(archive, version, destination)


def ensure_sdks(theos, versions, dry_run):
    sdks = theos / 'sdks'
    for version in versions:
        destination = sdks / sdk_label(version)
        if sdk_available(destination):
            report('SDK ' + version + ': ' + str(destination))
            continue
        if destination.exists() or destination.is_symlink():
            raise RuntimeError('Incomplete SDK at ' + str(destination) + '; refusing to overwrite it')
        source = sdk_source_dir(version)
        if source:
            report('Found ' + sdk_label(version) + ': ' + str(source))
            if not dry_run:
                sdks.mkdir(parents=True, exist_ok=True)
                destination.symlink_to(source.resolve(), target_is_directory=True)
            continue
        url, checksum = sdk_archive_source(version)
        if url:
            if not checksum or len(checksum) != 64 or any(char not in '0123456789abcdefABCDEF' for char in checksum):
                raise RuntimeError('A valid SHA256 is required with ' + sdk_label(version) + ' custom URL')
            report('Installing ' + sdk_label(version) + ' from configured archive URL')
            if not dry_run:
                with tempfile.TemporaryDirectory(prefix='onegram-sdk-download-') as temp:
                    archive = Path(temp) / 'archive'
                    download(url, archive)
                    validate_sha256(archive, checksum)
                    install_sdk_archive(archive, version, destination)
        elif version in SDK_ARCHIVE_URLS:
            report('SDK ' + version + ' will be downloaded from ' + SDK_ARCHIVE_URLS[version])
            if not dry_run:
                install_sdk_from_github_archive(version, destination)
        else:
            report('SDK ' + version + ' will be downloaded from ' + SDK_REPOSITORIES[version][0])
            if not dry_run:
                install_sdk_from_git(version, destination)
        if not dry_run and not sdk_available(destination):
            raise RuntimeError('SDK installation did not produce valid ' + sdk_label(version))




def main():
    parser = argparse.ArgumentParser(description='Prepare Onegram build prerequisites')
    parser.add_argument('--architecture', required=True, choices=tuple(SDK_BY_ARCH))
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    theos = Path(os.environ.get('THEOS') or Path.home() / 'theos').expanduser().resolve()
    if sys.platform not in ('linux', 'darwin'):
        raise RuntimeError('Only Linux and macOS are supported')
    if sys.platform == 'darwin' and not args.dry_run:
        from setup_macos_toolchain import ensure_native_packages
        tools = ensure_native_packages()
        os.environ['PATH'] = str(tools / 'bin') + os.pathsep + os.environ.get('PATH', '')
    packages = missing_packages()
    install_system_packages(packages, args.dry_run)
    install_theos(theos, args.dry_run)
    ensure_sdks(theos, SDK_BY_ARCH[args.architecture], args.dry_run)
    if sys.platform == 'linux':
        if args.architecture == 'armv7':
            sdk = theos / 'sdks/iPhoneOS6.1.sdk'
            install_linux_toolchain(theos, sdk, 'armv7', '4.3', args.dry_run)
        else:
            sdk = theos / 'sdks/iPhoneOS3.1.3.sdk'
            install_linux_toolchain(theos, sdk, 'armv6', '3.1.3', args.dry_run)
        if not args.dry_run:
            from setup_linux_linker import ensure_linux_linker
            ensure_linux_linker(theos / 'toolchain/linux/iphone')
    elif not args.dry_run:
        from setup_macos_toolchain import ensure_macos_toolchain
        ensure_macos_toolchain(theos, SDK_BY_ARCH[args.architecture])
    ensure_signer(theos, args.dry_run)
    report('Dry run complete; no changes made' if args.dry_run else 'Prerequisites ready; Makefile will generate files and build libraries as needed')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print('[Onegram setup] ERROR: ' + str(error), file=sys.stderr)
        sys.exit(1)
