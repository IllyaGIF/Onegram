#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from xcode_graph import ROOT
from generate import OUT


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--cc", required=True)
    p.add_argument("--sdk", required=True)
    p.add_argument("--toolchain", required=True)
    p.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    args = p.parse_args()

    core = ROOT / "thirdparty/TgVoipWebrtcIOS6"
    script = (core / "build_core_ios6.sh").read_text()

    def assignment(name):
        match = re.search(r"^" + name + r'="(.*?)"', script, re.M | re.S)
        if not match:
            raise ValueError("Missing shell assignment: " + name)
        return match[1]

    arch = os.environ.get("ONEGRAM_ARCH", "armv7")
    minimum = "7.0" if arch == "arm64" else "4.3"

    substitutions = {
        "ROOT": str(core),
        "SRC": str(core / "src"),
        "ARCH": arch,
        "MIN_VERSION": "-miphoneos-version-min=" + minimum,
    }

    def expand_shell(text):
        return re.sub(
            r"\$(\w+)",
            lambda m: substitutions[m[1]],
            text,
        )

    flags = shlex.split(
        expand_shell(
            assignment("CXXFLAGS") + " " + assignment("INCLUDES")
        )
    )

    if arch == "arm64":
        flags = [
            f.replace(
                str(core / "openssl-ios5/include"),
                str(
                    OUT
                    / "dependency-sources"
                    / "openssl-OpenSSL_1_0_2h"
                    / "include"
                ),
            )
            for f in flags
        ]

    sources = [
        core / "src" / source
        for source in assignment("SOURCES").split()
    ]

    required = core / "src/tgcalls/v2/SignalingConnection.cpp"

    if required not in sources:
        sources.append(required)

    (OUT / "core-manifest.json").write_text(
        json.dumps(
            {
                "script": "thirdparty/TgVoipWebrtcIOS6/build_core_ios6.sh",
                "sources": [
                    str(source.relative_to(ROOT))
                    for source in sources
                ],
                "additional_required_source": str(
                    required.relative_to(ROOT)
                ),
                "reason": "ExternalSignalingConnection requires tgcalls::SignalingConnection::SignalingConnection()",
                "flags": flags,
            },
            indent=2,
        )
        + "\n"
    )

    output = OUT / "core"
    output.mkdir(parents=True, exist_ok=True)

    archive = OUT / "products/libTgVoipWebrtcIOS6Core.a"
    archive.parent.mkdir(parents=True, exist_ok=True)

    signature = hashlib.sha256()

    for path in sorted(
        p
        for p in core.rglob("*")
        if p.is_file() and p.suffix not in (".a", ".o")
    ):
        signature.update(str(path.relative_to(core)).encode())
        signature.update(path.read_bytes())

    signature.update(args.cc.encode())
    signature.update(args.sdk.encode())
    signature.update(args.toolchain.encode())
    signature.update(arch.encode())
    signature.update(Path(__file__).read_bytes())

    stamp = output / "signature"
    digest = signature.hexdigest()

    if (
        archive.exists()
        and stamp.exists()
        and stamp.read_text() == digest
    ):
        return

    compiler = shlex.split(args.cc)

    object_map = {}

    for source in sources:
        object_map[source] = output / (
            str(source.relative_to(core / "src"))
            .replace("/", "_")
            + ".o"
        )

    def compile_source(source):
        obj = object_map[source]

        command = (
            compiler
            + [
                "-target",
                arch + "-apple-ios" + minimum,
                "-isysroot",
                args.sdk,
            ]
            + flags
            + [
                "-c",
                str(source),
                "-o",
                str(obj),
            ]
        )

        subprocess.run(command, check=True)

    jobs = max(1, min(args.jobs, len(sources)))

    with ThreadPoolExecutor(max_workers=jobs) as executor:
        futures = {
            executor.submit(compile_source, source): source
            for source in sources
        }

        for future in as_completed(futures):
            future.result()

    objects = [
        str(object_map[source])
        for source in sources
    ]

    subprocess.run(
        [
            str(Path(args.toolchain) / "bin/libtool"),
            "-static",
            "-o",
            str(archive),
        ]
        + objects,
        check=True,
    )

    stamp.write_text(digest)


if __name__ == "__main__":
    main()
