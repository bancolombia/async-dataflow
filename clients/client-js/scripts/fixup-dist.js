#!/usr/bin/env node
/* eslint-disable */
const fs = require('fs');
const path = require('path');

const distDir = path.resolve(__dirname, '..', 'dist');

const targets = [
  { dir: path.join(distDir, 'cjs'), pkg: { type: 'commonjs' } },
  { dir: path.join(distDir, 'esm'), pkg: { type: 'module' } },
];

for (const { dir, pkg } of targets) {
  if (!fs.existsSync(dir)) {
    console.error(`fixup-dist: expected output directory not found: ${dir}`);
    process.exit(1);
  }
  const pkgPath = path.join(dir, 'package.json');
  fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
  console.log(`fixup-dist: wrote ${pkgPath}`);
}
