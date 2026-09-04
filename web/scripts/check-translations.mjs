#!/usr/bin/env node
// Verifies web/messages/{en,ur,roman-ur}.json carry identical, non-empty key
// sets - covers both the marketing namespaces and the dashboard/auth "app"
// namespace (web/lib/locale/dashboardMessages.ts), since both now load from
// these same three files. Mirrors be/scripts/check_translations.py's job for
// the backend's language-keyed prompt/email/SMS dicts.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const dir = path.dirname(fileURLToPath(import.meta.url));
const messagesDir = path.join(dir, "..", "messages");
const locales = ["en", "ur", "roman-ur"];

function flatten(obj, prefix = "") {
  const keys = new Map();
  for (const [key, value] of Object.entries(obj)) {
    const full = prefix ? `${prefix}.${key}` : key;
    if (value !== null && typeof value === "object" && !Array.isArray(value)) {
      for (const [k, v] of flatten(value, full)) keys.set(k, v);
    } else {
      keys.set(full, value);
    }
  }
  return keys;
}

const catalogs = Object.fromEntries(
  locales.map((locale) => [locale, flatten(JSON.parse(readFileSync(path.join(messagesDir, `${locale}.json`), "utf8")))])
);

let ok = true;
const [base, ...rest] = locales;
const baseKeys = new Set(catalogs[base].keys());

for (const locale of rest) {
  const keys = new Set(catalogs[locale].keys());
  const missing = [...baseKeys].filter((k) => !keys.has(k));
  const extra = [...keys].filter((k) => !baseKeys.has(k));
  if (missing.length) {
    ok = false;
    console.error(`[${locale}] missing ${missing.length} key(s) present in ${base}:`, missing.slice(0, 20));
  }
  if (extra.length) {
    ok = false;
    console.error(`[${locale}] has ${extra.length} extra key(s) not in ${base}:`, extra.slice(0, 20));
  }
}

for (const locale of locales) {
  const empty = [...catalogs[locale].entries()].filter(([, v]) => typeof v === "string" && v.trim() === "");
  if (empty.length) {
    ok = false;
    console.error(`[${locale}] has ${empty.length} empty translation(s):`, empty.map(([k]) => k).slice(0, 20));
  }
}

if (!ok) {
  console.error("\nTranslation key check FAILED.");
  process.exit(1);
}

console.log(`Checked ${baseKeys.size} key(s) across ${locales.length} locale(s) (${locales.join(", ")}).`);
console.log("All translation catalogs are complete and consistent.");
