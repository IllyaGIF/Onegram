#!/usr/bin/env python3
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess


def builtin_sources(directory, architecture):
    text = (directory / 'CMakeLists.txt').read_text()
    definitions = {}
    for name, body in re.findall(r'set\((\w+_SOURCES)\s+([^)]*)\)', text, re.S):
        definitions.setdefault(name, shlex.split(re.sub(r'#[^\n]*', '', body)))
    def expand(name):
        result = []
        for entry in definitions[name]:
            variable = re.fullmatch(r'\$\{(\w+)\}', entry)
            if variable:
                result.extend(expand(variable.group(1)))
            else:
                result.append(directory / entry)
        return result
    group = {'armv6': 'GENERIC_SOURCES', 'armv7': 'arm_SOURCES', 'arm64': 'aarch64_SOURCES'}[architecture]
    selected = {}
    for source in expand(group):
        if not source.is_file():
            raise RuntimeError('Missing compiler runtime source: ' + str(source))
        previous = selected.get(source.stem)
        if previous is None or source.parent != directory:
            selected[source.stem] = source
    return sorted(selected.values())


def ensure_ios_runtime(toolchain, theos, versions, recipe):
    from bootstrap_build import download, safe_unpack, validate_sha256
    root = toolchain / '.onegram-runtime'
    root.mkdir(parents=True, exist_ok=True)
    compatibility = root / 'TargetConditionalsCompatibility.h'
    compatibility.write_text('#include <TargetConditionals.h>\n#ifndef TARGET_OS_SIMULATOR\n#define TARGET_OS_SIMULATOR TARGET_IPHONE_SIMULATOR\n#endif\n')
    archive = root / 'compiler-rt.tar.xz'
    if not archive.is_file():
        download(recipe['url'], archive)
    validate_sha256(archive, recipe['sha256'])
    sources = root / 'compiler-rt-11.1.0.src/lib/builtins'
    if not (sources / 'CMakeLists.txt').is_file():
        safe_unpack(archive, root)
    dispatch_headers = None
    if '3.1.3' in versions:
        dependencies = Path(__file__).resolve().parents[1] / 'generated/armv6/dependency-sources'
        dispatch_headers = dependencies / 'libdispatch-libdispatch-187.10'
        if not (dispatch_headers / 'dispatch/dispatch.h').is_file():
            dependencies.mkdir(parents=True, exist_ok=True)
            dispatch_archive = dependencies / 'libdispatch-187.10.tar.gz'
            if not dispatch_archive.is_file():
                download('https://github.com/apple-oss-distributions/libdispatch/archive/refs/tags/libdispatch-187.10.tar.gz', dispatch_archive)
            validate_sha256(dispatch_archive, 'd6a4ea662d57cbb45d15fd6057a9671a4da4aefdc6a37b54a8292e021cbb7b42')
            safe_unpack(dispatch_archive, dependencies)
    marker = root / 'installed.json'
    output = toolchain / 'lib/clang/11.1.0/lib/darwin/libclang_rt.ios.a'
    signature = hashlib.sha256((Path(__file__).read_text() + str(theos) + str(toolchain) + str(versions) + recipe['sha256']).encode()).hexdigest()
    if marker.is_file() and output.is_file() and not output.is_symlink():
        data = json.loads(marker.read_text())
        if data.get('signature') == signature and data.get('binary') == hashlib.sha256(output.read_bytes()).hexdigest():
            return
    tools = toolchain / 'bin'
    architectures = {'3.1.3': ('armv6', '3.1.3'), '6.1': ('armv7', '4.3'), '11.2': ('arm64', '7.0')}
    print('[Onegram setup] Preparing native iOS compiler runtime', flush=True)
    slices = []
    log = root / 'build.log'
    with log.open('w') as stream:
        for version in versions:
            architecture, deployment = architectures[version]
            directory = root / architecture
            directory.mkdir(exist_ok=True)
            selected = builtin_sources(sources, architecture)
            objects = [directory / (source.stem + '.o') for source in selected]
            def compile_source(entry):
                source, obj = entry
                command = [str(tools / 'clang'), '-target', architecture + '-apple-ios' + deployment,
                           '-isysroot', str(theos / ('sdks/iPhoneOS' + version + '.sdk')),
                           '-O2', '-fPIC', '-fvisibility=hidden', '-ffreestanding', '-fno-builtin',
                           '-fno-stack-protector', '-fblocks', '-I' + str(sources), '-include', str(compatibility)]
                if architecture == 'armv6':
                    command += ['-I' + str(Path(__file__).resolve().parents[1] / 'compat/ios3/libdispatch')]
                    command += ['-I' + str(dispatch_headers)]
                command += ['-c', str(source), '-o', str(obj)]
                result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
                if result.returncode:
                    raise RuntimeError('Compiler runtime preparation failed; full log: ' + str(log))
            with ThreadPoolExecutor(max_workers=min(4, os.cpu_count() or 2)) as executor:
                list(executor.map(compile_source, zip(selected, objects)))
            library = directory / 'builtins.a'
            subprocess.run([str(tools / 'libtool'), '-static', '-o', str(library)] + [str(obj) for obj in objects],
                           stdout=stream, stderr=subprocess.STDOUT, check=True)
            subprocess.run([str(tools / 'lipo'), str(library), '-verify_arch', architecture], check=True)
            slices.append(library)
        staged = output.with_name('libclang_rt.ios.install.a')
        subprocess.run([str(tools / 'lipo'), '-create'] + [str(path) for path in slices] + ['-output', str(staged)],
                       stdout=stream, stderr=subprocess.STDOUT, check=True)
        os.replace(staged, output)
    marker.write_text(json.dumps({'signature': signature, 'binary': hashlib.sha256(output.read_bytes()).hexdigest()}, sort_keys=True) + '\n')
