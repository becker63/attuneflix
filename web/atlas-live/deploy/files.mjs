/**
 * Small filesystem helpers shared by the deploy scripts and their tests.
 */
import fs from "node:fs";
import path from "node:path";

/** Every file under `root`, recursively, in directory order. */
export function listFiles(root) {
  const files = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else files.push(full);
    }
  };
  walk(root);
  return files;
}

/** Total size in bytes of every file under `root`. */
export function treeSize(root) {
  let total = 0;
  for (const file of listFiles(root)) total += fs.statSync(file).size;
  return total;
}

/**
 * Makes every file and directory under `root` writable. Bazel outputs are
 * read-only (`0555`), and `fs.cpSync` preserves that, so a copied tree must be
 * made writable before the deploy can stamp it or remove it.
 */
export function makeWritable(root) {
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        fs.chmodSync(full, 0o755);
      } else {
        fs.chmodSync(full, 0o644);
      }
    }
  };
  walk(root);
  fs.chmodSync(root, 0o755);
}
