import argparse
import fcntl
import hashlib
import io
from pathlib import Path, PurePosixPath
import tarfile
import urllib.request

REVISION = "08e1f3881ec140f79c2d1c14e482a32a782c5312"
SHA256 = "10183c0ae9737a338248fe6e205c2baae66d049ddb578a148e34e20660200d47"
URL = "https://codeload.github.com/pq-code-package/mlkem-native/tar.gz/" + REVISION


def prepare(output):
    output.parent.mkdir(parents=True, exist_ok=True)
    with (output.parent / ".mlkem-native.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        marker = output / ".revision"
        if marker.is_file() and marker.read_text() == REVISION and (output / "mlkem_native.c").is_file():
            return
        with urllib.request.urlopen(URL, timeout=60) as response:
            archive = response.read(4 * 1024 * 1024 + 1)
        if hashlib.sha256(archive).hexdigest() != SHA256:
            raise RuntimeError("mlkem-native archive integrity check failed")
        output.mkdir(parents=True, exist_ok=True)
        with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as source:
            for member in source:
                parts = PurePosixPath(member.name).parts
                if len(parts) < 3 or parts[1] != "mlkem" or not member.isfile():
                    continue
                relative = PurePosixPath(*parts[2:])
                if relative.is_absolute() or ".." in relative.parts:
                    raise RuntimeError("Invalid mlkem-native archive path")
                target = output.joinpath(*relative.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                with source.extractfile(member) as stream:
                    target.write_bytes(stream.read())
        if not (output / "mlkem_native.c").is_file() or not (output / "mlkem_native.h").is_file():
            raise RuntimeError("Incomplete mlkem-native source archive")
        marker.write_text(REVISION)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    prepare(parser.parse_args().output)
