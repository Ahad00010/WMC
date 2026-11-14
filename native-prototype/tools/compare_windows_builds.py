#!/usr/bin/env python3
"""Compare PE sections and PCK directory hashes from two Godot 4 builds."""
import hashlib
import difflib
from collections import Counter
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
        file_base = struct.unpack("<Q", f.read(8))[0]
        f.read(16 * 4)
        if flags & 2:
            file_base += offset
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
            files[name] = (size, digest, file_flags, file_base + offset_file)
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
    changed = sorted(k for k in files_a.keys() & files_b.keys() if files_a[k][:3] != files_b[k][:3])
    print("Changed by type:", dict(Counter(".import" if k.endswith(".import") else Path(k).suffix for k in changed)))
    print("Different compiled scenes:", [name for name in changed if name.endswith(".scn")])
    print("Different compiled scripts:", [name for name in changed if name.endswith(".gdc")])
    for group, ending in (("compiled texture", ".ctex"), ("script", ".gd"), ("script bytecode", ".gdc")):
        members = [k for k in files_a.keys() & files_b.keys() if k.endswith(ending)]
        different = [k for k in members if files_a[k][:3] != files_b[k][:3]]
        print(f"{group}: total={len(members)} changed={len(different)}")
    for name in ("assets/asphalt.png.import", "assets/bike-mobile.glb.import", "assets/bike-mobile_0.jpg.import"):
        if name not in changed:
            continue
        texts = []
        for path, entry in ((official, files_a[name]), (standalone, files_b[name])):
            with path.open("rb") as f:
                f.seek(entry[3])
                content = f.read(entry[0])
            if hashlib.md5(content).hexdigest() != entry[1]:
                raise ValueError(f"failed to read packed data for {name}")
            texts.append(content.decode("utf-8").splitlines())
        print("Import metadata diff for", name)
        for line in difflib.unified_diff(*texts, fromfile="official", tofile="diagnostic", lineterm=""):
            print(line)
    print("Only diagnostic:", len(added))
    for name in added:
        print(" +", name)
    print("Only official:", len(removed))
    for name in removed:
        print(" -", name)
    print("Different size/hash/flags:", len(changed))
    for name in changed:
        print(" *", name, files_a[name][:3], files_b[name][:3])
    print("Identical file entries:", len(files_a.keys() & files_b.keys()) - len(changed))


if __name__ == "__main__":
    main()
