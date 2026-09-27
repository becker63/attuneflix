/**
 * Entry point of `//web/atlas-live:layout_test`: the Build Output API v3 shape of
 * `:vercel_output`.
 *
 * It pins the two things Vercel reads (`config.json` version 3 with the exact
 * filesystem + SPA route list, and `static/` as the only other top-level entry)
 * and the payload the viewer needs (index.html, the manifest, every world's
 * Parquet, the JS bundle, the stylesheet, and the self-hosted DuckDB eh wasm and
 * worker). Later features add the synthetic fixture, census and trace data to
 * `:static`; the checks here cover what the data targets ship today.
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
  namedAsset(assetsDir, /\.css$/, "stylesheet");
  namedAsset(assetsDir, /^duckdb-eh-.*\.wasm$/, "self-hosted DuckDB eh wasm");
  namedAsset(assetsDir, /^duckdb-browser-eh\.worker-.*\.js$/, "DuckDB eh worker");

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
