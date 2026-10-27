#!/usr/bin/env python3
"""Static package checks, not an antivirus or device functionality test."""
import hashlib, json, struct, sys, zipfile
root = "Payload/Instagram.app/"
blocker = root + "Frameworks/ReelsBlocker.dylib"
helper = root + "Frameworks/zxPluginsInject.dylib"
forbidden = (b"scinsta.dylib", b"libflex.dylib", b"flexing.dylib", b"cydiasubstrate", b"flexmanager")
machos = {bytes.fromhex(x) for x in ("cffaedfe", "cefaedfe", "feedfacf", "feedface", "cafebabe", "bebafeca", "cafebabf", "bfbafeca")}
def digest(data):
    return hashlib.sha256(data).hexdigest()
def dependencies(data):
    assert data[:4] == bytes.fromhex("cffaedfe"), "Expected arm64 Mach-O"
    count = struct.unpack_from("<I", data, 16)[0]
    offset, loads = 32, []
    for _ in range(count):
        command, size = struct.unpack_from("<II", data, offset)
        assert size >= 8 and offset + size <= len(data)
        if command in (0xC, 0x80000018, 0x8000001F, 0x20, 0x80000023):
            start = offset + struct.unpack_from("<I", data, offset + 8)[0]
            loads.append(data[start:offset+size].split(b"\0", 1)[0].decode())
        offset += size
    return loads
with zipfile.ZipFile(sys.argv[1]) as package, zipfile.ZipFile(sys.argv[2]) as base:
    names = {i.filename for i in package.infolist() if not i.is_dir()}
    originals = {i.filename for i in base.infolist() if not i.is_dir()}
    added = names - originals
    assert added == {blocker, helper, root + "cyan.entitlements"}, f"Unexpected additions: {added}"
    assert not originals - names, "Unexpected removed original files"
    binaries = []
    for name in sorted(names):
        assert not any(marker.decode() in name.lower() for marker in forbidden), name
        with package.open(name) as stream:
            magic = stream.read(4)
            if magic not in machos: continue
            data = magic + stream.read()
        assert not any(marker in data.lower() for marker in forbidden), f"Unwanted component in {name}"
        binaries.append(dict(name=name, sha256=digest(data), bytes=len(data)))
    data = package.read(blocker)
    loads = dependencies(data)
    assert loads and all(s.startswith(("/System/Library/", "/usr/lib/")) for s in loads), loads
    assert len(data) < 100_000, "Unexpected blocker size"
    for marker in (b"IGSundialFeedDataSource", b"IGFeedScrollableClipsModel", b"CLIPS", b"setScrollEnabled:"):
        assert marker in data, f"Missing restriction: {marker}"
    assert digest(package.read(helper)) == "cd903ea15657cbd356398adcb60c8872c41c29b69acc1a5dfb78a49d6e75dea5", "Sideload helper changed"
    changed = [n for n in sorted(names & originals) if digest(package.read(n)) != digest(base.read(n))]
    result = dict(added=sorted(added), changed=changed, blocker_dependencies=loads, binaries=binaries,
                  forbidden_components_present=False, scope="Static verification, not a malware-free or runtime guarantee")
print(json.dumps(result, indent=2))
