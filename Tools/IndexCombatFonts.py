"""Index local TTF files for the optional, private Sintezza_UI_LocalFonts addon."""

import argparse
import hashlib
import json
from pathlib import Path
import re
from struct import error as StructError, unpack_from

UI = Path(__file__).resolve().parents[1]
COMPANION = "Sintezza_UI_LocalFonts"
DIGITS = set(range(0x30, 0x3A))
LATIN = set(range(0x41, 0x5B)) | set(range(0x61, 0x7B))
RUSSIAN = set(range(0x410, 0x450)) | {0x401, 0x451}
REQUIRED = DIGITS | LATIN | RUSSIAN


def tables(data):
    if data[:4] not in (b"\0\1\0\0", b"OTTO", b"true"):
        raise ValueError("Not an OpenType font")
    count = unpack_from(">H", data, 4)[0]
    result = {}
    for index in range(count):
        tag, _, offset, length = unpack_from(">4sIII", data, 12 + 16 * index)
        if offset + length > len(data):
            raise ValueError("Font table extends past file")
        result[tag] = data[offset:offset + length]
    return result


def font_name(data, fallback):
    _, count, storage = unpack_from(">HHH", data)
    names = {}
    for index in range(count):
        platform, _, language, name_id, length, offset = unpack_from(">HHHHHH", data, 6 + 12 * index)
        if name_id not in (1, 2, 16, 17) or platform not in (0, 3):
            continue
        start = storage + offset
        name = data[start:start + length].decode("utf-16-be", "replace").strip()
        name = "".join(character for character in name if character.isprintable() and character != "|")
        if name and (name_id not in names or language == 0x409):
            names[name_id] = name
    family = names.get(16) or names.get(1) or fallback
    style = names.get(17) or names.get(2)
    if style and style not in ("Regular", "Normal") and not style.isnumeric() and not family.endswith(style):
        family += " " + style
    return family[:96]


def bmp_coverage(data):
    segment_count = unpack_from(">H", data, 6)[0] // 2
    end, start = 14, 16 + 2 * segment_count
    delta, offset = start + 2 * segment_count, start + 4 * segment_count
    for index in range(0, 2 * segment_count, 2):
        last = unpack_from(">H", data, end + index)[0]
        first = unpack_from(">H", data, start + index)[0]
        shift = unpack_from(">H", data, delta + index)[0]
        distance = unpack_from(">H", data, offset + index)[0]
        for point in REQUIRED:
            if not first <= point <= last:
                continue
            glyph = point
            if distance:
                glyph = unpack_from(">H", data, offset + index + distance + 2 * (point - first))[0]
                if glyph == 0:
                    continue
            if (glyph + shift) & 0xFFFF:
                yield point


def full_coverage(data, consecutive):
    group_count = unpack_from(">I", data, 12)[0]
    for index in range(group_count):
        first, last, glyph = unpack_from(">III", data, 16 + 12 * index)
        for point in REQUIRED:
            if first <= point <= last and (glyph != 0 or consecutive and point > first):
                yield point


def coverage(cmap):
    starts = set()
    points = set()
    supported = False
    count = unpack_from(">H", cmap, 2)[0]
    for index in range(count):
        platform, encoding, start = unpack_from(">HHI", cmap, 4 + 8 * index)
        if start in starts or not (platform == 0 or platform == 3 and encoding in (1, 10)):
            continue
        starts.add(start)
        fmt = unpack_from(">H", cmap, start)[0]
        if fmt == 4:
            supported = True
            length = unpack_from(">H", cmap, start + 2)[0]
            points.update(bmp_coverage(cmap[start:start + length]))
        elif fmt in (12, 13):
            supported = True
            length = unpack_from(">I", cmap, start + 4)[0]
            points.update(full_coverage(cmap[start:start + length], fmt == 12))
    if supported:
        return len(points & DIGITS), len(points & RUSSIAN), len(points & LATIN)


def write_addon(destination, indexed, slots):
    media = destination / "Media"
    media.mkdir(parents=True, exist_ok=True)
    lines = ["-- Generated locally. Keep this addon and its fonts private.", "Sintezza_UI_LocalCombatFonts = {"]
    for hash_key, (label, counts, data) in sorted(indexed.items()):
        file = media / (hash_key + ".ttf")
        if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != hash_key:
            pending_font = file.with_suffix(".tmp")
            pending_font.write_bytes(data)
            pending_font.replace(file)
        safe_label = json.dumps(label, ensure_ascii=False)
        values = ""
        if counts is not None:
            digits, russian, latin = counts
            values = f", digits = {digits}, russian = {russian}, latin = {latin}"
        lines.append(f'    ["{hash_key}"] = {{ label = {safe_label}{values} }},')
    lines.append("}")
    lines.append("Sintezza_UI_IndexedCombatFontSlots = {")
    for slot, target in sorted(slots.items()):
        lines.append(f'    ["{slot}"] = "{target}",')
    lines.append("}")
    manifest = destination / "Fonts.lua"
    pending = manifest.with_suffix(".tmp")
    pending.write_text("\n".join(lines) + "\n", encoding="utf-8")
    pending.replace(manifest)
    (destination / (COMPANION + ".toc")).write_text(
        "## Interface: 120100, 120105, 16001\n"
        "## Title: Sintezza UI Local Fonts\n"
        "## Notes: Private local font index for Sintezza UI.\n"
        "Fonts.lua\n",
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("addons", type=Path, help="WoW Interface/AddOns directory")
    parser.add_argument("--font", type=Path, action="append", default=[], help="Add another user-owned TTF")
    parser.add_argument("--output", type=Path, help="Write the private companion beneath this directory")
    args = parser.parse_args()
    paths = {}
    for source, directory in [
        ("CUSTOM", args.addons / "Sintezza_UI/Media/CombatFonts/Custom"),
        ("FONTMAGIC", args.addons / "FontMagicCustomFonts/Custom"),
    ]:
        paths.update((directory / f"{number}.ttf", (source, number)) for number in range(1, 21))
    companion_dirs = {args.addons / COMPANION / "Media"}
    if args.output:
        companion_dirs.add(args.output / COMPANION / "Media")
    retained = {path for directory in companion_dirs for path in directory.glob("*.ttf")}
    for path in retained | set(args.font):
        paths.setdefault(path, None)
    theme = UI.parent / "Sintezza_Theme" / "Media"
    bundle_paths = {
        "RUBIK": UI / "Media/CombatFonts/RubikWetPaint-Regular.ttf",
        "FIRA": theme / "FiraSans Bold.ttf",
        "FIRA_MEDIUM": theme / "FiraSans Medium.ttf",
        "SPECTRAL": theme / "Spectral-Medium.ttf",
    }
    bundled = {hashlib.sha256(path.read_bytes()).hexdigest(): key for key, path in bundle_paths.items() if path.is_file()}
    indexed = {}
    slots = {}
    for directory in companion_dirs:
        manifest = directory.parent / "Fonts.lua"
        if manifest.is_file():
            slots.update(re.findall(
                r'^    \["((?:CUSTOM|FONTMAGIC):\d+)"\] = "([A-Z_0-9:abcdef]+)",$',
                manifest.read_text(encoding="utf-8"),
                flags=re.MULTILINE,
            ))
    for path, slot in paths.items():
        if not path.is_file():
            continue
        try:
            data = path.read_bytes()
            hash_key = hashlib.sha256(data).hexdigest()
            if path in retained and hash_key != path.stem.lower():
                raise ValueError("Private file contents differ from its indexed hash")
            font_tables = tables(data)
            label = font_name(font_tables.get(b"name", b"\0" * 6), path.stem)
            counts = coverage(font_tables[b"cmap"])
        except (ValueError, KeyError, StructError) as exc:
            print(f"{path.name}: {exc}")
            continue
        digits, russian, latin = counts or ("?", "?", "?")
        print(f"{label}: digits {digits}/10, Russian {russian}/66, English {latin}/52")
        if slot:
            slots[f"{slot[0]}:{slot[1]}"] = bundled.get(hash_key, "LOCAL:" + hash_key)
        if hash_key not in bundled:
            indexed[hash_key] = (label, counts, data)
    if args.output:
        targets = set(bundled.values()) | {"LOCAL:" + hash_key for hash_key in indexed}
        write_addon(args.output / COMPANION, indexed, {slot: target for slot, target in slots.items() if target in targets})


if __name__ == "__main__":
    main()
