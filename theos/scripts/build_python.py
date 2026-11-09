#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

from artifact_cache import cache_matches, cache_record, fingerprint
from bootstrap_build import download, safe_unpack, validate_sha256
from generate import OUT
from toolchain_flags import codegen_flags
from xcode_graph import ROOT

SOURCE = ROOT / 'thirdparty' / 'cpython'
PLUGIN_SOURCE = ROOT / 'OnegramPlugins' / 'python'
RUNTIME_BUILDER = Path(__file__).resolve().with_name('python_runtime.py')
SQLITE = ROOT / 'thirdparty' / 'sqlcipher'
WORK = ROOT / 'theos' / 'generated'
VERSION = '3.11'
STDLIB_ARCHIVE = 'python' + VERSION.replace('.', '') + '.zip'
PLUGIN_ARCHIVE = 'onegram.zip'
PACKAGES_ARCHIVE = 'packages.zip'
FROZEN_HEADER = 'onegram_frozen.h'
PYTHON_HOSTS = {'armv7': 'arm-linux-gnueabi', 'arm64': 'aarch64-linux-gnu'}
DARWIN_HOSTS = {'armv7': 'arm-apple-darwin', 'arm64': 'aarch64-apple-darwin'}
DEPENDENCIES = {
    'libffi': ('https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz',
               'b0dea9df23c863a7a50e825440f3ebffabd65df1497108e5d437747843895a4e', 'libffi-3.4.6'),
    'xz': ('https://github.com/tukaani-project/xz/releases/download/v5.4.6/xz-5.4.6.tar.gz',
           'aeba3e03bf8140ddedf62a0a367158340520f6b384f75ca6045ccc6c0d43fd5c', 'xz-5.4.6'),
    'openssl': ('https://github.com/openssl/openssl/releases/download/openssl-3.0.15/openssl-3.0.15.tar.gz',
                '23c666d0edf20f14249b3d8f0368acaee9ab585b09e1de82107c66e1f3ec9533', 'openssl-3.0.15'),
}
PYTHON_PACKAGES = {
    'requests': ('https://files.pythonhosted.org/packages/a0/f4/c67b0b3f1b9245e8d266f0f112c500d50e5b4e83cb6f3b71b6528104182a/requests-2.34.2-py3-none-any.whl',
                 '2a0d60c172f83ac6ab31e4554906c0f3b3588d37b5cb939b1c061f4907e278e0', '2.34.2'),
    'urllib3': ('https://files.pythonhosted.org/packages/92/9d/c4e665119135114480843e7ab388fa94d8480650450e6f8e26b70d323a4c/urllib3-2.8.0-py3-none-any.whl',
                '0cf3cae568d36aa9576b28dfb35f11328f1cb974ca7647d9475ebb86c75ac6e3', '2.8.0'),
    'idna': ('https://files.pythonhosted.org/packages/58/a2/bb081bab032533a855d44de1d56f8e8426114ff1ba5d1f07a438a0a654f8/idna-3.20-py3-none-any.whl',
             'ab7ae7122974553370f0bdb919e1a960b2cd1bc1ef0276416d896db81c14582c', '3.20'),
    'charset-normalizer': ('https://files.pythonhosted.org/packages/fc/ad/d07d7862a62ffa6d79d68074d14823243dd235a77c45262acbf6adeb28bf/charset_normalizer-3.5.2-py3-none-any.whl',
                           'b6b751274acb69d77b3323d6b7dbaa3c7fdfc1eb829b7eb61d262f32e1af9685', '3.5.2'),
    'certifi': ('https://files.pythonhosted.org/packages/32/d1/a3652fe2c19134d0d15922177821d863cbd7e842d53a21bbe7e8e3a1b5ac/certifi-2026.10.23-py3-none-any.whl',
                'e9b54de76e530bb6cf0ccd036787103acb58fd42ba930ea8bf948ddbaa2f61d1', '2026.10.23'),
    'packaging': ('https://files.pythonhosted.org/packages/63/34/ba1c580383c9eada3711951fef0795c80b829a078d72188184bcab9dd527/packaging-26.3-py3-none-any.whl',
                  'd7193f7c8e4e93f444fde0262bf90af30e16fa0ad0ad44cb553c87339b23cd1c', '26.3'),
    'PyYAML': ('https://files.pythonhosted.org/packages/05/8e/961c0007c59b8dd7729d542c61a4d537767a59645b82a0b521206e1e25c2/pyyaml-6.0.3.tar.gz',
               'd76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f', '6.0.3'),
    'beautifulsoup4': ('thirdparty/python-packages/beautifulsoup4-4.15.0.tar.gz',
                       '288e3ca7d54b06f2ac191970bc275c1939cb46d450b255bf6718b04aa37ab4f7', '4.15.0'),
    'soupsieve': ('thirdparty/python-packages/soupsieve-2.10.tar.gz',
                  '49e9380d7d2905463583bafe285e818c7366a9ed7b3aee221c1ac79c905d8bc0', '2.10'),
    'typing-extensions': ('https://files.pythonhosted.org/packages/49/d3/b8441a820a491ddfc024b0b0cf0393375b75ea13866d9c66727e54c2fc80/typing_extensions-4.16.0-py3-none-any.whl',
                          '481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8', '4.16.0'),
    'debugpy': ('https://files.pythonhosted.org/packages/56/3d/c7dc9f35bc9e22cdb53679f844bee40fd5cff871862f60595869a433400d/debugpy-1.8.22-py2.py3-none-any.whl',
                'a9e9d3550e15ca479c59333e90845029190531f0cacfedab3b815a57bd913947', '1.8.22'),
}
VENDOR_SOURCES = {
    'requests': ('requests-2.34.2.tar.gz', 'f288924cae4e29463698d6d60bc6a4da69c89185ad1e0bcc4104f584e960b9ed', 'requests'),
    'urllib3': ('urllib3-2.8.0.tar.gz', '63bf2ead4c879426ebf22ef2a781eeb4aa3b4ae798a0435506f8687fd5bb9b63', 'urllib3'),
    'idna': ('idna-3.20.tar.gz', 'a7db850025b95ded1eae8a46181a1a6c56c92c96f0e2b005d9ff8dc0210cab44', 'idna'),
    'charset-normalizer': ('charset_normalizer-3.5.2.tar.gz', '39de2a259fc954455c57274dc94c79d5842774e1247a016aff30bc0efed0f4ef', 'charset_normalizer'),
    'beautifulsoup4': ('beautifulsoup4-4.15.0.tar.gz', '288e3ca7d54b06f2ac191970bc275c1939cb46d450b255bf6718b04aa37ab4f7', 'bs4'),
    'soupsieve': ('soupsieve-2.10.tar.gz', '49e9380d7d2905463583bafe285e818c7366a9ed7b3aee221c1ac79c905d8bc0', 'soupsieve'),
}
OPENSSL_TARGETS = {
    'arm64': {'bn_ops': 'SIXTY_FOUR_BIT_LONG RC4_CHAR', 'asm_arch': 'aarch64', 'perlasm_scheme': 'ios64'},
    'armv7': {'bn_ops': 'BN_LLONG RC4_CHAR', 'asm_arch': 'armv4', 'perlasm_scheme': 'ios32',
              'lib_cppflags': '-DBROKEN_CLANG_ATOMICS'},
}
OPENSSL_OPTIONS = ['no-shared', 'no-module', 'no-dso', 'no-engine', 'no-tests', 'no-ui-console']
OPENSSL_MODULES = {'_ssl': '_ssl.o', '_hashlib': '_hashopenssl.o'}
BUNDLED_LIBRARIES = ['Modules/_decimal/libmpdec/libmpdec.a', 'Modules/expat/libexpat.a']
SUPPORT_LIBRARIES = ['libffi.a', 'liblzma.a']
DISABLED_MODULES = ['_tkinter', '_curses', '_curses_panel', 'readline', '_gdbm', '_dbm',
                    'nis', 'spwd', 'ossaudiodev', '_crypt', 'xxlimited', 'xxlimited_35', '_xxsubinterpreters',
                    '_testcapi', '_testinternalcapi', '_testbuffer', '_testimportmultiple', '_testmultiphase',
                    '_ctypes_test', 'xxsubtype', '_scproxy']
CONFIG_CACHE = {
    'ac_cv_computed_gotos': 'yes',
    'ac_cv_file__dev_ptmx': 'no',
    'ac_cv_file__dev_ptc': 'no',
    'ac_cv_buggy_getaddrinfo': 'no',
    'ac_cv_func_system': 'no',
    'ac_cv_func_getentropy': 'no',
    'ac_cv_func_clock_gettime': 'no',
    'ac_cv_func_clock_getres': 'no',
    'ac_cv_func_clock_settime': 'no',
    'ac_cv_func_futimens': 'no',
    'ac_cv_func_utimensat': 'no',
    'ac_cv_func_preadv': 'no',
    'ac_cv_func_pwritev': 'no',
    'ac_cv_func_mkfifoat': 'no',
    'ac_cv_func_mknodat': 'no',
    'ac_cv_func_sem_clockwait': 'no',
    'ac_cv_func_sendfile': 'no',
}
SQLITE_CACHE = {'ac_cv_lib_sqlite3_sqlite3_' + name: 'yes' for name in (
    'bind_double', 'column_decltype', 'column_double', 'complete', 'enable_shared_cache', 'load_extension',
    'progress_handler', 'result_double', 'serialize', 'set_authorizer', 'trace', 'trace_v2', 'value_double')}
CTYPES_MODULE = ('_ctypes _ctypes/_ctypes.c _ctypes/callbacks.c _ctypes/callproc.c _ctypes/stgdict.c _ctypes/cfield.c '
                 '-DHAVE_FFI_PREP_CIF_VAR -DHAVE_FFI_PREP_CLOSURE_LOC -DHAVE_FFI_CLOSURE_ALLOC')


class Target:
    def __init__(self, arch, deployment, sdk, toolchain):
        self.arch = arch
        self.deployment = deployment
        self.sdk = sdk
        self.tools = toolchain / 'bin'
        self.flags = ['-target', arch + '-apple-ios' + deployment, '-isysroot', str(sdk),
                      '-miphoneos-version-min=' + deployment, '-fno-common', '-Os', '-D_DARWIN_C_SOURCE',
                      '-Werror=unguarded-availability', '-Werror=unguarded-availability-new',
                      '-Werror=partial-availability'] + codegen_flags(arch)
        self.compiler = ' '.join([str(self.tools / 'clang')] + self.flags)

    def compiler_with_optimization(self, optimization):
        flags = [optimization if flag == '-Os' else flag for flag in self.flags]
        return ' '.join([str(self.tools / 'clang')] + flags)

    def tool(self, name):
        return str(self.tools / name)

    def signature_values(self):
        return [self.arch, self.deployment, str(self.sdk), self.flags]


def clean_environment():
    env = os.environ.copy()
    for name in ('MAKEFLAGS', 'GNUMAKEFLAGS', 'MFLAGS', 'MAKELEVEL', 'MAKE', 'CC', 'CXX', 'CPP', 'CFLAGS', 'CXXFLAGS',
                 'LDFLAGS', 'CPPFLAGS', 'LIBS', 'AR', 'RANLIB', 'PYTHONPATH', 'PYTHONHOME', 'CONFIG_SITE',
                 'PKG_CONFIG', 'PKG_CONFIG_PATH', 'PKG_CONFIG_LIBDIR', 'PKG_CONFIG_SYSROOT_DIR'):
        env.pop(name, None)
    return env


def host_environment():
    env = clean_environment()
    for name in ('DEVELOPER_DIR', 'SDKROOT', 'IPHONEOS_DEPLOYMENT_TARGET', 'MACOSX_DEPLOYMENT_TARGET'):
        env.pop(name, None)
    if sys.platform != 'darwin':
        return env
    from setup_macos_toolchain import RECIPE, native_root
    tools = native_root() / 'tools'
    sdk = native_root() / json.loads(RECIPE.read_text())['host_sdk']['name']
    flags = shlex.join(['-isysroot', str(sdk), '-mmacosx-version-min=11.0'])
    env.update(CC=str(tools / 'bin' / 'clang'), CXX=str(tools / 'bin' / 'clang++'), CFLAGS=flags,
               LDFLAGS=flags + ' -Wl,-rpath,' + str(tools / 'lib'), SDKROOT=str(sdk),
               PATH=str(tools / 'bin') + os.pathsep + env.get('PATH', ''))
    return env


def target_environment(prefix):
    env = clean_environment()
    env['PKG_CONFIG_LIBDIR'] = str(prefix / 'lib' / 'pkgconfig')
    return env


def run(command, cwd, env, log):
    with open(log, 'a') as output:
        output.write('$ ' + ' '.join(str(part) for part in command) + '\n')
        output.flush()
        result = subprocess.run([str(part) for part in command], cwd=str(cwd), env=env, stdout=output, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        sys.stderr.write(Path(log).read_text(errors='replace')[-6000:])
        raise SystemExit('Python build step failed: ' + ' '.join(str(part) for part in command))


def ensure_source():
    if not (SOURCE / 'configure').exists():
        raise SystemExit('CPython source is missing: ' + str(SOURCE))
    for script in ('configure', 'config.guess', 'config.sub', 'install-sh', 'Modules/makesetup'):
        path = SOURCE / script
        path.chmod(path.stat().st_mode | 0o111)
    if not (SQLITE / 'sqlite3.h').exists():
        raise SystemExit('SQLite source is missing: ' + str(SQLITE))


def build_machine():
    return subprocess.check_output([str(SOURCE / 'config.guess')]).decode().strip()


def write_config_site(path, entries):
    path.write_text(''.join(name + '=' + value + '\n' for name, value in sorted(entries.items())))


def prepare_build(directory, signature):
    marker = directory / 'onegram-configured'
    if marker.is_file() and marker.read_text() == signature:
        return False
    if directory.exists():
        shutil.rmtree(directory)
    directory.mkdir(parents=True)
    return True


def mark_configured(directory, signature):
    (directory / 'onegram-configured').write_text(signature)


def dependency_source(name):
    url, checksum, folder = DEPENDENCIES[name]
    archives = OUT / 'dependency-sources'
    archives.mkdir(parents=True, exist_ok=True)
    archive = archives / url.rsplit('/', 1)[1]
    if not archive.is_file():
        partial = archive.with_name(archive.name + '.part')
        download(url, partial)
        partial.replace(archive)
    validate_sha256(archive, checksum)
    root = WORK / 'python-sources'
    source = root / folder
    marker = root / (folder + '.sha256')
    if not (source.is_dir() and marker.is_file() and marker.read_text() == checksum):
        if source.exists():
            shutil.rmtree(source)
        root.mkdir(parents=True, exist_ok=True)
        safe_unpack(archive, root)
        marker.write_text(checksum)
    return source, checksum


def build_autotools_dependency(name, target, prefix, jobs, arguments, outputs, optimization=None):
    source, checksum = dependency_source(name)
    build = WORK / ('python-' + name + '-' + target.arch)
    stamp = prefix / (name + '-state.json')
    signature = fingerprint([], values=[checksum, arguments, optimization, target.signature_values(), sorted(CONFIG_CACHE.items())])
    products = [prefix / output for output in outputs]
    if cache_matches(stamp, signature, products):
        return
    env = target_environment(prefix)
    site = build / 'config.site'
    log = build / 'build.log'
    if prepare_build(build, signature):
        write_config_site(site, CONFIG_CACHE)
        env['CONFIG_SITE'] = str(site)
        run([source / 'configure', '--host=' + DARWIN_HOSTS[target.arch], '--build=' + build_machine(),
             '--prefix=' + str(prefix), '--disable-shared', '--enable-static'] + arguments +
            ['CC=' + (target.compiler_with_optimization(optimization) if optimization else target.compiler),
             'CCAS=' + (target.compiler_with_optimization(optimization) if optimization else target.compiler), 'AR=' + target.tool('llvm-ar'),
             'RANLIB=' + target.tool('ranlib')], build, env, log)
        mark_configured(build, signature)
    env['CONFIG_SITE'] = str(site)
    run(['make', '-j' + str(jobs)], build, env, log)
    run(['make', 'install'], build, env, log)
    cache_record(stamp, signature, products)


def build_openssl(target, prefix, jobs):
    source, checksum = dependency_source('openssl')
    build = WORK / ('python-openssl-' + target.arch)
    stamp = prefix / 'openssl-state.json'
    name = 'onegram-ios-' + target.arch
    definition = OPENSSL_TARGETS[target.arch]
    configuration = ('my %targets = (\n    "' + name + '" => {\n        inherit_from => [ "ios-common" ],\n' +
                     ''.join('        ' + key + ' => "' + value + '",\n' for key, value in sorted(definition.items())) +
                     '    },\n);\n')
    signature = fingerprint([], values=[checksum, configuration, OPENSSL_OPTIONS, '-O2', target.signature_values()])
    products = [prefix / 'lib' / 'libssl.a', prefix / 'lib' / 'libcrypto.a', prefix / 'include' / 'openssl']
    if cache_matches(stamp, signature, products):
        return
    env = target_environment(prefix)
    log = build / 'build.log'
    if prepare_build(build, signature):
        conf = build / 'onegram-ios.conf'
        conf.write_text(configuration)
        run(['perl', source / 'Configure', name, '--config=' + str(conf), '--prefix=' + str(prefix),
             '--openssldir=/var/empty', '--libdir=lib'] + OPENSSL_OPTIONS +
            ['CC=' + target.compiler_with_optimization('-O2'), 'AR=' + target.tool('llvm-ar'), 'RANLIB=' + target.tool('ranlib')], build, env, log)
        mark_configured(build, signature)
    run(['make', '-j' + str(jobs), 'build_libs'], build, env, log)
    run(['make', 'install_dev'], build, env, log)
    cache_record(stamp, signature, products)


def libffi_arguments(target):
    arguments = ['--disable-docs', '--disable-multi-os-directory']
    header = target.sdk / 'usr' / 'include' / 'mach' / 'arm' / 'vm_param.h'
    if 'PAGE_MAX_SHIFT' not in header.read_text(errors='replace'):
        arguments.append('CPPFLAGS=-DPAGE_MAX_SHIFT=14 -DPAGE_MAX_SIZE=16384')
    return arguments


def build_dependencies(target, jobs):
    prefix = WORK / ('python-prefix-' + target.arch)
    build_autotools_dependency('libffi', target, prefix, jobs, libffi_arguments(target),
                               ['lib/libffi.a', 'include/ffi.h', 'include/ffitarget.h'], optimization='-O2')
    build_autotools_dependency('xz', target, prefix, jobs,
                               ['--disable-xz', '--disable-xzdec', '--disable-lzmadec', '--disable-lzmainfo',
                                '--disable-lzma-links', '--disable-scripts', '--disable-doc', '--disable-nls'],
                               ['lib/liblzma.a', 'include/lzma.h', 'include/lzma'])
    build_openssl(target, prefix, jobs)
    return prefix


def build_host_python(jobs):
    host_prefix = WORK / 'hostpython'
    host_build = WORK / 'hostpython-build'
    executable = host_prefix / 'bin' / ('python' + VERSION)
    stamp = host_prefix / 'build-state.json'
    arguments = ['--prefix=' + str(host_prefix), '--without-ensurepip', '--disable-test-modules']
    signature = fingerprint([SOURCE / 'configure', SOURCE / 'Include' / 'patchlevel.h'], values=[VERSION, arguments])
    if executable.exists() and cache_matches(stamp, signature, [executable]):
        return executable
    env = host_environment()
    log = host_build / 'build.log'
    if prepare_build(host_build, signature):
        run([SOURCE / 'configure'] + arguments, host_build, env, log)
        mark_configured(host_build, signature)
    run(['make', '-j' + str(jobs)], host_build, env, log)
    run(['make', 'install'], host_build, env, log)
    shutil.rmtree(host_build)
    cache_record(stamp, signature, [executable])
    return executable


def require_modules(log):
    missing = re.findall(r'checking for stdlib extension module (\S+)\.\.\. missing', Path(log).read_text(errors='replace'))
    if missing:
        raise SystemExit('Python modules are missing build dependencies: ' + ', '.join(sorted(set(missing))))


def static_module_setup(build, prefix):
    stdlib = (build / 'Modules' / 'Setup.stdlib').read_text()
    return stdlib + '\n*static*\n' + CTYPES_MODULE + ' -I' + str(prefix / 'include') + '\n'


def isolate_openssl(target, build, archive, prefix, env, log):
    work = build / 'onegram-openssl'
    if work.exists():
        shutil.rmtree(work)
    work.mkdir()
    members = sorted(OPENSSL_MODULES.values())
    run([target.tool('llvm-ar'), 'x', archive] + members, work, env, log)
    combined = 'onegram_openssl_modules.o'
    exports = []
    for module in sorted(OPENSSL_MODULES):
        exports += ['-exported_symbol', '_PyInit_' + module]
    run([target.tool('ld'), '-r', '-arch', target.arch, '-syslibroot', target.sdk,
         '-iphoneos_version_min', target.deployment, '-o', combined] + members +
        [prefix / 'lib' / 'libssl.a', prefix / 'lib' / 'libcrypto.a'] + exports, work, env, log)
    run([target.tool('llvm-ar'), 'd', archive] + members, work, env, log)
    run([target.tool('llvm-ar'), '--format=darwin', 'rs', archive, combined], work, env, log)
    shutil.rmtree(work)


def build_target_python(target, host_python, prefix, jobs):
    interpreter_compiler = target.compiler_with_optimization('-O2')
    products = OUT / 'products'
    products.mkdir(parents=True, exist_ok=True)
    library = products / ('libpython' + VERSION + '.a')
    headers = OUT / 'python-include'
    runtime = OUT / 'python-runtime'
    archive_output = runtime / STDLIB_ARCHIVE
    build = WORK / ('python-build-' + target.arch)
    stamp = OUT / 'python-build-state.json'
    cache = dict(CONFIG_CACHE, **SQLITE_CACHE)
    cache.update({'py_cv_module_' + name: 'n/a' for name in DISABLED_MODULES})
    include = str(prefix / 'include')
    libraries = str(prefix / 'lib')
    arguments = ['--host=' + PYTHON_HOSTS[target.arch], '--build=' + build_machine(),
                 '--with-build-python=' + str(host_python), '--prefix=/python', '--disable-shared', '--without-ensurepip',
                 '--disable-test-modules', '--with-pymalloc', '--without-doc-strings',
                 '--with-openssl=' + str(prefix), '--with-openssl-rpath=no',
                 'CC=' + interpreter_compiler, 'CPP=' + interpreter_compiler + ' -E', 'CFLAGS=-O2',
                 'AR=' + target.tool('llvm-ar'), 'RANLIB=' + target.tool('ranlib'), 'READELF=true',
                 'LIBFFI_CFLAGS=-I' + include, 'LIBFFI_LIBS=-L' + libraries + ' -lffi',
                 'LIBLZMA_CFLAGS=-I' + include, 'LIBLZMA_LIBS=-L' + libraries + ' -llzma',
                 'LIBSQLITE3_CFLAGS=-I' + str(SQLITE), 'LIBSQLITE3_LIBS=-lsqlite3',
                 'ZLIB_CFLAGS=', 'ZLIB_LIBS=-lz', 'BZIP2_CFLAGS=', 'BZIP2_LIBS=-lbz2',
                 'MODULE_BUILDTYPE=static']
    signature = fingerprint([SOURCE, SQLITE / 'sqlite3.h', target.tools / 'clang', prefix / 'openssl-state.json',
                             prefix / 'libffi-state.json', prefix / 'xz-state.json'],
                            values=[arguments, sorted(cache.items()), CTYPES_MODULE, OPENSSL_MODULES,
                                    BUNDLED_LIBRARIES, SUPPORT_LIBRARIES])
    outputs = [library, headers, archive_output]
    product_signature = fingerprint([RUNTIME_BUILDER], values=[signature])
    if cache_matches(stamp, product_signature, outputs):
        return library
    env = target_environment(prefix)
    site = build / 'config.site'
    log = build / 'build.log'
    if prepare_build(build, signature):
        write_config_site(site, cache)
        env['CONFIG_SITE'] = str(site)
        run([SOURCE / 'configure'] + arguments, build, env, log)
        require_modules(log)
        (build / 'Modules' / 'Setup.local').write_text(static_module_setup(build, prefix))
        run(['make', 'Makefile', 'Modules/config.c'], build, env, log)
        mark_configured(build, signature)
    env['CONFIG_SITE'] = str(site)
    run(['make', '-j' + str(jobs), 'ARFLAGS=--format=darwin rcs', 'OPT=-O2', 'CFLAGS=-O2', 'libpython' + VERSION + '.a', 'pybuilddir.txt'] + BUNDLED_LIBRARIES, build, env, log)
    archive = build / ('libpython' + VERSION + '.a')
    interpreter = build / ('onegram-interpreter' + VERSION + '.a')
    staged = build / ('onegram-libpython' + VERSION + '.a')
    shutil.copyfile(archive, interpreter)
    isolate_openssl(target, build, interpreter, prefix, env, log)
    run([target.tool('libtool'), '-static', '-o', staged, interpreter] + [build / name for name in BUNDLED_LIBRARIES] +
        [prefix / 'lib' / name for name in SUPPORT_LIBRARIES], build, env, log)
    interpreter.unlink()
    run([target.tool('lipo'), staged, '-verify_arch', target.arch], build, env, log)
    shutil.move(str(staged), str(library))
    if headers.exists():
        shutil.rmtree(headers)
    shutil.copytree(SOURCE / 'Include', headers)
    shutil.copyfile(build / 'pyconfig.h', headers / 'pyconfig.h')
    package_runtime(host_python, build, headers, archive_output, env, log)
    cache_record(stamp, product_signature, outputs)
    return library


def package_runtime(host_python, build, headers, archive_output, env, log):
    directory = build / (build / 'pybuilddir.txt').read_text().strip()
    modules = sorted(directory.glob('_sysconfigdata_*.py'))
    if len(modules) != 1:
        raise SystemExit('Expected one sysconfig data module in ' + str(directory))
    archive_output.parent.mkdir(parents=True, exist_ok=True)
    run([host_python, '-I', RUNTIME_BUILDER, 'archive', '--output', archive_output, SOURCE / 'Lib'], build, env, log)
    run([host_python, '-I', RUNTIME_BUILDER, 'frozen', '--output', headers / FROZEN_HEADER,
         '--module', modules[0].stem, modules[0]], build, env, log)


def package_plugin_runtime(host_python):
    output = OUT / 'python-runtime' / PLUGIN_ARCHIVE
    stamp = OUT / 'python-plugin-runtime-state.json'
    signature = fingerprint([PLUGIN_SOURCE, RUNTIME_BUILDER, host_python])
    if cache_matches(stamp, signature, [output]):
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    log = WORK / 'python-plugin-runtime.log'
    log.write_text('')
    run([host_python, '-I', RUNTIME_BUILDER, 'archive', '--output', output, PLUGIN_SOURCE], WORK, clean_environment(), log)
    cache_record(stamp, signature, [output])


def build_packages_archive(archives, output, host_python=None):
    WORK.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='python-packages-', dir=WORK) as directory:
        staging = Path(directory)
        root = staging / 'packages'
        root.mkdir()
        for name, archive in sorted(archives.items()):
            if name == 'PyYAML':
                extracted = staging / 'pyyaml'
                extracted.mkdir()
                safe_unpack(archive, extracted)
                packages = [path.parent for path in extracted.rglob('lib/yaml/__init__.py')]
                if len(packages) != 1:
                    raise RuntimeError('PyYAML source must contain exactly one lib/yaml package')
                shutil.copytree(packages[0], root / 'yaml')
                version = PYTHON_PACKAGES['PyYAML'][2]
                metadata = root / ('PyYAML-' + version + '.dist-info')
                metadata.mkdir()
                (metadata / 'METADATA').write_text('Metadata-Version: 2.1\nName: PyYAML\nVersion: ' + version + '\n')
                (metadata / 'INSTALLER').write_text('onegram\n')
            elif name in VENDOR_SOURCES:
                _, _, package = VENDOR_SOURCES[name]
                extracted = staging / ('source-' + package)
                extracted.mkdir()
                safe_unpack(archive, extracted)
                candidates = [child for child in extracted.iterdir() if child.is_dir()]
                if len(candidates) != 1:
                    raise RuntimeError('Expected one source root for ' + name)
                source = candidates[0]
                package_root = next((candidate for candidate in (source / 'src' / package, source / package)
                                     if (candidate / '__init__.py').is_file()), None)
                if package_root is None:
                    raise RuntimeError('Missing package source for ' + name)
                shutil.copytree(package_root, root / package)
                version = PYTHON_PACKAGES[name][2]
                metadata = root / (name.replace('-', '_') + '-' + version + '.dist-info')
                metadata.mkdir()
                shutil.copyfile(source / 'PKG-INFO', metadata / 'METADATA')
                (metadata / 'INSTALLER').write_text('onegram\n')
                license_names = [path for path in source.iterdir() if path.is_file() and path.name.lower().startswith(('license', 'copying', 'notice'))]
                if license_names:
                    licenses = metadata / 'licenses'
                    licenses.mkdir()
                    for license_path in license_names:
                        shutil.copyfile(license_path, licenses / license_path.name)
            else:
                safe_unpack(archive, root)
        output.parent.mkdir(parents=True, exist_ok=True)
        if host_python is None:
            from python_runtime import write_archive
            write_archive([root], output)
        else:
            log = WORK / 'python-packages.log'
            log.write_text('')
            run([host_python, '-I', RUNTIME_BUILDER, 'archive', '--output', output, root], WORK, clean_environment(), log)


def package_python_packages(host_python):
    output = OUT / 'python-runtime' / PACKAGES_ARCHIVE
    stamp = OUT / 'python-packages-state.json'
    vendors = [ROOT / 'thirdparty' / 'python-packages' / source[0] for source in VENDOR_SOURCES.values()]
    signature = fingerprint([Path(__file__), RUNTIME_BUILDER, Path(__file__).with_name('bootstrap_build.py'), host_python] + vendors,
                            values=[sorted(PYTHON_PACKAGES.items()), sorted(VENDOR_SOURCES.items())])
    if cache_matches(stamp, signature, [output]):
        return
    cache = WORK / 'python-package-sources'
    cache.mkdir(parents=True, exist_ok=True)
    archives = {}
    for name, (url, checksum, _) in PYTHON_PACKAGES.items():
        if name in VENDOR_SOURCES:
            filename, vendor_hash, _ = VENDOR_SOURCES[name]
            archive = ROOT / 'thirdparty' / 'python-packages' / filename
            if not archive.is_file():
                raise RuntimeError('Bundled Python package source is missing: ' + str(archive))
            validate_sha256(archive, vendor_hash)
            archives[name] = archive
            continue
        archive = cache / url.rsplit('/', 1)[-1]
        if archive.exists():
            try:
                validate_sha256(archive, checksum)
            except RuntimeError:
                archive.unlink()
        if not archive.exists():
            with tempfile.NamedTemporaryFile(dir=cache, delete=False) as stream:
                temporary = Path(stream.name)
            try:
                download(url, temporary)
                validate_sha256(temporary, checksum)
                temporary.replace(archive)
            finally:
                temporary.unlink(missing_ok=True)
        archives[name] = archive
    build_packages_archive(archives, output, host_python)
    cache_record(stamp, signature, [output])


def main():
    global SOURCE, WORK
    parser = argparse.ArgumentParser()
    parser.add_argument('--arch', required=True, choices=sorted(PYTHON_HOSTS))
    parser.add_argument('--sdk', required=True, type=Path)
    parser.add_argument('--toolchain', required=True, type=Path)
    parser.add_argument('--deployment', required=True)
    parser.add_argument('--jobs', type=int, default=os.cpu_count() or 2)
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--work', type=Path, default=WORK)
    args = parser.parse_args()
    SOURCE = args.source.resolve()
    WORK = args.work.resolve()
    ensure_source()
    target = Target(args.arch, args.deployment, args.sdk.resolve(), args.toolchain)
    host_python = build_host_python(args.jobs)
    prefix = build_dependencies(target, args.jobs)
    build_target_python(target, host_python, prefix, args.jobs)
    package_plugin_runtime(host_python)
    package_python_packages(host_python)


if __name__ == '__main__':
    main()
