from pathlib import Path
import re
import subprocess
from artifact_cache import cache_matches, cache_record, fingerprint


def build_pst(sources, compiler, libtool, lipo, architecture, archive, output, inputs):
    output.mkdir(parents=True, exist_ok=True)
    stamp = output / 'build-state.json'
    objects = [output / (source.stem + '.o') for source in sources]
    records = [obj.with_suffix('.d') for obj in objects]
    base_inputs = sources + list(inputs) + [Path(__file__), Path(compiler[0]), Path(libtool)]

    def signature():
        dependencies = set()
        for record in records:
            text = record.read_text().replace('\\\n', '')
            target, separator, body = text.partition(':')
            if not separator or target.strip() != 'onegram':
                raise ValueError('Invalid dependency record: ' + str(record))
            dependencies.update(Path(re.sub(r'\\(.)', r'\1', token).replace('$$', '$'))
                                for token in re.findall(r'(?:\\.|[^\s])+', body))
        return fingerprint(base_inputs + sorted(dependencies), values=compiler + [libtool, architecture])

    try:
        current = signature()
    except (OSError, ValueError):
        current = None
    if current is not None and cache_matches(stamp, current, [archive]):
        return
    for source, obj, record in zip(sources, objects, records):
        subprocess.run(compiler + ['-MD', '-MT', 'onegram', '-MF', str(record),
                                  '-c', str(source), '-o', str(obj)], check=True)
    subprocess.run([libtool, '-static', '-o', str(archive)] + [str(obj) for obj in objects], check=True)
    subprocess.run([lipo, str(archive), '-verify_arch', architecture], check=True)
    cache_record(stamp, signature(), [archive])
