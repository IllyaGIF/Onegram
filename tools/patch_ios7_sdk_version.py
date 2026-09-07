#!/usr/bin/python
# -*- coding: utf-8 -*-
"""
Patch LC_VERSION_MIN_IPHONEOS.sdk in a Mach-O executable to iOS 7.0
without changing the minimum deployment target.

Why Onegram needs this:
Xcode 4.6 links against the iOS 6.x SDK.  On iOS 7, UIKit sees that
SDK version and runs the application in the legacy iOS 6 compatibility
mode.  The most visible symptom is the iOS 6 keyboard.  Marking only the
linked SDK field as 7.0 lets iOS 7 use its native UIKit behavior while
keeping LC_VERSION_MIN_IPHONEOS.version (the deployment target) intact.

Compatible with the system Python 2.7 shipped with OS X Mavericks and
with Python 3.
"""
from __future__ import print_function

import os
import struct
import sys

LC_VERSION_MIN_IPHONEOS = 0x25
TARGET_SDK = (7 << 16)  # 7.0.0

MH_MAGIC = 0xfeedface
MH_MAGIC_64 = 0xfeedfacf
FAT_MAGIC_BYTES = b"\xca\xfe\xba\xbe"
FAT_CIGAM_BYTES = b"\xbe\xba\xfe\xca"
FAT_MAGIC_64_BYTES = b"\xca\xfe\xba\xbf"
FAT_CIGAM_64_BYTES = b"\xbf\xba\xfe\xca"


def version_string(value):
    return "%d.%d.%d" % ((value >> 16) & 0xffff, (value >> 8) & 0xff, value & 0xff)


def patch_macho(data, base, size, label):
    if size < 28:
        raise ValueError("%s: Mach-O slice is too small" % label)

    magic_le = struct.unpack_from("<I", data, base)[0]
    if magic_le == MH_MAGIC:
        endian = "<"
        header_size = 28
    elif magic_le == MH_MAGIC_64:
        endian = "<"
        header_size = 32
    else:
        magic_be = struct.unpack_from(">I", data, base)[0]
        if magic_be == MH_MAGIC:
            endian = ">"
            header_size = 28
        elif magic_be == MH_MAGIC_64:
            endian = ">"
            header_size = 32
        else:
            raise ValueError("%s: unsupported Mach-O magic" % label)

    ncmds = struct.unpack_from(endian + "I", data, base + 16)[0]
    sizeofcmds = struct.unpack_from(endian + "I", data, base + 20)[0]
    command_offset = base + header_size
    command_limit = command_offset + sizeofcmds
    slice_limit = base + size

    if command_limit > slice_limit:
        raise ValueError("%s: invalid Mach-O load-command table" % label)

    found = False
    changed = False
    old_sdks = []

    for _ in range(ncmds):
        if command_offset + 8 > command_limit:
            raise ValueError("%s: truncated Mach-O load command" % label)

        cmd, cmdsize = struct.unpack_from(endian + "II", data, command_offset)
        if cmdsize < 8 or command_offset + cmdsize > command_limit:
            raise ValueError("%s: invalid Mach-O load command size" % label)

        if cmd == LC_VERSION_MIN_IPHONEOS:
            if cmdsize < 16:
                raise ValueError("%s: malformed LC_VERSION_MIN_IPHONEOS" % label)
            found = True
            minimum = struct.unpack_from(endian + "I", data, command_offset + 8)[0]
            sdk = struct.unpack_from(endian + "I", data, command_offset + 12)[0]
            old_sdks.append(sdk)

            # Never lower an executable that was genuinely built with a newer SDK.
            if sdk < TARGET_SDK:
                struct.pack_into(endian + "I", data, command_offset + 12, TARGET_SDK)
                changed = True
                print("%s: deployment %s, SDK %s -> %s" % (
                    label, version_string(minimum), version_string(sdk), version_string(TARGET_SDK)))
            else:
                print("%s: deployment %s, SDK already %s (unchanged)" % (
                    label, version_string(minimum), version_string(sdk)))

        command_offset += cmdsize

    if not found:
        raise ValueError("%s: LC_VERSION_MIN_IPHONEOS was not found" % label)

    return changed, old_sdks


def patch_file(path):
    with open(path, "rb") as f:
        raw = f.read()

    data = bytearray(raw)
    if len(data) < 4:
        raise ValueError("file is too small")

    magic = raw[:4]
    changed = False

    if magic in (FAT_MAGIC_BYTES, FAT_CIGAM_BYTES, FAT_MAGIC_64_BYTES, FAT_CIGAM_64_BYTES):
        is_64 = magic in (FAT_MAGIC_64_BYTES, FAT_CIGAM_64_BYTES)
        endian = ">" if magic in (FAT_MAGIC_BYTES, FAT_MAGIC_64_BYTES) else "<"
        nfat_arch = struct.unpack_from(endian + "I", data, 4)[0]
        arch_size = 32 if is_64 else 20
        arch_offset = 8

        for index in range(nfat_arch):
            if arch_offset + arch_size > len(data):
                raise ValueError("truncated FAT architecture table")

            if is_64:
                # cpu type/subtype (2x uint32), offset/size (2x uint64), align/reserved.
                slice_offset = struct.unpack_from(endian + "Q", data, arch_offset + 8)[0]
                slice_size = struct.unpack_from(endian + "Q", data, arch_offset + 16)[0]
            else:
                slice_offset = struct.unpack_from(endian + "I", data, arch_offset + 8)[0]
                slice_size = struct.unpack_from(endian + "I", data, arch_offset + 12)[0]

            if slice_offset + slice_size > len(data):
                raise ValueError("FAT slice %d is outside the file" % index)

            slice_changed, _ = patch_macho(data, int(slice_offset), int(slice_size), "slice %d" % index)
            changed = changed or slice_changed
            arch_offset += arch_size
    else:
        file_changed, _ = patch_macho(data, 0, len(data), "executable")
        changed = changed or file_changed

    if changed:
        # Modify in place so ownership and executable permissions are preserved.
        with open(path, "r+b") as f:
            f.seek(0)
            f.write(data)
            f.truncate()
        print("Patched linked SDK marker in: %s" % path)
    else:
        print("No patch needed: %s" % path)


def main(argv):
    if len(argv) != 2:
        print("usage: %s /path/to/AppExecutable" % os.path.basename(argv[0]), file=sys.stderr)
        return 2

    path = argv[1]
    if not os.path.isfile(path):
        print("error: executable not found: %s" % path, file=sys.stderr)
        return 1

    try:
        patch_file(path)
    except Exception as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
