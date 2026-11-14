#!/usr/bin/env python3
"""Compare PE sections and PCK directory hashes from two Godot 4 builds."""
import hashlib
import struct
import sys
from pathlib import Path

MAGIC = b"GDPC"


def sections(path):
    with path.open("rb") as f:
        head = f.read(64)
        if head[:2] != b"MZ":
            raise ValueError(f"{path}: not PE")
        pe = struct.unpack_from("<I", head, 0x3C)[0]
        f.seek(pe)
        coff = f.read(24)
        if coff[:4] != b"PE\0\0":
            raise ValueError(f"{path}: invalid PE header")
        machine, count = struct.unpack_from("<HH", coff, 4)
        optional_size = struct.unpack_from("<H", coff, 20)[0]
        f.seek(pe + 24 + optional_size)
        entries = []
        for _ in range(count):
            entry = f.read(40)
            name = entry[:8].split(b"\0")[0].decode("ascii", "replace")
            raw_size, raw_offset = struct.unpack_from("<II", entry, 16)
            entries.append((name, raw_offset, raw_size))
        return machine, entries


def digest_range(path, start, length):
    digest = hashlib.sha256()
    with path.open("rb") as f:
        f.seek(start)
        while length:
            data = f.read(min(1024 * 1024, length))
            if not data:
                raise ValueError("unexpected EOF")
            digest.update(data)
            length -= len(data)
    return digest.hexdigest()


def pck_directory(path, offset):
    with path.open("rb") as f:
        f.seek(offset)
        if f.read(4) != MAGIC:
            # PE section can contain up to seven bytes of alignment padding.
            f.seek(offset)
            data = f.read(12)
            pos = data.find(MAGIC)
            if pos < 0:
                raise ValueError(f"{path}: PCK header not found at {offset}")
            f.seek(offset + pos + 4)
        version, major, minor, patch, flags = struct.unpack("<IIIII", f.read(20))
        if version != 2 or flags & 1:
            raise ValueError(f"unsupported or encrypted pack version={version} flags={flags}")
        f.read(8 + 16 * 4)
        count = struct.unpack("<I", f.read(4))[0]
        if count > 100000:
            raise ValueError(f"invalid file count {count}")
        files = {}
        for _ in range(count):
            name_len = struct.unpack("<I", f.read(4))[0]
            if name_len > 8192:
                raise ValueError(f"invalid path length {name_len}")
            name = f.read(name_len).rstrip(b"\0").decode("utf-8")
            offset_file, size = struct.unpack("<QQ", f.read(16))
            digest = f.read(16).hex()
            file_flags = struct.unpack("<I", f.read(4))[0]
            files[name] = (size, digest, file_flags)
        return (version, major, minor, patch, flags), files


def main():
    official, custom, standalone = map(Path, sys.argv[1:4])
    machine_a, a = sections(official)
    machine_b, b = sections(custom)
    print("Official PE machine:", hex(machine_a), "size:", official.stat().st_size)
    print("Custom PE machine:", hex(machine_b), "size:", custom.stat().st_size)
    for name in (".text", ".rdata", ".data"):
        for label, path, entries in (("official", official, a), ("custom", custom, b)):
            section = next((item for item in entries if item[0] == name), None)
            if section and section[2]:
                print(label, name, "bytes=", section[2], "sha256=", digest_range(path, section[1], section[2]))
    pck_sections = [section for section in a if section[0] == "pck"]
    if len(pck_sections) != 1:
        raise ValueError("official executable did not have one embedded pck section")
    meta_a, files_a = pck_directory(official, pck_sections[0][1])
    meta_b, files_b = pck_directory(standalone, 0)
    print("Official pack header:", meta_a, "file count:", len(files_a))
    print("Diagnostic pack header:", meta_b, "file count:", len(files_b))
    added = sorted(files_b.keys() - files_a.keys())
    removed = sorted(files_a.keys() - files_b.keys())
    changed = sorted(k for k in files_a.keys() & files_b.keys() if files_a[k] != files_b[k])
    print("Only diagnostic:", len(added))
    for name in added:
        print(" +", name)
    print("Only official:", len(removed))
    for name in removed:
        print(" -", name)
    print("Different size/hash/flags:", len(changed))
    for name in changed:
        print(" *", name, files_a[name], files_b[name])
    print("Identical file entries:", len(files_a.keys() & files_b.keys()) - len(changed))


if __name__ == "__main__":
    main()
