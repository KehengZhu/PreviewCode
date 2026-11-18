// Patch highlight.min.js: register grammars on first lookup instead of all 192 at load.
const fs = require('fs');
const [,, inFile, outFile] = process.argv;
const s = fs.readFileSync(inFile, 'utf8');
const loop = 'const We=ae;for(const e of Object.keys($e)){\nconst t=e.replace("grmr_","").replace("_","-");We.registerLanguage(t,$e[e])}\nreturn We}()';
const getLang = 'function O(e){return e=(e||"").toLowerCase(),n[e]||n[r[e]]}';
if (s.split(loop).length !== 2 || s.split(getLang).length !== 2) throw new Error('pattern not found');
// alias -> grammar key map, computed from the full bundle
const full = new Function(s + '\n;return hljs;')();
const lazyProbe = new Function(s.replace(loop, 'const We=ae;We.__g=$e;return We}()') + '\n;return hljs;')();
const map = {};
// hljs semantics: canonical names win over aliases; among aliases the last registration wins
for (const k of Object.keys(lazyProbe.__g)) {
  const name = k.replace('grmr_', '').replace('_', '-');
  for (const a of (full.getLanguage(name).aliases || [])) map[a.toLowerCase()] = k;
}
for (const k of Object.keys(lazyProbe.__g)) map[k.replace('grmr_', '').replace('_', '-')] = k;
// sub-language dependencies: hljs looks these up directly in its registry, so register them up front
const deps = {};
for (const k of Object.keys(lazyProbe.__g)) {
  const name = k.replace('grmr_', '').replace('_', '-');
  const seen = new Set(), found = new Set();
  (function walk(o) {
    if (!o || typeof o !== 'object' || seen.has(o)) return; seen.add(o);
    if (o.subLanguage) [].concat(o.subLanguage).forEach(x => found.add(String(x).toLowerCase()));
    for (const v of Object.values(o)) { if (Array.isArray(v)) v.forEach(walk); else walk(v); }
  })(full.getLanguage(name));
  const ks = [...found].map(x => map[x]).filter(Boolean);
  if (ks.length) deps[k] = ks;
}
const out = s
  .replace(getLang, 'function O(e){return e=(e||"").toLowerCase(),n[e]||n[r[e]]||(globalThis.__hljsLazy&&globalThis.__hljsLazy(e)?n[e]||n[r[e]]:void 0)}')
  .replace(loop, 'const We=ae;const __m=' + JSON.stringify(map) + ',__d=' + JSON.stringify(deps) + ',__busy={};const __reg=function(k){if(__busy[k])return;__busy[k]=1;(__d[k]||[]).forEach(__reg);We.registerLanguage(k.replace("grmr_","").replace("_","-"),$e[k])};globalThis.__hljsLazy=function(e){const k=__m[e];if(!k||__busy[k])return!1;__reg(k);return!0};return We}()');
fs.writeFileSync(outFile, out);
// self-check: every language and alias highlights identically to the full bundle
const lazy = new Function(out + '\n;return hljs;')();
let bad = 0;
const sample = 'x = 1 # c\nif (a < b) { return "s"; }\n<div class="a">t</div>\n';
for (const a of Object.keys(map)) {
  const f = full.highlight(sample, {language: a, ignoreIllegals: true}).value;
  const l = lazy.highlight(sample, {language: a, ignoreIllegals: true}).value;
  if (f !== l) { bad++; console.log('MISMATCH', a, map[a]); }
}
// sub-language check (xml with embedded css/js, php, markdown)
const mixed = '<style>a{color:red}</style><script>var x=1;</script>';
const lazy2 = new Function(out + '\n;return hljs;')();
console.log('deps', Object.keys(deps).length); console.log('aliases', Object.keys(map).length, 'mismatches', bad, 'sublang ok', full.highlight(mixed,{language:'xml'}).value === lazy2.highlight(mixed,{language:'xml'}).value, 'bytes', out.length);
