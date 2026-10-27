#!/usr/bin/env python3
"""Inspect an IPA without executing it; reject FLEX files or runtime references."""
import hashlib
import json
import sys
import zipfile


def verify(path):
    markers = (b"libflex.dylib", b"flexing.dylib", b"flexmanager")
    macho_magic = {
        b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe",
        b"\xfe\xed\xfa\xcf", b"\xfe\xed\xfa\xce",
        b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",
        b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca",
    }
    errors = []
    binaries = 0
    tweaks = []
    with zipfile.ZipFile(path) as ipa:
        for entry in ipa.infolist():
            if entry.is_dir():
                continue
            if any(m.decode() in entry.filename.lower() for m in markers):
                errors.append(f"FLEX file remains: {entry.filename}")
            with ipa.open(entry) as stream:
                magic = stream.read(4)
                if magic not in macho_magic:
                    continue
                content = magic + stream.read()
            binaries += 1
            lower = content.lower()
            for marker in markers:
                if marker in lower:
                    errors.append(f"FLEX reference {marker.decode()} in {entry.filename}")
            if entry.filename.endswith("/SCInsta.dylib"):
                tweaks.append(entry.filename)
                for feature in (b"hide_reels_tab", b"disable_scrolling_reels", b"prevent_doom_scrolling"):
                    if feature not in content:
                        errors.append(f"Missing Reels setting: {feature.decode()}")
    if len(tweaks) != 1:
        errors.append(f"Expected one SCInsta.dylib; found {len(tweaks)}")
    if errors:
        raise SystemExit("\n".join(errors))
    digest = hashlib.sha256()
    with open(path, "rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    print(json.dumps({"ipa": path, "sha256": digest.hexdigest(),
                      "macho_files_checked": binaries, "flex_files_and_references": 0,
                      "reels_setting_markers_present": True,
                      "scope": "Static packaging check, not a malware or runtime safety guarantee"}, indent=2))


if __name__ == "__main__":
    verify(sys.argv[1])
