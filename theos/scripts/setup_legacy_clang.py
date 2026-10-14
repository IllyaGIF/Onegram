#!/usr/bin/env python3
import hashlib
import os
import sys
import subprocess
import tarfile
import urllib.request
from xcode_graph import ROOT

URL='https://releases.llvm.org/3.2/clang%2Bllvm-3.2-x86_64-linux-ubuntu-12.04.tar.gz'
SHA256='5b5a23eef95d88eecf4e2009b9afd17675a5455735fd6e1315a75d7b6543b347'
DIRECTORY='clang+llvm-3.2-x86_64-linux-ubuntu-12.04'

def main():
    root=ROOT/'theos'/'generated'/'toolchains'
    compiler=root/DIRECTORY/'bin/clang++'
    c_compiler=root/DIRECTORY/'bin/clang'
    marker=root/DIRECTORY/'.archive.sha256'
    if compiler.is_file() and c_compiler.is_file() and marker.exists() and marker.read_text().strip()==SHA256:return
    if os.uname().sysname!='Linux' or os.uname().machine!='x86_64':
        raise SystemExit('Set CORE_CXX to a compatible legacy compiler on this host')
    root.mkdir(parents=True,exist_ok=True)
    archive=root/'clang32.tar.gz'
    if not archive.exists():
        print('Downloading pinned LLVM 3.2 from releases.llvm.org',flush=True)
        urllib.request.urlretrieve(URL,archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=SHA256:
        raise SystemExit('LLVM archive checksum mismatch: '+str(archive))
    with tarfile.open(archive) as tar:
        if sys.version_info >= (3, 12):
            tar.extractall(root, filter='data')
        else:
            tar.extractall(root)
    subprocess.run([str(compiler),'--version'],check=True)
    marker.write_text(SHA256+'\n')

if __name__=='__main__':main()
