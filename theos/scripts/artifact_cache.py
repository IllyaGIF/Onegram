import hashlib
import json
from pathlib import Path
import stat


def fingerprint(paths, values=()):
    digest = hashlib.sha256(json.dumps(values, sort_keys=True).encode())
    def visit(path, relative, parents):
        digest.update(str(relative).encode())
        digest.update(b'\0')
        digest.update(str(stat.S_IMODE(path.stat().st_mode)).encode())
        if path.is_dir():
            resolved = path.resolve()
            if resolved in parents:
                raise ValueError('Cyclic artifact directory: ' + str(path))
            digest.update(b'd\0')
            for child in sorted(path.iterdir()):
                visit(child, relative / child.name, parents | {resolved})
        else:
            digest.update(b'f\0')
            content = hashlib.sha256()
            with path.open('rb') as source:
                for block in iter(lambda: source.read(1024 * 1024), b''):
                    content.update(block)
            digest.update(content.digest())
    for original in paths:
        path = Path(original)
        digest.update(str(path).encode())
        digest.update(b'\0')
        visit(path, Path('.'), set())
    return digest.hexdigest()


def cache_matches(stamp, signature, outputs):
    try:
        saved = json.loads(Path(stamp).read_text())
        return saved['signature'] == signature and saved['outputs'] == fingerprint(outputs)
    except (OSError, ValueError, KeyError):
        return False


def cache_record(stamp, signature, outputs):
    stamp = Path(stamp)
    stamp.parent.mkdir(parents=True, exist_ok=True)
    contents = json.dumps({'signature': signature, 'outputs': fingerprint(outputs)}, sort_keys=True)
    temporary = stamp.with_suffix(stamp.suffix + '.tmp')
    temporary.write_text(contents + '\n')
    temporary.replace(stamp)
