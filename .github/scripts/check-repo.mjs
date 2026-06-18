#!/usr/bin/env node
// Repo guard: fails on duplicate phase-number prefixes or broken relative markdown links.
// No dependencies. Run: node .github/scripts/check-repo.mjs
import { readdirSync, readFileSync, statSync, existsSync } from 'fs';
import { join, dirname, resolve } from 'path';

const root = process.cwd();
const errors = [];

// 1) Duplicate NN- phase-folder prefixes
const phaseDirs = readdirSync(root).filter(
  (d) => /^\d\d-/.test(d) && statSync(join(root, d)).isDirectory()
);
const byNum = {};
for (const d of phaseDirs) (byNum[d.slice(0, 2)] ||= []).push(d);
for (const [num, ds] of Object.entries(byNum))
  if (ds.length > 1) errors.push(`Duplicate phase number ${num}: ${ds.join(', ')}`);

// 2) Broken relative markdown links
const linkRe = /\]\(([^)]+)\)/g;
function checkFile(file) {
  const text = readFileSync(file, 'utf8');
  let m;
  while ((m = linkRe.exec(text))) {
    const link = m[1].trim();
    if (/^(https?:|mailto:|tel:|#)/i.test(link) || /^[a-z][a-z0-9+.-]*:\/\//i.test(link)) continue;
    const path = link.split('#')[0];
    if (!path) continue;
    if (!existsSync(resolve(dirname(file), path)))
      errors.push(`broken link in ${file.replace(root + '/', '')} -> ${link}`);
  }
}
function walk(dir) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.name === 'node_modules' || e.name === '.git') continue;
    const p = join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.md')) checkFile(p);
  }
}
walk(root);

if (errors.length) {
  console.error(`❌ Repo guard FAILED (${errors.length}):`);
  for (const e of errors) console.error('  - ' + e);
  process.exit(1);
}
console.log('✅ Repo guard passed: no duplicate phase numbers, no broken relative links.');
