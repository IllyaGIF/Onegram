#!/usr/bin/env python3
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import inspect
import os
from pathlib import Path
import platform
import shutil
import shlex
import subprocess
import sys
import tarfile
import urllib.request
from generate import OUT
from xcode_graph import ROOT
from artifact_cache import cache_matches, cache_record, fingerprint


def install_archive(source, destination, ranlib):
    signature = fingerprint([source, Path(ranlib)])
    stamp = destination.with_suffix('.install-state.json')
    if cache_matches(stamp, signature, [destination]):
        return
    shutil.copy2(source, destination)
    run([ranlib, destination])
    cache_record(stamp, signature, [destination])


def tool(name, tools):
    candidates = [tools / name, tools / ('llvm-' + name)]
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    raise SystemExit('Missing toolchain utility: ' + str(tools / name))


def clang_resource_dir(clang):
    result = subprocess.run([clang, '-print-resource-dir'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    if result.returncode == 0:
        path = Path(result.stdout.strip())
        if (path / 'include').is_dir():
            return path
    compiler_root = Path(clang).resolve().parent.parent
    candidates = []
    for root in (compiler_root / 'lib/clang', compiler_root / 'lib64/clang'):
        if root.is_dir():
            candidates.extend(path for path in root.iterdir() if path.is_dir() and (path / 'include').is_dir())
    if len(candidates) == 1:
        return candidates[0]
    if not candidates:
        raise SystemExit('Unable to locate Clang resource directory for ' + str(clang))
    raise SystemExit('Multiple Clang resource directories found for ' + str(clang) + ': ' + ', '.join(str(path) for path in sorted(candidates)))


def download(url, destination, sha256=None):
    if not destination.is_file():
        urllib.request.urlretrieve(url, destination)
    if sha256 is not None:
        actual = hashlib.sha256(destination.read_bytes()).hexdigest()
        if actual != sha256:
            raise SystemExit(destination.name + ' checksum mismatch: ' + actual)


def unpack(archive, destination, expected):
    if expected.is_dir():
        return
    with tarfile.open(archive) as package:
        package.extractall(destination)
    if not expected.is_dir():
        raise SystemExit('Expected source directory was not extracted: ' + str(expected))


def write_wrapper(path, executable, arguments):
    command = 'exec ' + shlex.join([str(executable)] + [str(x) for x in arguments]) + ' "$@"\n'
    path.write_text('#!/bin/sh\n' + command)
    path.chmod(0o755)


def write_link_wrapper(path, executable, arguments, crt):
    base = shlex.join([str(executable)] + [str(x) for x in arguments])
    crt_arg = shlex.quote(str(crt))
    script = '#!/bin/sh\nlink=1\nfor arg in "$@"; do\ncase "$arg" in\n-c|-E|-S|-M|-MM|-MD|-MMD|--version|-v|-V|-qversion|-###) link=0 ;;\nesac\ndone\nif [ "$link" = 1 ]; then\nexec ' + base + ' -nostartfiles ' + crt_arg + ' "$@"\nfi\nexec ' + base + ' "$@"\n'
    path.write_text(script)
    path.chmod(0o755)


def extract_armv6_slice(source, destination, lipo):
    if destination.exists():
        destination.unlink()
    result = subprocess.run([lipo, source, '-thin', 'armv6', '-output', destination], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        data = source.read_bytes()
        if len(data) < 8 or int.from_bytes(data[0:4], 'big') != 0xcafebabe:
            raise SystemExit('Unable to extract ARMv6 CRT: ' + result.stderr.strip())
        count = int.from_bytes(data[4:8], 'big')
        found = None
        for index in range(count):
            pos = 8 + index * 20
            if pos + 20 > len(data):
                break
            cputype = int.from_bytes(data[pos:pos + 4], 'big', signed=True)
            cpusubtype = int.from_bytes(data[pos + 4:pos + 8], 'big', signed=True)
            offset = int.from_bytes(data[pos + 8:pos + 12], 'big')
            size = int.from_bytes(data[pos + 12:pos + 16], 'big')
            if cputype == 12 and (cpusubtype & 0x00ffffff) == 6 and offset + size <= len(data):
                found = data[offset:offset + size]
                break
        if found is None:
            raise SystemExit('ARMv6 slice not found in ' + str(source))
        destination.write_bytes(found)
    run([lipo, destination, '-verify_arch', 'armv6'])


def run(command, cwd=None, env=None):
    subprocess.run([str(x) for x in command], cwd=cwd, env=env, check=True)


def replace_required(path, old, new, label):
    text = path.read_text(encoding='latin-1')
    if new in text:
        return
    if old not in text:
        raise SystemExit(label + ' source changed unexpectedly: ' + str(path))
    path.write_text(text.replace(old, new, 1), encoding='latin-1')


def backport_openssl_ios_arm_perlasm(openssl):
    arm_xlate = r'''my $flavour = shift;
my $output = shift;
open STDOUT,">$output" || die "can't open $output: $!";

$flavour = "linux32" if (!$flavour or $flavour eq "void");

my %GLOBALS;
my $dotinlocallabels=($flavour=~/linux/)?1:0;
my $arch = sub {
    if ($flavour =~ /linux/) { ".arch\t".join(',',@_); }
    else { ""; }
};
my $fpu = sub {
    if ($flavour =~ /linux/) { ".fpu\t".join(',',@_); }
    else { ""; }
};
my $hidden = sub {
    if ($flavour =~ /ios/) { ".private_extern\t".join(',',@_); }
    else { ".hidden\t".join(',',@_); }
};
my $comm = sub {
    my @args = split(/,\s*/,shift);
    my $name = @args[0];
    my $global = \$GLOBALS{$name};
    my $ret;
    if ($flavour =~ /ios32/) {
        $ret = ".comm\t_$name,@args[1]\n";
        $ret .= ".non_lazy_symbol_pointer\n";
        $ret .= "$name:\n";
        $ret .= ".indirect_symbol\t_$name\n";
        $ret .= ".long\t0";
        $name = "_$name";
    } else { $ret = ".comm\t".join(',',@args); }
    $$global = $name;
    $ret;
};
my $globl = sub {
    my $name = shift;
    my $global = \$GLOBALS{$name};
    my $ret;
    SWITCH: for ($flavour) {
        /ios/ && do { $name = "_$name"; last; };
    }
    $ret = ".globl\t$name" if (!$ret);
    $$global = $name;
    $ret;
};
my $global = $globl;
my $extern = sub {
    &$globl(@_);
    return;
};
my $type = sub {
    if ($flavour =~ /linux/) { ".type\t".join(',',@_); }
    else { ""; }
};
my $size = sub {
    if ($flavour =~ /linux/) { ".size\t".join(',',@_); }
    else { ""; }
};
my $inst = sub {
    if ($flavour =~ /linux/) { ".inst\t".join(',',@_); }
    else { ".long\t".join(',',@_); }
};
my $asciz = sub {
    my $line = join(",",@_);
    if ($line =~ /^"(.*)"$/) { ".byte\t" . join(",",unpack("C*",$1),0) . "\n.align\t2"; }
    else { ""; }
};
sub range {
    my ($r,$sfx,$start,$end) = @_;
    join(",",map("$r$_$sfx",($start..$end)));
}
sub expand_line {
    my $line = shift;
    my @ret = ();
    pos($line)=0;
    while ($line =~ m/\G[^@\/\{"]*/g) {
        if ($line =~ m/\G(@|\/\/|$)/gc) {
            last;
        }
        elsif ($line =~ m/\G\{/gc) {
            my $saved_pos = pos($line);
            $line =~ s/\G([rdqv])([0-9]+)([^\-]*)\-\1([0-9]+)\3/range($1,$3,$2,$4)/e;
            pos($line) = $saved_pos;
            $line =~ m/\G[^\}]*\}/g;
        }
        elsif ($line =~ m/\G"/gc) {
            $line =~ m/\G[^"]*"/g;
        }
    }
    $line =~ s/\b(\w+)/$GLOBALS{$1} or $1/ge;
    return $line;
}
while($line=<>) {
    if ($line =~ m/^\s*(#|@|\/\/)/) { print $line; next; }
    $line =~ s|/\*.*\*/||;
    $line =~ s|^\s+||;
    $line =~ s|\s+$||;
    {
        $line =~ s|[\b\.]L(\w{2,})|L$1|g;
        $line =~ s|\bL(\w{2,})|.L$1|g if ($dotinlocallabels);
    }
    {
        if ($line =~ s|(^[\.\w]+)\:\s*||) {
            my $label = $1;
            printf "%s:",($GLOBALS{$label} or $label);
        }
    }
    if ($line !~ m/^[#@]/) {
        $line =~ s|^\s*(\.?)(\S+)\s*||;
        my $c = $1; $c = "\t" if ($c eq "");
        my $mnemonic = $2;
        my $opcode;
        if ($mnemonic =~ m/([^\.]+)\.([^\.]+)/) {
            $opcode = eval("\$$1_$2");
        }
        else {
            $opcode = eval("\$$mnemonic");
        }
        my $arg=expand_line($line);
        if (ref($opcode) eq 'CODE') {
            $line = &$opcode($arg);
        }
        elsif ($mnemonic) {
            $line = $c.$mnemonic;
            $line.= "\t$arg" if ($arg ne "");
        }
    }
    print $line if ($line);
    print "\n";
}
close STDOUT;
'''
    perlasm = openssl / 'crypto/perlasm/arm-xlate.pl'
    perlasm.write_text(arm_xlate, encoding='latin-1')

    old_output = '''while (($output=shift) && ($output!~/^\\w[\\w\\-]*\\.\\w+$/)) {}\nopen STDOUT,\">$output\";'''
    new_output = '''$flavour = shift;\nif ($flavour=~/^\\w[\\w\\-]*\\.\\w+$/) { $output=$flavour; undef $flavour; }\nelse { while (($output=shift) && ($output!~/^\\w[\\w\\-]*\\.\\w+$/)) {} }\n\nif ($flavour && $flavour ne \"void\") {\n    $0 =~ m/(.*[\\/\\\\])[^\\/\\\\]+$/; $dir=$1;\n    ( $xlate=\"${dir}arm-xlate.pl\" and -f $xlate ) or\n    ( $xlate=\"${dir}../../perlasm/arm-xlate.pl\" and -f $xlate) or\n    die \"can't locate arm-xlate.pl\";\n\n    open STDOUT,\"| \\\"$^X\\\" $xlate $flavour $output\";\n} else {\n    open STDOUT,\">$output\";\n}'''
    generators = (
        'crypto/aes/asm/aes-armv4.pl',
        'crypto/bn/asm/armv4-mont.pl',
        'crypto/bn/asm/armv4-gf2m.pl',
        'crypto/modes/asm/ghash-armv4.pl',
        'crypto/sha/asm/sha1-armv4-large.pl',
        'crypto/sha/asm/sha256-armv4.pl',
        'crypto/sha/asm/sha512-armv4.pl'
    )
    for name in generators:
        replace_required(openssl / name, old_output, new_output, 'OpenSSL ARM perlasm')

    armv4cpuid = openssl / 'crypto/armv4cpuid.S'
    armv4cpuid_source = armv4cpuid.read_bytes()
    subprocess.run(
        ['perl', str(perlasm), 'ios32', str(armv4cpuid)],
        input=armv4cpuid_source, check=True)

    aes = openssl / 'crypto/aes/asm/aes-armv4.pl'
    replace_required(
        aes,
        '''AES_encrypt:\n#if __ARM_ARCH__<7''',
        '''#ifdef\t__APPLE__\nLAES_encrypt_table_offset:\n.word\tAES_encrypt-AES_Te\n.align\t5\n#endif\nAES_encrypt:\n#if __ARM_ARCH__<7''',
        'OpenSSL AES encrypt iOS literal')
    replace_required(
        aes,
        '''private_AES_set_encrypt_key:\n_armv4_AES_set_encrypt_key:''',
        '''#ifdef\t__APPLE__\nLAES_set_encrypt_key_table_offset:\n.word\t_armv4_AES_set_encrypt_key-AES_Te-1024\n.align\t5\n#endif\nprivate_AES_set_encrypt_key:\n_armv4_AES_set_encrypt_key:''',
        'OpenSSL AES key iOS literal')
    replace_required(
        aes,
        '''AES_decrypt:\n#if __ARM_ARCH__<7''',
        '''#ifdef\t__APPLE__\nLAES_decrypt_table_offset:\n.word\tAES_decrypt-AES_Td\n.align\t5\n#endif\nAES_decrypt:\n#if __ARM_ARCH__<7''',
        'OpenSSL AES decrypt iOS literal')
    replace_required(
        aes,
        '''\tsub\t$tbl,r3,#AES_encrypt-AES_Te\t@ Te''',
        '''#ifdef\t__APPLE__\n\tldr\t$tbl,LAES_encrypt_table_offset\n\tsub\t$tbl,r3,$tbl\t@ Te\n#else\n\tsub\t$tbl,r3,#AES_encrypt-AES_Te\t@ Te\n#endif''',
        'OpenSSL AES encrypt iOS relocation')
    replace_required(
        aes,
        '''\tsub\t$tbl,r3,#_armv4_AES_set_encrypt_key-AES_Te-1024\t@ Te4''',
        '''#ifdef\t__APPLE__\n\tldr\t$tbl,LAES_set_encrypt_key_table_offset\n\tsub\t$tbl,r3,$tbl\t@ Te4\n#else\n\tsub\t$tbl,r3,#_armv4_AES_set_encrypt_key-AES_Te-1024\t@ Te4\n#endif''',
        'OpenSSL AES key iOS relocation')
    replace_required(
        aes,
        '''\tsub\t$tbl,r3,#AES_decrypt-AES_Td\t\t@ Td''',
        '''#ifdef\t__APPLE__\n\tldr\t$tbl,LAES_decrypt_table_offset\n\tsub\t$tbl,r3,$tbl\t@ Td\n#else\n\tsub\t$tbl,r3,#AES_decrypt-AES_Td\t\t@ Td\n#endif''',
        'OpenSSL AES decrypt iOS relocation')


def run_parallel(commands, jobs, cwd=None, env=None):
    commands = list(commands)
    if len(commands) <= 1 or jobs <= 1:
        for command in commands:
            run(command, cwd=cwd, env=env)
        return
    with ThreadPoolExecutor(max_workers=min(jobs, len(commands))) as executor:
        futures = [executor.submit(run, command, cwd, env) for command in commands]
        for future in futures:
            future.result()


def verify_archive(path, lipo):
    if not path.is_file():
        raise SystemExit('Missing ARMv6 archive: ' + str(path))
    run([lipo, str(path), '-verify_arch', 'armv6'])


def static_archive(output, objects, libtool, ar, ranlib):
    if output.exists() or output.is_symlink():
        output.unlink()
    if sys.platform == 'darwin':
        run([libtool, '-static', '-o', output] + objects)
        run([ranlib, output])
    else:
        run([ar, '--format=darwin', 'rcs', output] + objects)
    return output

def hash_path(hasher, path):
    path = Path(path)
    if not path.exists():
        hasher.update(b'MISSING\0')
        hasher.update(str(path).encode())
        return
    if path.is_file() or path.is_symlink():
        hasher.update(b'FILE\0')
        hasher.update(str(path).encode())
        hasher.update(b'\0')
        if path.is_symlink():
            hasher.update(os.readlink(path).encode())
        else:
            with path.open('rb') as f:
                for chunk in iter(lambda: f.read(1024 * 1024), b''):
                    hasher.update(chunk)
        return
    hasher.update(b'DIR\0')
    hasher.update(str(path).encode())
    hasher.update(b'\0')
    for child in sorted(path.rglob('*'), key=lambda item: str(item)):
        if child.is_dir():
            continue
        relative = child.relative_to(path)
        hasher.update(str(relative).encode())
        hasher.update(b'\0')
        if child.is_symlink():
            hasher.update(os.readlink(child).encode())
        else:
            with child.open('rb') as f:
                for chunk in iter(lambda: f.read(1024 * 1024), b''):
                    hasher.update(chunk)


def build_signature(label, values=(), paths=()):
    hasher = hashlib.sha256()
    hasher.update(label.encode())
    hasher.update(b'\0')
    for value in values:
        hasher.update(str(value).encode())
        hasher.update(b'\0')
    for path in paths:
        hash_path(hasher, path)
    return hasher.hexdigest()


def source_fragment(start, end):
    text = Path(__file__).read_text()
    begin = text.index(start)
    finish = text.index(end, begin)
    return text[begin:finish]


def first_existing(root, candidates):
    for candidate in candidates:
        path = root / candidate
        if path.is_file():
            return path
    return None


def cache_valid(stamp, signature, outputs):
    if not stamp.is_file():
        return False
    if stamp.read_text().strip() != signature:
        return False
    return all(Path(output).is_file() for output in outputs)


def cache_store(stamp, signature):
    stamp.parent.mkdir(parents=True, exist_ok=True)
    temporary = stamp.with_suffix(stamp.suffix + '.tmp')
    temporary.write_text(signature + '\n')
    temporary.replace(stamp)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sdk', required=True, type=Path)
    parser.add_argument('--toolchain', required=True, type=Path)
    parser.add_argument('--cc', required=True, type=Path)
    parser.add_argument('--jobs', type=int, default=max(1, os.cpu_count() or 1))
    args = parser.parse_args()
    if args.jobs < 1:
        raise SystemExit('--jobs must be at least 1')
    if not args.sdk.is_dir():
        raise SystemExit('Missing iPhoneOS3.1.3 SDK: ' + str(args.sdk))
    if not args.cc.is_file():
        raise SystemExit('Missing ARMv6 compiler: ' + str(args.cc))
    tools = args.toolchain / 'bin'
    clang = str(args.cc)
    clangxx = str(args.cc.with_name('clang++'))
    if not Path(clangxx).is_file():
        clangxx = tool('clang++', tools)
    if sys.platform == 'darwin':
        ar = tool('ar', tools)
    else:
        llvm_ar = tools / 'llvm-ar'
        if not llvm_ar.is_file():
            raise SystemExit('Missing Darwin-compatible archive tool: ' + str(llvm_ar))
        ar = str(llvm_ar)
    ranlib = tool('ranlib', tools)
    libtool = tool('libtool', tools)
    lipo = tool('lipo', tools)
    nm = tool('nm', tools)
    if sys.platform == 'darwin':
        ld = tool('ld', tools)
        driver_tool_flags = []
    else:
        darwin_ld = tools / 'ld'
        if not darwin_ld.is_file():
            raise SystemExit('Missing Darwin linker: ' + str(darwin_ld))
        ld = str(darwin_ld)
        driver_tool_flags = ['-B' + str(tools) + os.sep]
    mig = tool('mig', tools) if (tools / 'mig').is_file() else None
    sources = OUT / 'dependency-sources'
    products = OUT / 'products'
    objects = OUT / 'dependency-objects'
    wrappers = OUT / 'dependency-tools'
    for directory in (sources, products, objects, wrappers):
        directory.mkdir(parents=True, exist_ok=True)
    cc_wrapper = wrappers / 'armv6-cc'
    cxx_wrapper = wrappers / 'armv6-cxx'
    target_flags = driver_tool_flags + ['-target', 'armv6-apple-ios3.1.3', '-arch', 'armv6', '-miphoneos-version-min=3.1.3', '-isysroot', str(args.sdk)]
    ccache = shutil.which('ccache')
    cc_driver = ccache or clang
    cxx_driver = ccache or clangxx
    cc_prefix = [clang] if ccache else []
    cxx_prefix = [clangxx] if ccache else []
    write_wrapper(cc_wrapper, cc_driver, cc_prefix + target_flags)
    write_wrapper(cxx_wrapper, cxx_driver, cxx_prefix + target_flags)
    make_env = os.environ.copy()
    for name in ('MAKEFLAGS', 'GNUMAKEFLAGS', 'MFLAGS', 'MAKELEVEL', 'MAKE'):
        make_env.pop(name, None)
    if sys.platform != 'darwin':
        make_env['PATH'] = str(tools) + os.pathsep + make_env.get('PATH', '')
    make_env.update(CC=str(cc_wrapper), CXX=str(cxx_wrapper), AR=ar, RANLIB=ranlib, LD=ld)

    archives = {
        'libclosure-38.tar.gz': ('https://github.com/apple-oss-distributions/libclosure/archive/refs/tags/libclosure-38.tar.gz', None, sources / 'libclosure-libclosure-38'),
        'libdispatch-187.10.tar.gz': ('https://github.com/apple-oss-distributions/libdispatch/archive/refs/tags/libdispatch-187.10.tar.gz', None, sources / 'libdispatch-libdispatch-187.10'),
        'xnu-1504.15.3.tar.gz': ('https://github.com/apple-oss-distributions/xnu/archive/refs/tags/xnu-1504.15.3.tar.gz', None, sources / 'xnu-xnu-1504.15.3'),
        'opus-1.0.3.tar.gz': ('https://archive.mozilla.org/pub/opus/opus-1.0.3.tar.gz', '191a089c92dbc403de6980463dd3604b65beb12d283c607e246c8076363cb49c', sources / 'opus-1.0.3'),
        'libwebp-0.4.3.tar.gz': ('https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-0.4.3.tar.gz', 'efbe0d58fda936f2ed99d0b837ed7087d064d6838931f282c4618d2a3f7390c4', sources / 'libwebp-0.4.3'),
        'openssl-1.0.2h.tar.gz': ('https://codeload.github.com/openssl/openssl/tar.gz/refs/tags/OpenSSL_1_0_2h', '2cadf888883690320fb638b651ee4d1cf90ec656a0e3b89ba3419592c2080e9f', sources / 'openssl-OpenSSL_1_0_2h')
    }
    for name, (url, digest, directory) in archives.items():
        archive = sources / name
        download(url, archive, digest)
        unpack(archive, sources, directory)

    closure = sources / 'libclosure-libclosure-38'
    compat = ROOT / 'theos/compat/ios3'
    compiler_identity = subprocess.check_output([clang, '--version'], text=True, stderr=subprocess.STDOUT).strip()
    common_signature_values = (str(args.sdk.resolve()), str(args.toolchain.resolve()), str(args.cc.resolve()), compiler_identity, ar, ranlib, ld, tuple(target_flags))

    closure_obj = objects / 'BlocksRuntime.o'
    arclite = products / 'libarclite_iphoneos.a'
    arclite_stamp = objects / '.onegram-armv6-arclite.signature'
    arclite_sources = (compat / 'OnegramBlocksRuntimeClasses.m', compat / 'OnegramARCRuntime.m', compat / 'OnegramIOS3Compatibility.m')
    arclite_compile_flags = ['-DONEGRAM_LINKER_BLOCK_ALIASES=1']
    if os.environ.get('ONEGRAM_DIAGNOSTICS') == '1':
        arclite_compile_flags.append('-DONEGRAM_DIAGNOSTICS=1')
    arclite_signature = build_signature(
        'arclite',
        values=common_signature_values + (tuple(arclite_compile_flags),),
        paths=(closure / 'runtime.c', closure / 'Block.h', closure / 'Block_private.h', compat / 'OnegramIOS3Compatibility.h') + arclite_sources
    )
    if not cache_valid(arclite_stamp, arclite_signature, (arclite,)):
        arc_objects = [closure_obj] + [objects / (source.stem + '.o') for source in arclite_sources]
        arc_commands = [[cc_wrapper, '-fblocks', '-Os', '-I' + str(closure), '-c', closure / 'runtime.c', '-o', closure_obj]]
        arc_commands.extend([cc_wrapper, '-fno-objc-arc', '-fblocks', '-std=gnu99', '-Os'] + arclite_compile_flags + ['-I' + str(closure), '-I' + str(compat), '-c', source, '-o', output] for source, output in zip(arclite_sources, arc_objects[1:]))
        run_parallel(arc_commands, args.jobs)
        static_archive(arclite, arc_objects, libtool, ar, ranlib)
        verify_archive(arclite, lipo)
        cache_store(arclite_stamp, arclite_signature)
    else:
        verify_archive(arclite, lipo)
        print('ARMv6 dependency cache hit: libarclite_iphoneos.a')

    compiler_obj = objects / 'OnegramCompilerRuntime.o'
    compiler_rt = products / 'libclang_rt.ios.a'
    compiler_stamp = objects / '.onegram-armv6-compiler-runtime.signature'
    compiler_signature = build_signature(
        'compiler-runtime',
        values=common_signature_values,
        paths=(compat / 'OnegramCompilerRuntime.c',)
    )
    if not cache_valid(compiler_stamp, compiler_signature, (compiler_rt,)):
        run([cc_wrapper, '-Os', '-c', compat / 'OnegramCompilerRuntime.c', '-o', compiler_obj])
        static_archive(compiler_rt, [compiler_obj], libtool, ar, ranlib)
        verify_archive(compiler_rt, lipo)
        cache_store(compiler_stamp, compiler_signature)
    else:
        verify_archive(compiler_rt, lipo)
        print('ARMv6 dependency cache hit: libclang_rt.ios.a')

    resource_source = clang_resource_dir(clang)
    resource_dir = wrappers / 'armv6-clang-resource'
    resource_include = resource_dir / 'include'
    resource_lib = resource_dir / 'lib/darwin'
    if resource_include.exists() or resource_include.is_symlink():
        if resource_include.is_dir() and not resource_include.is_symlink():
            shutil.rmtree(resource_include)
        else:
            resource_include.unlink()
    resource_dir.mkdir(parents=True, exist_ok=True)
    resource_include.symlink_to(resource_source / 'include')
    resource_lib.mkdir(parents=True, exist_ok=True)
    shutil.copy2(compiler_rt, resource_lib / 'libclang_rt.ios.a')
    crt_source = args.sdk / 'usr/lib/crt1.3.1.o'
    if not crt_source.is_file():
        raise SystemExit('Missing iOS 3.1 CRT: ' + str(crt_source))
    crt_armv6 = products / 'crt1.3.1-armv6.o'
    crt_stamp = objects / '.onegram-armv6-crt.signature'
    crt_signature = build_signature('crt1.3.1', values=common_signature_values, paths=(crt_source,))
    if not cache_valid(crt_stamp, crt_signature, (crt_armv6,)):
        extract_armv6_slice(crt_source, crt_armv6, lipo)
        cache_store(crt_stamp, crt_signature)
    else:
        run([lipo, crt_armv6, '-verify_arch', 'armv6'])
    icu_source = args.sdk / 'usr/lib/libicucore.dylib'
    if not icu_source.is_file():
        raise SystemExit('Missing iOS 3.1 ICU runtime: ' + str(icu_source))
    icu_armv6 = products / 'libicucore.dylib'
    icu_stamp = objects / '.onegram-armv6-icu.signature'
    icu_signature = build_signature('libicucore', values=common_signature_values, paths=(icu_source,))
    if not cache_valid(icu_stamp, icu_signature, (icu_armv6,)):
        extract_armv6_slice(icu_source, icu_armv6, lipo)
        cache_store(icu_stamp, icu_signature)
    else:
        run([lipo, icu_armv6, '-verify_arch', 'armv6'])
    configure_cc_wrapper = wrappers / 'armv6-configure-cc'
    configure_cxx_wrapper = wrappers / 'armv6-configure-cxx'
    write_link_wrapper(configure_cc_wrapper, cc_driver, cc_prefix + target_flags + ['-resource-dir', str(resource_dir)], crt_armv6)
    write_link_wrapper(configure_cxx_wrapper, cxx_driver, cxx_prefix + target_flags + ['-resource-dir', str(resource_dir)], crt_armv6)

    dispatch = sources / 'libdispatch-libdispatch-187.10'
    xnu = sources / 'xnu-xnu-1504.15.3'
    dispatch_build = objects / 'libdispatch'
    dispatch_build.mkdir(parents=True, exist_ok=True)
    dispatch_src = dispatch_build / 'src'
    dispatch_archive = products / 'libdispatch.a'
    dispatch_stamp = objects / '.onegram-armv6-libdispatch.signature'
    dispatch_recipe = source_fragment(
        "\n    dispatch = sources / 'libdispatch-libdispatch-187.10'\n",
        "\n    def configure_static("
    )
    dispatch_signature = build_signature(
        'libdispatch',
        values=common_signature_values + ((str(mig) if mig is not None else 'pregenerated-mig'), dispatch_recipe),
        paths=(
            dispatch / 'src',
            dispatch / 'private',
            dispatch / 'config/config.h',
            xnu / 'osfmk/mach',
            compat / 'mig',
            compat / 'libdispatch-mig',
            compat / 'libdispatch',
            compat / 'include',
            closure / 'Block.h',
            closure / 'Block_private.h'
        )
    )
    if not cache_valid(dispatch_stamp, dispatch_signature, (dispatch_archive,)):
        if dispatch_src.exists():
            shutil.rmtree(dispatch_src)
        shutil.copytree(dispatch / 'src', dispatch_src)
        config = dispatch / 'config/config.h'
        config_text = config.read_text()
        config_text = config_text.replace('#define HAVE_PTHREAD_MACHDEP_H 1', '#undef HAVE_PTHREAD_MACHDEP_H')
        config_text = config_text.replace('#define HAVE_PTHREAD_WORKQUEUES 1', '#undef HAVE_PTHREAD_WORKQUEUES')
        config_text = config_text.replace('#define USE_APPLE_TSD_OPTIMIZATIONS 1', '#undef USE_APPLE_TSD_OPTIMIZATIONS')
        constructor_disabled = '/* #undef USE_LIBDISPATCH_INIT_CONSTRUCTOR */'
        constructor_enabled = '#define USE_LIBDISPATCH_INIT_CONSTRUCTOR 1'
        if constructor_enabled not in config_text:
            if constructor_disabled not in config_text:
                raise SystemExit('libdispatch constructor config changed unexpectedly')
            config_text = config_text.replace(
                constructor_disabled, constructor_enabled, 1)
        config_out = dispatch_build / 'config'
        config_out.mkdir(exist_ok=True)
        (config_out / 'config.h').write_text(config_text)
        if mig is not None:
            mig_include = compat / 'mig'
            run([mig, '-arch', 'armv6', '-I' + str(mig_include), '-I' + str(xnu / 'osfmk'), '-I' + str(xnu / 'bsd'), '-user', 'protocolUser.c', '-header', 'protocol.h', '-server', 'protocolServer.c', '-sheader', 'protocolServer.h', 'protocol.defs'], cwd=dispatch_src)
        else:
            protocol_defs = dispatch_src / 'protocol.defs'
            expected_protocol_defs = '395b0fe709a1e83490b7c24cd0010981d0c65f47acc242af6731033694d9899a'
            actual_protocol_defs = hashlib.sha256(protocol_defs.read_bytes()).hexdigest()
            if actual_protocol_defs != expected_protocol_defs:
                raise SystemExit('libdispatch protocol.defs checksum mismatch: ' + actual_protocol_defs)
            pregenerated_mig = compat / 'libdispatch-mig'
            for name in ('protocolUser.c', 'protocol.h', 'protocolServer.c', 'protocolServer.h'):
                source = pregenerated_mig / name
                if not source.is_file():
                    raise SystemExit('Missing pregenerated MIG source: ' + str(source))
                shutil.copy2(source, dispatch_src / name)
        queue = dispatch_src / 'queue.c'
        queue_text = queue.read_text()
        if '.fflags = NOTE_TRIGGER,' in queue_text:
            queue.write_text(queue_text.replace('.fflags = NOTE_TRIGGER,', '.flags = EV_TRIGGER,'))
        # ONEGRAM_IOS3_LIBDISPATCH_SEMAPHORE_FALLBACK
        queue_text = queue.read_text()
        pool_pattern = (r'kr\s*=\s*semaphore_create\(mach_task_self\(\),\s*'
            r'&_dispatch_thread_mediator\[i\]\.dsema_port,\s*'
            r'SYNC_POLICY_LIFO\s*,\s*0\s*\);')
        pool_replacement = '''kr = semaphore_create(mach_task_self(),
                &_dispatch_thread_mediator[i].dsema_port, SYNC_POLICY_LIFO, 0);
        if (kr != KERN_SUCCESS) {
            kr = semaphore_create(mach_task_self(),
                    &_dispatch_thread_mediator[i].dsema_port, SYNC_POLICY_FIFO, 0);
        }'''
        if 'SYNC_POLICY_FIFO, 0);' not in queue_text:
            queue_text, pool_replacements = __import__('re').subn(
                pool_pattern, pool_replacement, queue_text, count=1)
            if pool_replacements != 1:
                raise SystemExit('libdispatch thread-pool semaphore code changed unexpectedly')

        worker_guard = """
	if (_dispatch_thread_getspecific(dispatch_queue_key)) {
		DISPATCH_CRASH("Premature thread recycling");
	}

	_dispatch_thread_setspecific(dispatch_queue_key, dq);
"""
        worker_compat = """
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && (__IPHONE_OS_VERSION_MIN_REQUIRED < 40000)
	_dispatch_thread_setspecific(dispatch_queue_key, dq);
#else
	if (_dispatch_thread_getspecific(dispatch_queue_key)) {
		DISPATCH_CRASH("Premature thread recycling");
	}

	_dispatch_thread_setspecific(dispatch_queue_key, dq);
#endif
"""
        if worker_compat not in queue_text:
            if worker_guard not in queue_text:
                raise SystemExit('libdispatch worker TLS guard changed unexpectedly')
            queue_text = queue_text.replace(worker_guard, worker_compat, 1)

        worker_loop_clear = """
		#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && (__IPHONE_OS_VERSION_MIN_REQUIRED < 40000)
		if (_dispatch_thread_getspecific(dispatch_queue_key)) {
			_dispatch_thread_setspecific(dispatch_queue_key, NULL);
		}
		#endif
"""
        queue_text = queue_text.replace(worker_loop_clear, '', 1)

        sync_redirect_original = '''	if (!DISPATCH_OBJ_IS_VTABLE(dc) &&
			(long)dc->do_vtable & DISPATCH_OBJ_SYNC_SLOW_BIT) {
		dispatch_atomic_barrier();
		_dispatch_thread_semaphore_signal(
				(_dispatch_thread_semaphore_t)dc->dc_ctxt);
	} else {
'''
        sync_redirect_heap = '''	if (!DISPATCH_OBJ_IS_VTABLE(dc) &&
			(long)dc->do_vtable & DISPATCH_OBJ_SYNC_SLOW_BIT) {
		_dispatch_thread_semaphore_t sema =
				(_dispatch_thread_semaphore_t)dc->dc_ctxt;
		if ((long)dc->do_vtable == DISPATCH_OBJ_SYNC_SLOW_BIT) {
			_dispatch_continuation_free(dc);
		}
		dispatch_atomic_barrier();
		_dispatch_thread_semaphore_signal(sema);
	} else {
'''
        if sync_redirect_heap not in queue_text:
            if sync_redirect_original not in queue_text:
                raise SystemExit('libdispatch sync redirect code changed unexpectedly')
            queue_text = queue_text.replace(sync_redirect_original, sync_redirect_heap, 1)

        sync_slow_original = '''	_dispatch_thread_semaphore_t sema = _dispatch_get_thread_semaphore();
	struct dispatch_sync_slow_s {
		DISPATCH_CONTINUATION_HEADER(dispatch_sync_slow_s);
	} dss = {
		.do_vtable = (void*)DISPATCH_OBJ_SYNC_SLOW_BIT,
		.dc_ctxt = (void*)sema,
	};
	_dispatch_queue_push(dq, (void *)&dss);

	_dispatch_thread_semaphore_wait(sema);
'''
        sync_slow_heap = '''	_dispatch_thread_semaphore_t sema = _dispatch_get_thread_semaphore();
	dispatch_continuation_t dss = _dispatch_continuation_alloc_from_heap();
	dss->do_vtable = (void *)DISPATCH_OBJ_SYNC_SLOW_BIT;
	dss->dc_func = NULL;
	dss->dc_ctxt = (void *)sema;
	_dispatch_queue_push(dq, dss);

	_dispatch_thread_semaphore_wait(sema);
'''
        if sync_slow_heap not in queue_text:
            if sync_slow_original not in queue_text:
                raise SystemExit('libdispatch sync slow code changed unexpectedly')
            queue_text = queue_text.replace(sync_slow_original, sync_slow_heap, 1)

        barrier_sync_original = '''	struct dispatch_barrier_sync_slow_s dbss = {
		.do_vtable = (void *)(DISPATCH_OBJ_BARRIER_BIT |
				DISPATCH_OBJ_SYNC_SLOW_BIT),
		.dc_func = _dispatch_barrier_sync_f_slow_invoke,
		.dc_ctxt = &dbss2,
	};
	_dispatch_queue_push(dq, (void *)&dbss);
'''
        barrier_sync_heap = '''	struct dispatch_barrier_sync_slow_s *dbss =
			(void *)_dispatch_continuation_alloc_from_heap();
	dbss->do_vtable = (void *)(DISPATCH_OBJ_ASYNC_BIT |
			DISPATCH_OBJ_BARRIER_BIT | DISPATCH_OBJ_SYNC_SLOW_BIT);
	dbss->dc_func = _dispatch_barrier_sync_f_slow_invoke;
	dbss->dc_ctxt = &dbss2;
	_dispatch_queue_push(dq, (void *)dbss);
'''
        if barrier_sync_heap not in queue_text:
            if barrier_sync_original not in queue_text:
                raise SystemExit('libdispatch barrier sync code changed unexpectedly')
            queue_text = queue_text.replace(barrier_sync_original, barrier_sync_heap, 1)

        barrier_drain_original = '''	struct dispatch_barrier_sync_slow_s *dbssp = (void *)dc;
	struct dispatch_barrier_sync_slow2_s *dbss2p = dbssp->dc_ctxt;
	return dbss2p->dbss2_sema;
'''
        barrier_drain_heap = '''	struct dispatch_barrier_sync_slow_s *dbssp = (void *)dc;
	struct dispatch_barrier_sync_slow2_s *dbss2p = dbssp->dc_ctxt;
	_dispatch_thread_semaphore_t sema = dbss2p->dbss2_sema;
	if ((long)dc->do_vtable & DISPATCH_OBJ_ASYNC_BIT) {
		_dispatch_continuation_free((void *)dc);
	}
	return sema;
'''
        if barrier_drain_heap not in queue_text:
            if barrier_drain_original not in queue_text:
                raise SystemExit('libdispatch barrier drain code changed unexpectedly')
            queue_text = queue_text.replace(
                barrier_drain_original, barrier_drain_heap, 1)

        allocator_private = '''static dispatch_continuation_t
_dispatch_continuation_alloc_from_heap(void)
'''
        allocator_shared = '''dispatch_continuation_t
_dispatch_continuation_alloc_from_heap(void)
'''
        if allocator_private in queue_text:
            queue_text = queue_text.replace(allocator_private, allocator_shared, 1)
        elif allocator_shared not in queue_text:
            raise SystemExit('libdispatch continuation allocator changed unexpectedly')

        continuation_cache_original = '''DISPATCH_ALWAYS_INLINE
static inline dispatch_continuation_t
_dispatch_continuation_alloc_cacheonly(void)
{
	dispatch_continuation_t dc;
	dc = fastpath(_dispatch_thread_getspecific(dispatch_cache_key));
	if (dc) {
		_dispatch_thread_setspecific(dispatch_cache_key, dc->do_next);
	}
	return dc;
}
'''
        continuation_cache_disabled = '''DISPATCH_ALWAYS_INLINE
static inline dispatch_continuation_t
_dispatch_continuation_alloc_cacheonly(void)
{
	return NULL;
}
'''
        if continuation_cache_disabled not in queue_text:
            if continuation_cache_original not in queue_text:
                raise SystemExit('libdispatch continuation cache allocator changed unexpectedly')
            queue_text = queue_text.replace(
                continuation_cache_original, continuation_cache_disabled, 1)

        continuation_free_original = '''DISPATCH_ALWAYS_INLINE
static inline void
_dispatch_continuation_free(dispatch_continuation_t dc)
{
	dispatch_continuation_t prev_dc;
	prev_dc = _dispatch_thread_getspecific(dispatch_cache_key);
	dc->do_next = prev_dc;
	_dispatch_thread_setspecific(dispatch_cache_key, dc);
}
'''
        continuation_free_heap = '''DISPATCH_ALWAYS_INLINE
static inline void
_dispatch_continuation_free(dispatch_continuation_t dc)
{
	malloc_zone_free(_dispatch_ccache_zone, dc);
}
'''
        if continuation_free_heap not in queue_text:
            if continuation_free_original not in queue_text:
                raise SystemExit('libdispatch continuation free code changed unexpectedly')
            queue_text = queue_text.replace(
                continuation_free_original, continuation_free_heap, 1)

        continuation_original = """
	dispatch_continuation_t dc = dou._dc;
	dispatch_group_t dg;

	_dispatch_trace_continuation_pop(_dispatch_queue_get_current(), dou);
	if (DISPATCH_OBJ_IS_VTABLE(dou._do)) {
		return _dispatch_queue_invoke(dou._dq);
	}

	// Add the item back to the cache before calling the function. This
	// allows the 'hot' continuation to be used for a quick callback.
	//
	// The ccache version is per-thread.
	// Therefore, the object has not been reused yet.
	// This generates better assembly.
	if ((long)dc->do_vtable & DISPATCH_OBJ_ASYNC_BIT) {
		_dispatch_continuation_free(dc);
	}
	if ((long)dc->do_vtable & DISPATCH_OBJ_GROUP_BIT) {
		dg = dc->dc_group;
	} else {
		dg = NULL;
	}
	_dispatch_client_callout(dc->dc_ctxt, dc->dc_func);
"""
        continuation_safe = """
	dispatch_continuation_t dc = dou._dc;
	dispatch_group_t dg;
	void *ctxt;
	dispatch_function_t func;
	long dc_flags;

	if (!DISPATCH_OBJ_IS_VTABLE(dou._do) &&
			(long)dc->do_vtable == DISPATCH_OBJ_SYNC_SLOW_BIT) {
		return _dispatch_continuation_redirect(
				_dispatch_queue_get_current(), dou);
	}
	_dispatch_trace_continuation_pop(_dispatch_queue_get_current(), dou);
	if (DISPATCH_OBJ_IS_VTABLE(dou._do)) {
		return _dispatch_queue_invoke(dou._dq);
	}

	dc_flags = (long)dc->do_vtable;
	ctxt = dc->dc_ctxt;
	func = dc->dc_func;
	if (dc_flags & DISPATCH_OBJ_GROUP_BIT) {
		dg = dc->dc_group;
	} else {
		dg = NULL;
	}

	_dispatch_client_callout(ctxt, func);
	if (dc_flags & DISPATCH_OBJ_ASYNC_BIT) {
		_dispatch_continuation_free(dc);
	}
"""
        continuation_previous = """
	dispatch_continuation_t dc = dou._dc;
	dispatch_group_t dg;
	void *ctxt;
	dispatch_function_t func;
	long dc_flags;

	_dispatch_trace_continuation_pop(_dispatch_queue_get_current(), dou);
	if (DISPATCH_OBJ_IS_VTABLE(dou._do)) {
		return _dispatch_queue_invoke(dou._dq);
	}

	dc_flags = (long)dc->do_vtable;
	ctxt = dc->dc_ctxt;
	func = dc->dc_func;
	if (dc_flags & DISPATCH_OBJ_GROUP_BIT) {
		dg = dc->dc_group;
	} else {
		dg = NULL;
	}

	if (dc_flags & DISPATCH_OBJ_ASYNC_BIT) {
		_dispatch_continuation_free(dc);
	}
	_dispatch_client_callout(ctxt, func);
"""
        if continuation_safe not in queue_text:
            if continuation_previous in queue_text:
                queue_text = queue_text.replace(continuation_previous, continuation_safe, 1)
            elif continuation_original in queue_text:
                queue_text = queue_text.replace(continuation_original, continuation_safe, 1)
            else:
                raise SystemExit('libdispatch continuation pop code changed unexpectedly')

        worker_priority_original = """
	r = _dispatch_pthread_sigmask(SIG_BLOCK, &mask, NULL);
	(void)dispatch_assume_zero(r);

	do {
		_dispatch_worker_thread2(context);
"""
        worker_priority_applied = """
	r = _dispatch_pthread_sigmask(SIG_BLOCK, &mask, NULL);
	(void)dispatch_assume_zero(r);

	_dispatch_worker_thread_apply_priority(dq);

	do {
		_dispatch_worker_thread2(context);
"""
        worker_priority_function = """
static void
_dispatch_worker_thread_apply_priority(dispatch_queue_t dq)
{
	thread_precedence_policy_data_t policy;
	switch (dq - _dispatch_root_queues) {
	case DISPATCH_ROOT_QUEUE_IDX_HIGH_PRIORITY:
	case DISPATCH_ROOT_QUEUE_IDX_HIGH_OVERCOMMIT_PRIORITY:
		policy.importance = 4;
		break;
	default:
		return;
	}
	(void)dispatch_assume_zero(thread_policy_set(
			pthread_mach_thread_np(pthread_self()), THREAD_PRECEDENCE_POLICY,
			(thread_policy_t)&policy, THREAD_PRECEDENCE_POLICY_COUNT));
}

// 6618342 Contact the team that owns the Instrument DTrace probe before
//         renaming this symbol
static void *
_dispatch_worker_thread(void *context)
"""
        worker_thread_declaration = """
// 6618342 Contact the team that owns the Instrument DTrace probe before
//         renaming this symbol
static void *
_dispatch_worker_thread(void *context)
"""
        if worker_priority_applied not in queue_text:
            if worker_priority_original not in queue_text or queue_text.count(worker_thread_declaration) != 1:
                raise SystemExit('libdispatch worker thread code changed unexpectedly')
            queue_text = queue_text.replace(worker_priority_original, worker_priority_applied, 1)
            queue_text = queue_text.replace(worker_thread_declaration, worker_priority_function, 1)
            if '#include <mach/thread_policy.h>' not in queue_text:
                queue_text = '#include <mach/thread_policy.h>\n' + queue_text

        queue.write_text(queue_text)

        dispatch_init = dispatch_src / 'init.c'
        dispatch_init_text = dispatch_init.read_text()
        cocoa_pool_original = '''void *(*_dispatch_begin_NSAutoReleasePool)(void) = (void *)dummy_function;
void (*_dispatch_end_NSAutoReleasePool)(void *) = (void *)dummy_function;
'''
        cocoa_pool_enabled = '''extern void *objc_autoreleasePoolPush(void);
extern void objc_autoreleasePoolPop(void *pool);

void *(*_dispatch_begin_NSAutoReleasePool)(void) = objc_autoreleasePoolPush;
void (*_dispatch_end_NSAutoReleasePool)(void *) = objc_autoreleasePoolPop;
'''
        if cocoa_pool_enabled not in dispatch_init_text:
            if cocoa_pool_original not in dispatch_init_text:
                raise SystemExit('libdispatch autorelease pool hooks changed unexpectedly')
            dispatch_init_text = dispatch_init_text.replace(
                cocoa_pool_original, cocoa_pool_enabled, 1)
        dispatch_init.write_text(dispatch_init_text)

        queue_internal = dispatch_src / 'queue_internal.h'
        queue_internal_text = queue_internal.read_text()
        allocator_declaration_anchor = '''typedef struct dispatch_continuation_s *dispatch_continuation_t;
'''
        allocator_declaration = '''typedef struct dispatch_continuation_s *dispatch_continuation_t;

dispatch_continuation_t
_dispatch_continuation_alloc_from_heap(void);
'''
        if allocator_declaration not in queue_internal_text:
            if allocator_declaration_anchor not in queue_internal_text:
                raise SystemExit('libdispatch continuation declaration changed unexpectedly')
            queue_internal_text = queue_internal_text.replace(
                allocator_declaration_anchor, allocator_declaration, 1)
        queue_internal.write_text(queue_internal_text)

        apply = dispatch_src / 'apply.c'
        apply_text = apply.read_text()
        apply_continuations_stack = '''\tstruct dispatch_apply_dc_s {
\t\tDISPATCH_CONTINUATION_HEADER(dispatch_apply_dc_s);
\t} da_dc[DISPATCH_APPLY_MAX_CPUS];
\tsize_t i;

\tfor (i = 0; i < da->da_thr_cnt - 1; i++) {
\t\tda_dc[i].do_vtable = NULL;
\t\tda_dc[i].do_next = &da_dc[i + 1];
\t\tda_dc[i].dc_func = func;
\t\tda_dc[i].dc_ctxt = da;
\t}

\tda->da_sema = _dispatch_get_thread_semaphore();

\t_dispatch_queue_push_list(dq, (void *)&da_dc[0],
\t\t\t(void *)&da_dc[da->da_thr_cnt - 2]);
'''
        apply_continuations_heap = '''\tdispatch_continuation_t da_dc[DISPATCH_APPLY_MAX_CPUS];
\tsize_t i;

\tfor (i = 0; i < da->da_thr_cnt - 1; i++) {
\t\tda_dc[i] = _dispatch_continuation_alloc_from_heap();
\t}
\tfor (i = 0; i < da->da_thr_cnt - 1; i++) {
\t\tda_dc[i]->do_vtable = (void *)DISPATCH_OBJ_ASYNC_BIT;
\t\tda_dc[i]->do_next = i + 1 < da->da_thr_cnt - 1 ?
\t\t\tda_dc[i + 1] : NULL;
\t\tda_dc[i]->dc_func = func;
\t\tda_dc[i]->dc_ctxt = da;
\t}

\tda->da_sema = _dispatch_get_thread_semaphore();

\t_dispatch_queue_push_list(dq, da_dc[0],
\t\t\tda_dc[da->da_thr_cnt - 2]);
'''
        if apply_continuations_heap not in apply_text:
            if apply_continuations_stack not in apply_text:
                raise SystemExit('libdispatch apply continuation code changed unexpectedly')
            apply_text = apply_text.replace(
                apply_continuations_stack, apply_continuations_heap, 1)
        apply.write_text(apply_text)

        dispatch_objects = []
        dispatch_commands = []
        dispatch_sources = ['apply.c', 'benchmark.c', 'data.c', 'init.c', 'io.c', 'object.c', 'once.c', 'queue.c', 'semaphore.c', 'source.c', 'time.c', 'protocolServer.c', 'protocolUser.c']
        dispatch_flags = ['-fblocks', '-Os', '-fno-objc-arc', '-DDISPATCH_COCOA_COMPAT=1', '-I' + str(compat / 'libdispatch'), '-I' + str(compat / 'include'), '-I' + str(closure), '-I' + str(dispatch_src), '-I' + str(dispatch / 'private'), '-I' + str(dispatch_build), '-I' + str(dispatch_build / 'config'), '-I' + str(dispatch), '-D__DARWIN_NON_CANCELABLE=1', '-D__DARWIN_UNIX03=1']
        for name in dispatch_sources:
            source = dispatch_src / name
            if not source.is_file():
                raise SystemExit('Missing libdispatch source: ' + str(source))
            output = dispatch_build / (Path(name).stem + '.o')
            dispatch_commands.append([cc_wrapper] + dispatch_flags + ['-c', source, '-o', output])
            dispatch_objects.append(output)
        run_parallel(dispatch_commands, args.jobs)
        static_archive(dispatch_archive, dispatch_objects, libtool, ar, ranlib)
        verify_archive(dispatch_archive, lipo)
        cache_store(dispatch_stamp, dispatch_signature)
    else:
        verify_archive(dispatch_archive, lipo)
        print('ARMv6 dependency cache hit: libdispatch.a')

    def configure_static(source, archive, label, arguments, output_name, candidates):
        signature = build_signature(
            label,
            values=common_signature_values + (tuple(arguments), inspect.getsource(configure_static)),
            paths=(archive,)
        )
        stamp = objects / ('.onegram-armv6-' + label + '.signature')
        result = first_existing(source, candidates)
        if not stamp.is_file() or stamp.read_text().strip() != signature or result is None:
            if source.is_dir():
                shutil.rmtree(source)
            unpack(archive, sources, source)
            env = make_env.copy()
            env.update(CC=str(configure_cc_wrapper), CXX=str(configure_cxx_wrapper), AR=ar, RANLIB=ranlib, CFLAGS='-Os', CXXFLAGS='-Os', LDFLAGS='')
            try:
                build_system = 'apple-darwin' if sys.platform == 'darwin' else 'unknown-linux-gnu'
                run([source / 'configure', '--host=arm-apple-darwin', '--build=' + platform.machine() + '-' + build_system, '--disable-shared', '--enable-static'] + arguments, cwd=source, env=env)
            except subprocess.CalledProcessError:
                config_log = source / 'config.log'
                if config_log.is_file():
                    sys.stderr.write(config_log.read_text(errors='replace')[-16000:])
                raise
            run(['make', '-j' + str(args.jobs)], cwd=source, env=env)
            result = first_existing(source, candidates)
            if result is None:
                raise SystemExit('Build did not produce ' + output_name)
            cache_store(stamp, signature)
        destination = products / output_name
        install_archive(result, destination, ranlib)
        verify_archive(destination, lipo)

    configure_static(sources / 'opus-1.0.3', sources / 'opus-1.0.3.tar.gz', 'opus', [], 'libopus.a', ['.libs/libopus.a', 'libopus.a'])
    configure_static(sources / 'libwebp-0.4.3', sources / 'libwebp-0.4.3.tar.gz', 'webp', ['--disable-sse2', '--disable-sse4.1'], 'libWebP.a', ['src/.libs/libwebp.a', 'src/libwebp.a'])

    openssl = sources / 'openssl-OpenSSL_1_0_2h'
    openssl_archive = sources / 'openssl-1.0.2h.tar.gz'
    openssl_recipe = source_fragment(
        "\n    openssl = sources / 'openssl-OpenSSL_1_0_2h'\n",
        "\n    pst = ROOT / 'thirdparty/PSTCollectionView/PSTCollectionView'\n"
    )
    openssl_signature = build_signature('openssl', values=common_signature_values + (openssl_recipe,), paths=(openssl_archive,))
    openssl_stamp = objects / '.onegram-armv6-openssl.signature'
    openssl_outputs = (openssl / 'libssl.a', openssl / 'libcrypto.a')
    if not cache_valid(openssl_stamp, openssl_signature, openssl_outputs):
        if openssl.is_dir():
            shutil.rmtree(openssl)
        unpack(openssl_archive, sources, openssl)
        configure = openssl / 'Configure'
        original = configure.read_text(encoding='latin-1')
        original = original.replace('rename($Makefile,"$Makefile.bak")', 'unlink($Makefile)')
        original = original.replace('rename("crypto/opensslconf.h","crypto/opensslconf.h.bak")', 'unlink("crypto/opensslconf.h")')
        original = original.replace('rename($f,"$f.bak")', 'unlink($f)')
        lines = original.splitlines()
        if not any(line.startswith('"ios-armv6-cross","') for line in lines):
            for index, line in enumerate(lines):
                if line.startswith('"iphoneos-cross","'):
                    lines.insert(index + 1, '"ios-armv6-cross","' + cc_wrapper.name + ':-Os -fno-common::-D_REENTRANT:iOS:-Wl,-search_paths_first%:BN_LLONG RC4_CHAR RC4_CHUNK DES_UNROLL BF_PTR:armcap.o armv4cpuid.o:bn_asm.o armv4-mont.o armv4-gf2m.o:::aes_cbc.o aes-armv4.o:::sha1-armv4-large.o sha256-armv4.o sha512-armv4.o:::::::ghash-armv4.o::ios32:dlfcn:darwin-shared:-fPIC -fno-common:-dynamiclib:.\\$(SHLIB_MAJOR).\\$(SHLIB_MINOR).dylib",')
                    break
            else:
                raise SystemExit('OpenSSL iphoneos-cross target not found')
        configure.write_text('\n'.join(lines) + '\n', encoding='latin-1')
        backport_openssl_ios_arm_perlasm(openssl)
        env = make_env.copy()
        env['PATH'] = str(wrappers) + os.pathsep + env.get('PATH', '')
        run(['perl', 'Configure', 'ios-armv6-cross', 'no-shared', 'no-dso', 'no-hw', 'no-engine'], cwd=openssl, env=env)
        run(['make', 'depend', 'AR=' + ar + ' r', 'RANLIB=' + ranlib], cwd=openssl, env=env)
        run(['make', '-j1', 'build_libs', 'AR=' + ar + ' r', 'RANLIB=' + ranlib], cwd=openssl, env=env)
        archive_members = subprocess.check_output([ar, 't', str(openssl / 'libcrypto.a')], text=True).splitlines()
        required_asm_members = {
            'armcap.o',
            'armv4cpuid.o',
            'armv4-mont.o',
            'armv4-gf2m.o',
            'aes-armv4.o',
            'sha1-armv4-large.o',
            'sha256-armv4.o',
            'sha512-armv4.o',
            'ghash-armv4.o'
        }
        missing_asm_members = sorted(required_asm_members.difference(archive_members))
        if missing_asm_members:
            raise SystemExit('OpenSSL ARM assembly objects missing from libcrypto.a: ' + ', '.join(missing_asm_members))
        cache_store(openssl_stamp, openssl_signature)
    for name in ('libssl.a', 'libcrypto.a'):
        source = openssl / name
        if not source.is_file():
            raise SystemExit('OpenSSL build did not produce ' + name)
        destination = products / name
        install_archive(source, destination, ranlib)
        verify_archive(destination, lipo)

    pst = ROOT / 'thirdparty/PSTCollectionView/PSTCollectionView'
    pst_out = objects / 'pst'
    pst_out.mkdir(parents=True, exist_ok=True)
    pst_archive = products / 'libPSTCollectionView.a'
    pst_stamp = objects / '.onegram-armv6-pst.signature'
    pst_recipe = source_fragment(
        "\n    pst = ROOT / 'thirdparty/PSTCollectionView/PSTCollectionView'\n",
        "\n    required = ['libarclite_iphoneos.a'"
    )
    pst_signature = build_signature(
        'pstcollectionview',
        values=common_signature_values + (pst_recipe,),
        paths=(pst, compat / 'OnegramIOS3Compatibility.h', compat / 'OnegramIOS3Compatibility.m', closure / 'Block.h')
    )
    if not cache_valid(pst_stamp, pst_signature, (pst_archive,)):
        pst_objects = []
        pst_commands = []
        for source in sorted(pst.glob('*.m')):
            output = pst_out / (source.stem + '.o')
            pst_commands.append([cc_wrapper, '-fobjc-arc', '-fblocks', '-std=gnu99', '-Os', '-DONEGRAM_ARMV6=1', '-I' + str(pst), '-I' + str(closure), '-include', compat / 'OnegramIOS3Compatibility.h', '-c', source, '-o', output])
            pst_objects.append(output)
        run_parallel(pst_commands, args.jobs)
        static_archive(pst_archive, pst_objects, libtool, ar, ranlib)
        verify_archive(pst_archive, lipo)
        cache_store(pst_stamp, pst_signature)
    else:
        verify_archive(pst_archive, lipo)
        print('ARMv6 dependency cache hit: libPSTCollectionView.a')

    required = ['libarclite_iphoneos.a', 'libclang_rt.ios.a', 'libdispatch.a', 'libopus.a', 'libWebP.a', 'libssl.a', 'libcrypto.a', 'libPSTCollectionView.a']
    for name in required:
        verify_archive(products / name, lipo)
    dispatch_symbols = subprocess.run([nm, '-u', dispatch_archive], check=True, capture_output=True, text=True).stdout
    (OUT / 'armv6-libdispatch-undefined.txt').write_text(dispatch_symbols)
    print('ARMv6 dependency products: ' + str(products))


if __name__ == '__main__':
    main()
