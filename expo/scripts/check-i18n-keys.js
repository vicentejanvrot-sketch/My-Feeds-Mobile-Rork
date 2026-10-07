#!/usr/bin/env node
// Fails when en.json and pt-BR.json don't have exactly the same keys,
// or when a value is empty. Run: node scripts/check-i18n-keys.js
const path = require("path");
const dir = path.join(__dirname, "..", "lib", "i18n", "locales");
const load = (f) => require(path.join(dir, f));

function flatten(obj, prefix = "", out = {}) {
  for (const [k, v] of Object.entries(obj)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === "object") flatten(v, key, out);
    else out[key] = v;
  }
  return out;
}

const en = flatten(load("en.json"));
const pt = flatten(load("pt-BR.json"));
const missingPt = Object.keys(en).filter((k) => !(k in pt));
const missingEn = Object.keys(pt).filter((k) => !(k in en));
const empty = [...Object.entries(en), ...Object.entries(pt)]
  .filter(([, v]) => typeof v !== "string" || v.trim() === "")
  .map(([k]) => k);

// Interpolation variables must match between the two languages.
const vars = (s) => (String(s).match(/{{\s*[\w.]+\s*}}/g) || []).map((x) => x.replace(/\s/g, "")).sort().join(",");
const varMismatch = Object.keys(en).filter((k) => k in pt && vars(en[k]) !== vars(pt[k]));

let ok = true;
const report = (label, list) => {
  if (!list.length) return;
  ok = false;
  console.error(`${label} (${list.length}):\n  ${list.join("\n  ")}`);
};
report("Missing in pt-BR", missingPt);
report("Missing in en", missingEn);
report("Empty values", empty);
report("Interpolation variables differ", varMismatch);
if (!ok) process.exit(1);
console.log(`i18n keys OK: ${Object.keys(en).length} keys in en and pt-BR`);
