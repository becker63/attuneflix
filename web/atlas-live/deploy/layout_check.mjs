/**
 * Entry point of `//web/atlas-live:layout_test`: the Build Output API v3 shape of
 * `:vercel_output`.
 *
 * It pins the two things Vercel reads (`config.json` version 3 with the exact
 * filesystem + SPA route list, and `static/` as the only other top-level entry)
 * and the payload the viewer needs (index.html, the manifest, every world's
 * Parquet, the JS bundle, the linked stylesheet, and the self-hosted DuckDB eh
 * wasm and worker). Later features add the synthetic fixture, census and trace
 * data to `:static`; the checks here cover what the data targets ship today.
 *
 * The stylesheet check is deliberately two-sided (VAL-STYLE-001): the built
 * index.html must link at least one same-origin stylesheet that exists in the
 * output, that stylesheet must carry the compiled StyleX rules, and every
 * stylesheet the output ships must be linked. A file that is emitted but never
 * linked (the old `assets/stylex.css` fallback) is unstyled UI, and an assertion
 * that only checks the file exists misses it.
 */
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

import { listFiles, treeSize } from "./files.mjs";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(SCRIPT_DIR, "..", "vercel_output");

/** The exact routes VAL-DEPLOY-001 pins for the single-page app. */
const EXPECTED_ROUTES = [{ handle: "filesystem" }, { src: "/(.*)", dest: "/index.html" }];

/** The 78 frozen census worlds (ATLAS_WORLDS in experiments/atlas-swe-explore/census/census.bzl). */
const EXPECTED_WORLDS = 78;

/** A compiled StyleX class selector: `.x` + base36 hash, e.g. `.x1tamke2`. */
const STYLEX_CLASS_RE = /\.x[0-9a-z]{3,}\s*[,{]/;

function check(condition, message) {
  if (!condition) throw new Error(`layout_check: ${message}`);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function isRecord(value) {
  return typeof value === "object" && value !== null;
}

function requireFile(file, what) {
  check(fs.existsSync(file), `${what} is missing at ${path.relative(ROOT, file)}`);
  check(fs.statSync(file).size > 0, `${what} is empty at ${path.relative(ROOT, file)}`);
}

/** Exactly one asset whose name matches `pattern`; returns its path. */
function namedAsset(assetsDir, pattern, what) {
  const matches = fs
    .readdirSync(assetsDir)
    .filter((name) => pattern.test(name))
    .map((name) => path.join(assetsDir, name));
  check(matches.length === 1, `expected exactly one ${what}, found ${matches.length}`);
  const file = matches[0];
  check(file !== undefined, `expected exactly one ${what}`);
  requireFile(file, what);
  return file;
}

function checkTopLevel() {
  const entries = fs.readdirSync(ROOT).toSorted((a, b) => (a < b ? -1 : 1));
  check(
    entries.join(",") === "config.json,static",
    `expected the output root to hold exactly config.json and static/, found ${entries.join(", ")}`,
  );
  check(!fs.existsSync(path.join(ROOT, "functions")), "a functions/ directory must not exist");
}

function checkConfig() {
  const config = readJson(path.join(ROOT, "config.json"));
  check(isRecord(config) && config.version === 3, "config.json must be Build Output API version 3");
  const routes = isRecord(config) ? config.routes : undefined;
  check(Array.isArray(routes), "config.json must list routes");
  check(routes.length === 2, `expected exactly 2 routes, found ${String(routes.length)}`);
  for (let i = 0; i < EXPECTED_ROUTES.length; i += 1) {
    check(
      JSON.stringify(routes[i]) === JSON.stringify(EXPECTED_ROUTES[i]),
      `route ${i} must be ${JSON.stringify(EXPECTED_ROUTES[i])}, found ${JSON.stringify(routes[i])}`,
    );
  }
}

/** The `rel="stylesheet"` link hrefs declared in the built index.html, in order. */
function linkedStylesheetHrefs(html) {
  const hrefs = [];
  for (const match of html.matchAll(/<link\b[^>]*>/gi)) {
    const tag = match[0];
    const rel = /\brel\s*=\s*["']([^"']*)["']/i.exec(tag);
    if (rel === null) continue;
    if (!rel[1].toLowerCase().split(/\s+/).includes("stylesheet")) continue;
    const href = /\bhref\s*=\s*["']([^"']+)["']/i.exec(tag);
    if (href !== null) hrefs.push(href[1]);
  }
  return hrefs;
}

/**
 * The linked-stylesheet contract (VAL-STYLE-001): at least one same-origin
 * stylesheet is linked and present, the linked CSS carries the compiled StyleX
 * rules, and no stylesheet ships unlinked.
 */
function checkStylesheets(staticDir) {
  const html = fs.readFileSync(path.join(staticDir, "index.html"), "utf8");
  const hrefs = linkedStylesheetHrefs(html);
  check(
    hrefs.length >= 1,
    "index.html must link at least one stylesheet (a StyleX build with no link renders unstyled)",
  );
  for (const href of hrefs) {
    check(
      href.startsWith("/") && !href.startsWith("//"),
      `stylesheet ${href} must be same-origin (an absolute /… path served from the deployment)`,
    );
  }

  let linkedCss = 0;
  let stylexRules = 0;
  for (const href of hrefs) {
    if (!href.endsWith(".css")) continue;
    linkedCss += 1;
    const file = path.join(staticDir, href);
    requireFile(file, `linked stylesheet ${href}`);
    if (STYLEX_CLASS_RE.test(fs.readFileSync(file, "utf8"))) stylexRules += 1;
  }
  check(linkedCss >= 1, "index.html must link a .css stylesheet");
  check(stylexRules >= 1, "the linked stylesheet carries no compiled StyleX rules");

  const shipped = listFiles(staticDir).filter((file) => file.endsWith(".css"));
  check(shipped.length >= 1, "the output must ship at least one stylesheet");
  const linked = new Set(hrefs);
  for (const file of shipped) {
    const href = `/${path.relative(staticDir, file)}`;
    check(linked.has(href), `the output ships ${href} but index.html does not link it`);
  }
}

function checkStaticPayload() {
  const staticDir = path.join(ROOT, "static");
  requireFile(path.join(staticDir, "index.html"), "index.html");
  requireFile(path.join(staticDir, "manifest.json"), "manifest.json");

  const manifest = readJson(path.join(staticDir, "manifest.json"));
  const worlds = isRecord(manifest) ? manifest.worlds : undefined;
  check(Array.isArray(worlds), "manifest.json must list worlds");
  check(
    worlds.length === EXPECTED_WORLDS,
    `manifest.json must list ${EXPECTED_WORLDS} worlds, found ${worlds.length}`,
  );
  for (const world of worlds) {
    const digest = isRecord(world) ? world.snapshotDigest : undefined;
    check(typeof digest === "string", "every manifest world must carry a snapshotDigest");
    for (const name of ["metadata", "entities", "relations"]) {
      requireFile(path.join(staticDir, "data", digest, `${name}.parquet`), `${digest} ${name}`);
    }
  }

  const assetsDir = path.join(staticDir, "assets");
  check(fs.existsSync(assetsDir), "static/assets is missing");
  namedAsset(assetsDir, /^index-.*\.js$/, "main JS bundle");
  namedAsset(assetsDir, /^duckdb-eh-.*\.wasm$/, "self-hosted DuckDB eh wasm");
  namedAsset(assetsDir, /^duckdb-browser-eh\.worker-.*\.js$/, "DuckDB eh worker");
  checkStylesheets(staticDir);

  const files = listFiles(staticDir);
  const worldDirs = fs.readdirSync(path.join(staticDir, "data"), { withFileTypes: true });
  console.log(
    `layout_check: config.json v3 with the filesystem + SPA routes, ` +
      `${worlds.length} worlds, ${files.length} static files, ${treeSize(staticDir)} bytes`,
  );
  console.log(`layout_check: static/data holds ${worldDirs.length} snapshot directories`);
}

function run() {
  try {
    checkTopLevel();
    checkConfig();
    checkStaticPayload();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

run();
