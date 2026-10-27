#!/usr/bin/env python3
"""Create an unsigned review candidate. Does NOT establish base authenticity.

Never executes downloaded code. Replaces the known injected load commands and
files, preserving all executable bytes outside the Mach-O load-command region.
Sideloadly must re-sign the result before any device use.
"""
import hashlib
from copy import copy
import json
import plistlib
import struct
import sys
import zipfile
from pathlib import Path

ROOT = 'Payload/Instagram.app/'
HELPER = ROOT + 'Frameworks/zxPluginsInject.dylib'
BLOCKER = ROOT + 'Frameworks/ReelsBlocker.dylib'
REMOVED_PREFIXES = (ROOT + 'RyukGram.bundle/', ROOT + 'Frameworks/CydiaSubstrate.framework/')
REMOVED_FILE = ROOT + 'Frameworks/RyukGram.dylib'
BASE_SHA = 'fefc9d23b678723427e7cd4744817edf21a866a2f317e3e855c6ab52c477a90f'
HELPER_SHA = 'cd903ea15657cbd356398adcb60c8872c41c29b69acc1a5dfb78a49d6e75dea5'
BLOCKER_SHA = '49601b2c7cc82548e8797d15f993176e9b53ce46a62e5b29fe2423b2a7903df7'
LOAD_COMMANDS = (0xC, 0x80000018, 0x8000001F, 0x20, 0x80000023)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def commands(data):
    assert data[:4] == bytes.fromhex('cffaedfe')
    off = 32
    result = []
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        cmd, size = struct.unpack_from('<II', data, off)
        assert size >= 8 and size % 8 == 0 and off + size <= len(data)
        raw = data[off:off+size]
        name = None
        if cmd in LOAD_COMMANDS:
            start = struct.unpack_from('<I', raw, 8)[0]
            name = raw[start:].split(b'\0', 1)[0].decode()
        result.append((cmd, raw, name))
        off += size
    assert off == 32 + struct.unpack_from('<I', data, 20)[0]
    return result, off

def dylib_command(name):
    encoded = name.encode() + b'\0'
    size = (24 + len(encoded) + 7) & ~7
    return struct.pack('<6I', 0xC, size, 24, 0, 0, 0) + encoded.ljust(size - 24, b'\0')

def patch_main(data):
    original, old_end = commands(data)
    unwanted = {'@rpath/RyukGram.dylib', '@rpath/zxPluginsInject.dylib'}
    assert {name for _, _, name in original if name in unwanted} == unwanted
    kept = [raw for _, raw, name in original if name not in unwanted]
    kept += [dylib_command('@rpath/ReelsBlocker.dylib'), dylib_command('@rpath/zxPluginsInject.dylib')]
    joined = b''.join(kept)
    new_end = 32 + len(joined)
    # Grow only into verified zero-filled header padding, before all sections.
    section_offsets = []
    for cmd, raw, _ in original:
        if cmd == 0x19:
            for i in range(struct.unpack_from('<I', raw, 64)[0]):
                section = 72 + i * 80
                offset = struct.unpack_from('<I', raw, section + 48)[0]
                if offset:
                    section_offsets.append(offset)
    assert section_offsets and max(old_end, new_end) <= min(section_offsets)
    assert not any(data[old_end:max(old_end, new_end)])
    result = bytearray(data)
    struct.pack_into('<II', result, 16, len(kept), len(joined))
    result[32:max(old_end, new_end)] = joined.ljust(max(old_end, new_end) - 32, b'\0')
    # No code, data, signature blob, or file offsets are changed.
    assert len(result) == len(data)
    assert result[max(old_end, new_end):] == data[max(old_end, new_end):]
    assert result[:16] == data[:16] and result[24:32] == data[24:32]
    parsed, _ = commands(result)
    assert not any(name in unwanted - {'@rpath/zxPluginsInject.dylib'} for _, _, name in parsed)
    return bytes(result), max(old_end, new_end)

def main():
    base, previous, blocker_path, output = map(Path, sys.argv[1:])
    assert not output.exists(), 'Never overwrite an existing build'
    assert sha(base.read_bytes()) == BASE_SHA
    blocker = blocker_path.read_bytes()
    assert sha(blocker) == BLOCKER_SHA
    with zipfile.ZipFile(previous) as old:
        helper = old.read(HELPER)
    assert sha(helper) == HELPER_SHA
    with zipfile.ZipFile(base) as source:
        infos = [i for i in source.infolist() if not i.is_dir()]
        assert len({i.filename for i in infos}) == len(infos)
        main_data, header_end = patch_main(source.read(ROOT + 'Instagram'))
        plist = plistlib.loads(source.read(ROOT + 'Info.plist'))
        assert plist['CFBundleShortVersionString'] == '451.0.0'
        plist['UIFileSharingEnabled'] = False
        replacements = {ROOT+'Instagram':main_data, ROOT+'Info.plist':plistlib.dumps(plist, fmt=plistlib.FMT_BINARY), HELPER:helper}
        removed, preserved = [], []
        with zipfile.ZipFile(output, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as target:
            for info in infos:
                name = info.filename
                assert not name.startswith('/') and '..' not in Path(name).parts
                if name == REMOVED_FILE or name.startswith(REMOVED_PREFIXES):
                    removed.append(name)
                    continue
                data = replacements.get(name)
                if data is None:
                    data = source.read(name)
                    preserved.append(name)
                target.writestr(copy(info), data)
            target.writestr(BLOCKER, blocker)
        with zipfile.ZipFile(output) as target:
            assert target.testzip() is None
            names = set(target.namelist())
            expected = {i.filename for i in infos} - set(removed) | {BLOCKER}
            assert names == expected
            for name in preserved:
                assert sha(source.read(name)) == sha(target.read(name)), name
            before = plistlib.loads(source.read(ROOT+'Info.plist'))
            after = plistlib.loads(target.read(ROOT+'Info.plist'))
            assert {k for k in before.keys() | after.keys() if before.get(k) != after.get(k)} == {'UIFileSharingEnabled'}
            forbidden = (b'ryukgram', b'cydiasubstrate', b'libflex.dylib', b'scinsta.dylib')
            binaries = []
            for name in sorted(names):
                with target.open(name) as f:
                    if f.read(4) != bytes.fromhex('cffaedfe'):
                        continue
                data = target.read(name)
                assert not any(word in data.lower() for word in forbidden), name
                binaries.append({'name':name,'sha256':sha(data),'bytes':len(data)})
        (output.parent/'Instagram-451-v2-main-for-scan').write_bytes(main_data)
        report = dict(base_sha256=BASE_SHA, ipa_sha256=sha(output.read_bytes()), removed=removed,
                      added=[BLOCKER], changed=sorted(replacements), unchanged_file_count=len(preserved),
                      main_unchanged_after_offset=header_end, binaries=binaries,
                      file_sharing_enabled=False, source_authenticity_verified=False,
                      signature_valid=False, requires_resigning=True, device_tested=False,
                      disclaimer='Experimental review candidate derived from a third-party modified IPA. Removing known additions and passing static checks do not establish safety, authenticity, or functionality.')
        output.with_suffix('.verification.json').write_text(json.dumps(report, indent=2))
        print(json.dumps({k:v for k,v in report.items() if k not in ('removed','binaries')}, indent=2))

if __name__ == '__main__':
    main()
