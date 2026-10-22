import argparse
import hashlib
from pathlib import Path
import plistlib
import shlex
import struct
import subprocess
import zipfile


def macho_slices(data):
    formats = {b'\xca\xfe\xba\xbe': ('>', 'IIIII'), b'\xbe\xba\xfe\xca': ('<', 'IIIII'),
               b'\xca\xfe\xba\xbf': ('>', 'IIQQII'), b'\xbf\xba\xfe\xca': ('<', 'IIQQII')}
    if data[:4] not in formats:
        return [data]
    endian, layout = formats[data[:4]]
    count = struct.unpack_from(endian + 'I', data, 4)[0]
    entry_size = struct.calcsize(endian + layout)
    table_end = 8 + count * entry_size
    if not count or table_end > len(data):
        raise ValueError('Invalid Mach-O architecture table')
    result = []
    ranges = []
    for index in range(count):
        _, _, offset, size, *_ = struct.unpack_from(endian + layout, data, 8 + index * entry_size)
        if offset < table_end or size < 28 or offset + size > len(data):
            raise ValueError('Invalid Mach-O architecture bounds')
        result.append(data[offset:offset + size])
        ranges.append((offset, offset + size))
    ordered = sorted(ranges)
    if any(left[1] > right[0] for left, right in zip(ordered, ordered[1:])):
        raise ValueError('Overlapping Mach-O architectures')
    return result


def signature_blobs(data):
    headers = {b'\xce\xfa\xed\xfe': ('<', 28), b'\xcf\xfa\xed\xfe': ('<', 32),
               b'\xfe\xed\xfa\xce': ('>', 28), b'\xfe\xed\xfa\xcf': ('>', 32)}
    if data[:4] not in headers:
        raise ValueError('Unsupported Mach-O executable')
    endian, position = headers[data[:4]]
    count, size = struct.unpack_from(endian + 'II', data, 16)
    limit = position + size
    if limit > len(data):
        raise ValueError('Truncated Mach-O load commands')
    signature = None
    code_limit = None
    for _ in range(count):
        if position + 8 > limit:
            raise ValueError('Truncated Mach-O load command')
        command, size = struct.unpack_from(endian + 'II', data, position)
        if size < 8 or position + size > limit:
            raise ValueError('Invalid Mach-O load command size')
        if command == 0x1d:
            if size != 16 or signature is not None:
                raise ValueError('Invalid LC_CODE_SIGNATURE')
            offset, length = struct.unpack_from(endian + 'II', data, position + 8)
            if offset < limit or length < 12 or offset + length > len(data):
                raise ValueError('Invalid Mach-O signature bounds')
            code_limit = offset
            signature = data[offset:offset + length]
        position += size
    if signature is None:
        raise ValueError('Missing LC_CODE_SIGNATURE')
    magic, length, count = struct.unpack_from('>III', signature)
    table_end = 12 + count * 8
    if magic != 0xfade0cc0 or not table_end <= length <= len(signature):
        raise ValueError('Invalid embedded signature')
    blobs = {}
    for index in range(count):
        slot, offset = struct.unpack_from('>II', signature, 12 + index * 8)
        if slot in blobs or not table_end <= offset <= length - 8:
            raise ValueError('Invalid signature slot')
        size = struct.unpack_from('>I', signature, offset + 4)[0]
        if size < 8 or offset + size > length:
            raise ValueError('Truncated signature blob')
        blobs[slot] = signature[offset:offset + size]
    return blobs, code_limit


def verify_slice(data, info_data, resource_data, expected_entitlements):
    info = plistlib.loads(info_data)
    blobs, code_limit = signature_blobs(data)
    if 5 not in blobs or struct.unpack_from('>I', blobs[5])[0] != 0xfade7171:
        raise ValueError('Missing XML signing entitlements')
    entitlements = plistlib.loads(blobs[5][8:])
    if entitlements.get('application-identifier') != info['CFBundleIdentifier']:
        raise ValueError('Signing entitlements do not match the bundle identifier')
    if expected_entitlements is not None and entitlements != expected_entitlements:
        raise ValueError('Signing entitlements differ from the requested entitlements')
    algorithms = set()
    for slot, directory in blobs.items():
        if slot != 0 and not 0x1000 <= slot < 0x1005:
            continue
        if len(directory) < 44:
            raise ValueError('Truncated CodeDirectory')
        magic, length, _, _, hashes, identifier, special, pages, covered = struct.unpack_from('>9I', directory)
        hash_size, hash_type, _, page_shift = struct.unpack_from('4B', directory, 36)
        algorithm = {1: 'sha1', 2: 'sha256'}.get(hash_type)
        if magic != 0xfade0c02 or algorithm is None or hash_size != hashlib.new(algorithm).digest_size:
            raise ValueError('Unsupported CodeDirectory hash format')
        if not 44 <= identifier < hashes - special * hash_size or directory.find(b'\0', identifier, hashes - special * hash_size) == -1:
            raise ValueError('Invalid CodeDirectory identifier')
        if directory[identifier:directory.index(b'\0', identifier)].decode() != info['CFBundleIdentifier']:
            raise ValueError('CodeDirectory identifier does not match Info.plist')
        if covered != code_limit or page_shift > 30:
            raise ValueError('Invalid CodeDirectory code coverage')
        page_size = 1 << page_shift if page_shift else covered
        if not page_size or pages != (covered + page_size - 1) // page_size:
            raise ValueError('Invalid CodeDirectory page count')
        if special < 5 or hashes - special * hash_size < 44 or hashes + pages * hash_size > length:
            raise ValueError('Invalid CodeDirectory hash table')
        def digest(content):
            return hashlib.new(algorithm, content).digest()
        for index in range(pages):
            start = index * page_size
            expected = directory[hashes + index * hash_size:hashes + (index + 1) * hash_size]
            if digest(data[start:min(start + page_size, covered)]) != expected:
                raise ValueError('Executable code hash mismatch at page ' + str(index))
        special_data = dict(blobs)
        special_data.update({1: info_data, 3: resource_data})
        for index in range(1, special + 1):
            content = special_data.get(index)
            expected = digest(content) if content is not None else bytes(hash_size)
            if directory[hashes - index * hash_size:hashes - (index - 1) * hash_size] != expected:
                raise ValueError('CodeDirectory special slot mismatch: ' + str(index))
        algorithms.add(algorithm)
    if 0 not in blobs or algorithms != {'sha1', 'sha256'}:
        raise ValueError('Both SHA-1 and SHA-256 CodeDirectories are required')


def verify_bundle(read, expected_entitlements=None):
    info_data = read('Info.plist')
    info = plistlib.loads(info_data)
    resource_data = read('_CodeSignature/CodeResources')
    resources = plistlib.loads(resource_data)
    for table in ('files', 'files2'):
        if not isinstance(resources.get(table), dict) or not resources[table]:
            raise ValueError('Missing resource seal: ' + table)
        for name, entry in resources[table].items():
            entry = {'hash': entry} if isinstance(entry, bytes) else entry
            for key, algorithm in (('hash', 'sha1'), ('hash2', 'sha256')):
                if key in entry and hashlib.new(algorithm, read(name)).digest() != entry[key]:
                    raise ValueError('Resource hash mismatch: ' + name)
    slices = macho_slices(read(info['CFBundleExecutable']))
    for index, data in enumerate(slices):
        try:
            verify_slice(data, info_data, resource_data, expected_entitlements)
        except (ValueError, struct.error) as error:
            raise ValueError('Architecture slice ' + str(index) + ': ' + str(error)) from error
    return len(slices)


def verify_app(app, entitlements=None):
    app = Path(app)
    expected = plistlib.loads(Path(entitlements).read_bytes()) if entitlements else None
    return verify_bundle(lambda name: (app / name).read_bytes(), expected)


def verify_ipa(ipa, entitlements=None):
    expected = plistlib.loads(Path(entitlements).read_bytes()) if entitlements else None
    with zipfile.ZipFile(ipa) as archive:
        roots = [name[:-len('Info.plist')] for name in archive.namelist()
                 if len(Path(name).parts) == 3 and name.startswith('Payload/') and name.endswith('.app/Info.plist')]
        if len(roots) != 1 or len(archive.namelist()) != len(set(archive.namelist())):
            raise ValueError('Expected one application without duplicate IPA entries')
        return verify_bundle(lambda name: archive.read(roots[0] + name), expected)


def sign_app(app, ldid, entitlements):
    signing_flag = '-S' + str(entitlements) if entitlements else '-S'
    subprocess.run(shlex.split(ldid) + ['-Hsha1', '-Hsha256', signing_flag, str(app)], check=True)
    count = verify_app(app, entitlements)
    print('Bundle signature verified: ' + str(count) + ' architecture(s), SHA-1 + SHA-256')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('path', type=Path)
    parser.add_argument('--entitlements', type=Path)
    args = parser.parse_args()
    verify = verify_app if args.path.is_dir() else verify_ipa
    count = verify(args.path, args.entitlements)
    print('Verified bundle signature: ' + str(count) + ' architecture(s)')
