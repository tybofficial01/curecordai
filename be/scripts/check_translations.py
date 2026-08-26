"""
Consistency check for the Python-side language dictionaries.

Scope: only Python mappings keyed by `app.core.enums.Language` - the AI prompt strings
(services/prompts.py), the email copy (services/email_templates.py), and the SMS bodies
(services/twilio_service.py). Flutter ARB files and the Next.js JSON catalogues are
separate ecosystems and are deliberately NOT scanned here.

What it verifies, for every such mapping found:
  1. All three Language members (en / ur / roman_ur) are present as keys.
  2. Every value is non-empty (no blank/whitespace-only string, no empty container).
  3. For nested dicts (e.g. _OTP_EMAIL_TEXT[Language.EN]["subject"]), every language's
     inner dict has exactly the same set of message keys - a message added to English
     but forgotten in Urdu is the failure mode this catches.
  4. The `{placeholder}` names used in a message are identical across all three
     languages, so a translation can't silently drop `{otp}` or `{minutes}`.

Run:  cd be && python -m scripts.check_translations
Exit code 0 = consistent, 1 = problems found (suitable for CI).
"""
import importlib
import string
import sys

from app.core.enums import Language

# Modules whose module-level globals are scanned. Add new ones here as they gain
# language-keyed copy.
MODULES = (
    "app.services.prompts",
    "app.services.email_templates",
    "app.services.twilio_service",
)

EXPECTED = set(Language)


def _placeholders(value: object) -> set[str]:
    """Named `{...}` fields in a format string; empty set for anything else."""
    if not isinstance(value, str):
        return set()
    try:
        return {name for _, name, _, _ in string.Formatter().parse(value) if name}
    except ValueError:
        # Not a valid format string (e.g. literal braces) - nothing to compare.
        return set()


def _is_empty(value: object) -> bool:
    if isinstance(value, str):
        return not value.strip()
    if isinstance(value, (list, tuple, dict, set)):
        return len(value) == 0 or any(_is_empty(v) for v in value)
    return value is None


def _is_language_keyed(value: object) -> bool:
    return (
        isinstance(value, dict)
        and len(value) > 0
        and all(isinstance(k, Language) for k in value)
    )


def _check_mapping(label: str, mapping: dict, problems: list[str]) -> None:
    missing = EXPECTED - set(mapping)
    if missing:
        problems.append(
            f"{label}: missing language key(s) {sorted(m.value for m in missing)}"
        )

    for lang, value in mapping.items():
        if _is_empty(value):
            problems.append(f"{label}[{lang.value}]: empty value")

    # Nested per-message dicts: compare message-key sets and placeholders across languages.
    nested = {lang: v for lang, v in mapping.items() if isinstance(v, dict)}
    if not nested:
        return
    if len(nested) != len(mapping):
        plain = sorted(l.value for l in mapping if l not in nested)
        problems.append(
            f"{label}: inconsistent shape - {plain} are not dicts while others are"
        )
        return

    reference_lang = Language.EN if Language.EN in nested else next(iter(nested))
    reference_keys = set(nested[reference_lang])
    for lang, inner in nested.items():
        if lang is reference_lang:
            continue
        for key in sorted(reference_keys - set(inner)):
            problems.append(f"{label}[{lang.value}]: missing message key '{key}'")
        for key in sorted(set(inner) - reference_keys):
            problems.append(
                f"{label}[{lang.value}]: extra message key '{key}' "
                f"not present in '{reference_lang.value}'"
            )

    for key in sorted(reference_keys):
        ref_ph = _placeholders(nested[reference_lang].get(key))
        for lang, inner in nested.items():
            if lang is reference_lang or key not in inner:
                continue
            ph = _placeholders(inner[key])
            if ph != ref_ph:
                problems.append(
                    f"{label}[{lang.value}]['{key}']: placeholder mismatch - "
                    f"has {sorted(ph)}, expected {sorted(ref_ph)}"
                )


def main() -> int:
    problems: list[str] = []
    checked = 0

    for module_name in MODULES:
        module = importlib.import_module(module_name)
        found_in_module = 0
        for name, value in sorted(vars(module).items()):
            if not _is_language_keyed(value):
                continue
            found_in_module += 1
            checked += 1
            _check_mapping(f"{module_name}.{name}", value, problems)
        print(f"{module_name}: {found_in_module} language-keyed mapping(s)")
        if found_in_module == 0:
            problems.append(f"{module_name}: no language-keyed mapping found")

    print(f"\nChecked {checked} mapping(s) across {len(MODULES)} module(s).")
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for p in problems:
            print(f"  - {p}")
        return 1
    print("All language mappings are complete and consistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
