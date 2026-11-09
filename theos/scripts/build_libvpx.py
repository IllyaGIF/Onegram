from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request
from artifact_cache import cache_matches, cache_record, fingerprint

LIBVPX_VERSION = '1.14.1'
LIBVPX_URL = 'https://codeload.github.com/webmproject/libvpx/tar.gz/refs/tags/v' + LIBVPX_VERSION

COMMON_OPTIONS = [
    '--enable-external-build',
    '--enable-vp8',
    '--enable-vp9-decoder',
    '--disable-vp9-encoder',
    '--enable-realtime-only',
    '--disable-runtime-cpu-detect',
    '--size-limit=1920x1088',
    '--disable-examples',
    '--disable-tools',
    '--disable-docs',
    '--disable-unit-tests',
    '--disable-install-bins',
    '--disable-install-libs',
    '--disable-webm-io',
    '--disable-libyuv',
]

TARGETS = {
    'armv6': ('generic-gnu', []),
    'armv7': ('armv7-darwin-gcc', ['--disable-neon-asm']),
    'arm64': ('arm64-darwin-gcc', ['--disable-neon-dotprod', '--disable-neon-i8mm', '--disable-sve']),
}

GENERATED_HEADERS = ['vp8_rtcd.h', 'vp9_rtcd.h', 'vpx_dsp_rtcd.h', 'vpx_scale_rtcd.h', 'vpx_version.h']


class LibvpxBuild:
    def __init__(self, archive, include):
        self.archive = archive
        self.include = include


def make_environment():
    environment = os.environ.copy()
    for name in ('MAKEFLAGS', 'GNUMAKEFLAGS', 'MFLAGS', 'MAKELEVEL', 'MAKE'):
        environment.pop(name, None)
    return environment


def prepare_source(out):
    sources = out / 'dependency-sources'
    sources.mkdir(parents=True, exist_ok=True)
    archive = sources / ('libvpx-' + LIBVPX_VERSION + '.tar.gz')
    if not archive.is_file():
        temporary = archive.with_suffix('.download')
        urllib.request.urlretrieve(LIBVPX_URL, temporary)
        temporary.replace(archive)
    source = sources / ('libvpx-' + LIBVPX_VERSION)
    if not (source / 'configure').is_file():
        if source.exists():
            shutil.rmtree(source)
        with tarfile.open(archive) as package:
            if hasattr(tarfile, 'data_filter'):
                package.extractall(sources, filter='data')
            else:
                package.extractall(sources)
    if not (source / 'vpx/vpx_encoder.h').is_file():
        raise SystemExit('libvpx source was not extracted: ' + str(source))
    return archive, source


def configure(source, config, arch):
    target, options = TARGETS[arch]
    if config.exists():
        shutil.rmtree(config)
    config.mkdir(parents=True)
    environment = make_environment()
    subprocess.run(['sh', str(source / 'configure'), '--target=' + target] + COMMON_OPTIONS + options,
                   cwd=config, env=environment, check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['make', '--no-print-directory'] + GENERATED_HEADERS, cwd=config, env=environment, check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['make', '--no-print-directory', 'libvpx_srcs.txt', 'target=libs'], cwd=config, env=environment, check=True, stdout=subprocess.DEVNULL)
    for header in ['vpx_config.h'] + GENERATED_HEADERS:
        if not (config / header).is_file():
            raise SystemExit('libvpx configuration did not produce ' + header)
    sources = []
    for line in (config / 'libvpx_srcs.txt').read_text().split():
        if line.endswith(('.S', '.asm', '.s')):
            raise SystemExit('Unexpected libvpx assembly source for ' + arch + ': ' + line)
        if not line.endswith('.c'):
            continue
        generated = config / line
        sources.append(generated if generated.is_file() else source / line)
    if not sources:
        raise SystemExit('libvpx source list is empty for ' + arch)
    return sources


def build_libvpx(arch, compiler, sdk, minimum, toolchain, jobs, out, extra_flags):
    archive_source, source = prepare_source(out)
    work = out / 'libvpx'
    config = work / 'config'
    objects_dir = work / 'objects'
    include = work / 'include'
    products = out / 'products'
    products.mkdir(parents=True, exist_ok=True)
    library = products / 'libvpx.a'
    libtool = str(Path(toolchain) / 'bin/libtool')
    lipo = str(Path(toolchain) / 'bin/lipo')
    flags = ['-target', arch + '-apple-ios' + minimum, '-isysroot', str(sdk), '-miphoneos-version-min=' + minimum,
             '-std=gnu99', '-O3', '-DNDEBUG', '-fno-common', '-w'] + list(extra_flags)
    signature = fingerprint([archive_source, Path(__file__)], values=[arch, list(compiler), flags, TARGETS[arch][1], COMMON_OPTIONS, libtool])
    stamp = work / 'build-state.json'
    public = include / 'vpx'
    if not cache_matches(stamp, signature, [library]) or not public.is_dir():
        sources = configure(source, config, arch)
        if objects_dir.exists():
            shutil.rmtree(objects_dir)
        objects_dir.mkdir(parents=True)
        command = list(compiler) + flags + ['-I' + str(config), '-I' + str(source)]
        objects = []
        for item in sources:
            relative = item.relative_to(config) if config in item.parents else item.relative_to(source)
            objects.append(objects_dir / (str(relative).replace('/', '_') + '.o'))

        def compile_source(item, obj):
            subprocess.run(command + ['-c', str(item), '-o', str(obj)], check=True)

        with ThreadPoolExecutor(max_workers=max(1, min(jobs, len(sources)))) as executor:
            futures = [executor.submit(compile_source, item, obj) for item, obj in zip(sources, objects)]
            for future in as_completed(futures):
                future.result()
        if library.exists() or library.is_symlink():
            library.unlink()
        subprocess.run([libtool, '-static', '-o', str(library)] + [str(obj) for obj in objects], check=True)
        include.mkdir(parents=True, exist_ok=True)
        if public.is_symlink() or public.exists():
            public.unlink()
        public.symlink_to(os.path.relpath(source / 'vpx', include))
        cache_record(stamp, signature, [library])
    subprocess.run([lipo, str(library), '-verify_arch', arch], check=True)
    return LibvpxBuild(library, include)
