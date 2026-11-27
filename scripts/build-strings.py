#!/usr/bin/env python3
"""Builds the String Catalogs from Localization/strings.json (the single source of truth).

  python3 scripts/build-strings.py

Writes App/DCAudioTours/Resources/Localizable.xcstrings and InfoPlist.xcstrings.
Keys are the English text exactly as it appears in Swift (interpolations as %lld / %@), so
SwiftUI's Text("…") / Label("…") / Button("…") find them without any extra code.
Reused wording comes from the web app's locale files; edit strings.json, not the .xcstrings.
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
src = json.loads((ROOT / "Localization" / "strings.json").read_text(encoding="utf-8"))
RES = ROOT / "App" / "DCAudioTours" / "Resources"

def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}

def catalog(entries):
    return {"sourceLanguage": "en", "strings": entries, "version": "1.0"}

strings = {}
for key, langs in src["strings"].items():
    loc = {"en": unit(key)}
    loc.update({lang: unit(text) for lang, text in langs.items()})
    strings[key] = {"extractionState": "manual", "localizations": loc}

info = {}
for key, langs in src["infoPlist"].items():
    info[key] = {"extractionState": "manual",
                 "localizations": {lang: unit(text) for lang, text in langs.items()}}

for name, data in (("Localizable.xcstrings", catalog(strings)), ("InfoPlist.xcstrings", catalog(info))):
    (RES / name).write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {name}: {len(data['strings'])} keys")
