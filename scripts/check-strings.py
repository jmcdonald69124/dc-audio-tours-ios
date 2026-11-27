#!/usr/bin/env python3
"""Fails if translations or Swift call sites drift. Runs in CI (no Xcode needed).

1. strings.json: every language present and non-empty for every key; printf-style specifiers match English.
2. Swift sources: every user-facing string literal passed to a SwiftUI text API has a catalog key
   (language-neutral strings such as numbers and flags are exempt).
3. The generated .xcstrings files are up to date with strings.json.
"""
import json, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
src = json.loads((ROOT / "Localization" / "strings.json").read_text(encoding="utf-8"))
LANGS = [l for l in src["languages"] if l != "en"]
errors = []

SPEC = re.compile(r"%(?:\d+\$)?(lld|@|lf|d)")
def specs(s): return sorted(SPEC.findall(s))

for key, tr in src["strings"].items():
    for lang in LANGS:
        v = tr.get(lang, "")
        if not v.strip(): errors.append(f"missing {lang}: {key!r}")
        elif specs(v) != specs(key): errors.append(f"specifier mismatch {lang}: {key!r} -> {v!r}")
for key, tr in src["infoPlist"].items():
    for lang in src["languages"]:
        if not tr.get(lang, "").strip(): errors.append(f"missing {lang} in InfoPlist: {key}")

# -- Swift call sites ---------------------------------------------------------------------------
API = r'(?:Text|Label|Button|Eyebrow|navigationTitle|ContentUnavailableView|Section|LabeledContent|Picker|Toggle|' \
      r'DisclosureGroup|accessibilityLabel|accessibilityHint|accessibilityValue|Link|rows|check|clip|pill)'
LIT = re.compile(API + r'\(\s*"((?:[^"\\]|\\.)*)"')
keys = set(src["strings"])
def swift_key(lit):
    return re.sub(r"\\\((?:[^()]|\([^()]*\))*\)", "§", lit)        # interpolation -> placeholder

def matches(lit):
    k = swift_key(lit)
    if "§" not in k: return k in keys
    pat = re.compile("^" + "".join(".*" if c == "§" else re.escape(c) for c in k) + "$")
    # an interpolation is %lld or %@ in the key
    return any(pat.match(re.sub(r"%lld|%@", "", key).strip() or key) is not None or
               re.fullmatch("".join(r"(?:%lld|%@)" if c == "§" else re.escape(c) for c in k), key) for key in keys)

NEUTRAL = re.compile(r"^[^A-Za-z]*$|^\\\(.*\)\.?$|^§[.\s§]*$")
EXEMPT = {"Language", "Developer", "Unlock all tours", "DC Audio Tours"}
for path in sorted((ROOT / "App").rglob("*.swift")):
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        for m in LIT.finditer(line):
            lit = m.group(1)
            k = swift_key(lit)
            if NEUTRAL.match(k) or re.fullmatch(r"[§\s.·]*", k) or lit in EXEMPT: continue
            if re.fullmatch(r"[a-z]+(\.[a-z0-9.]+)+", lit): continue          # SF Symbol names
            if not re.search(r"[A-Za-z]{3}", re.sub("§", "", k)): continue
            if not matches(lit):
                errors.append(f"no catalog key for {lit!r} at {path.relative_to(ROOT)}:{n}")

# -- ternary of string literals compiles to a plain String and silently skips localization -------------
TERNARY = re.compile(r'\?\s*"[^"]*"\s*:\s*"')
for path in sorted((ROOT / "App").rglob("*.swift")):
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if TERNARY.search(line) and not any(t in line for t in ("systemName", "LocalizedStringKey", "PlayfairDisplay")):
            errors.append(f"ternary of string literals (not localized) at {path.relative_to(ROOT)}:{n}: {line.strip()[:90]}")

# -- generated catalogs are current ----------------------------------------------------------------
before = {p.name: p.read_bytes() for p in (ROOT / "App/DCAudioTours/Resources").glob("*.xcstrings")}
subprocess.run([sys.executable, str(ROOT / "scripts/build-strings.py")], check=True, stdout=subprocess.DEVNULL)
for p in (ROOT / "App/DCAudioTours/Resources").glob("*.xcstrings"):
    if before.get(p.name) != p.read_bytes(): errors.append(f"{p.name} was stale — run scripts/build-strings.py and commit")

if errors:
    print("\n".join(errors)); print(f"\n{len(errors)} problem(s)"); sys.exit(1)
print(f"strings OK: {len(src['strings'])} keys × {len(LANGS)} languages")
