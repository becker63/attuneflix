/**
 * Entry point of //web/atlas-live/projection:data_test (a plain js_test, not a
 * Vitest case). Validates the :data output: manifest.json lists exactly the 78
 * ATLAS_WORLDS snapshots, every entry's counts match the formulas over the
 * shipped metadata.parquet, and every shipped file's sha256 matches the manifest.
 */
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { SNAPSHOT_ID_PREFIX, type WorldManifest, type WorldManifestEntry } from "../src/manifest.ts";
import { decodeMetadata, toArrayBuffer } from "../src/tables.ts";

const EXPECTED_WORLD_COUNT = 78;

function fail(message: string): never {
  throw new Error(`data_check: ${message}`);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

/** Shallow shape check; the entry fields themselves are validated against the shipped Parquet below. */
function isWorldManifest(value: unknown): value is WorldManifest {
  return (
    isRecord(value) &&
    value.version === 1 &&
    Array.isArray(value.worlds) &&
    value.worlds.every(isRecord) &&
    (value.synthetic === null || isRecord(value.synthetic))
  );
}

function parseManifest(raw: string): WorldManifest {
  const value: unknown = JSON.parse(raw);
  if (!isWorldManifest(value))
    fail("manifest.json has the wrong shape (expected {version: 1, worlds: [...]})");
  return value;
}

async function readBytes(file: string): Promise<Uint8Array> {
  const buffer = await readFile(file);
  const copy = new Uint8Array(buffer.byteLength);
  copy.set(buffer);
  return copy;
}

/** Validates one manifest entry against the shipped Parquet files it references. */
async function checkEntry(world: WorldManifestEntry): Promise<void> {
  const { snapshotDigest: digest, counts } = world;
  if (world.snapshotId !== `${SNAPSHOT_ID_PREFIX}${digest}`) {
    fail(`${digest}: snapshot id ${world.snapshotId} does not embed the digest`);
  }
  // The :data tree root holds manifest.json; asset paths are relative to it.
  const treeRoot = "data";
  for (const name of ["metadata", "entities", "relations"] as const) {
    const assetPath = world.assets[name];
    if (assetPath !== `data/${digest}/${name}.parquet`) fail(`${digest}: bad asset path ${assetPath}`);
    const bytes = await readBytes(path.join(treeRoot, assetPath));
    const sha256 = createHash("sha256").update(bytes).digest("hex");
    if (sha256 !== world.sha256[name]) fail(`${digest}: sha256 mismatch for ${name}.parquet`);
  }
  if (world.assets.locations !== undefined) {
    const bytes = await readBytes(path.join(treeRoot, world.assets.locations));
    const sha256 = createHash("sha256").update(bytes).digest("hex");
    if (sha256 !== world.sha256.locations) fail(`${digest}: sha256 mismatch for locations.parquet`);
  }

  const metadataBytes = await readBytes(path.join(treeRoot, world.assets.metadata));
  const metadata = await decodeMetadata(toArrayBuffer(metadataBytes));
  if (metadata.snapshotId !== world.snapshotId) fail(`${digest}: metadata snapshot id mismatch`);
  if (metadata.repository !== world.repository) fail(`${digest}: repository mismatch`);
  if (metadata.baseRevision !== world.baseRevision) fail(`${digest}: base revision mismatch`);
  if (metadata.fileCount !== counts.files)
    fail(`${digest}: file_count ${metadata.fileCount} !== ${counts.files}`);
  if (metadata.symbolCount !== counts.symbols) fail(`${digest}: symbol_count mismatch`);
  if (metadata.parentCount !== counts.parent) fail(`${digest}: parent_count mismatch`);
  if (metadata.definesCount !== counts.defines) fail(`${digest}: defines_count mismatch`);
  if (metadata.importsCount !== counts.imports) fail(`${digest}: imports_count mismatch`);
  if (metadata.callsCount !== counts.calls) fail(`${digest}: calls_count mismatch`);
  if (counts.directories !== counts.parent - counts.files + 1) {
    fail(`${digest}: directories ${counts.directories} !== parent - files + 1`);
  }
  if (counts.points !== counts.files + counts.symbols + counts.directories) {
    fail(`${digest}: points ${counts.points} !== F + S + D`);
  }
  if (counts.links !== counts.defines + counts.imports + counts.calls + counts.parent) {
    fail(`${digest}: links ${counts.links} !== defines + imports + calls + parent`);
  }
}

/** The synthetic stress fixture is a separate entry, never a 78-world member. */
async function checkSynthetic(manifest: WorldManifest): Promise<void> {
  const synthetic = manifest.synthetic;
  if (synthetic === null) fail("manifest.json has no synthetic stress fixture entry");
  if (!synthetic.synthetic) fail("the synthetic fixture entry is not labelled synthetic");
  if (synthetic.repository !== "synthetic") fail("the synthetic fixture claims a repository");
  if (synthetic.counts.points !== 10000) fail(`synthetic points ${synthetic.counts.points} !== 10000`);
  if (synthetic.counts.links !== 50000) fail(`synthetic links ${synthetic.counts.links} !== 50000`);
  if (manifest.worlds.some((world) => world.synthetic)) fail("a worlds[] entry is labelled synthetic");

  const digest = synthetic.snapshotDigest;
  for (const name of ["metadata", "entities", "relations", "locations"] as const) {
    const asset = synthetic.assets[name];
    if (asset === undefined) fail(`synthetic fixture is missing ${name}.parquet`);
    const bytes = await readBytes(path.join("data", asset));
    const sha256 = createHash("sha256").update(bytes).digest("hex");
    if (sha256 !== synthetic.sha256[name]) fail(`synthetic: sha256 mismatch for ${name}.parquet`);
  }
  const metadata = await decodeMetadata(
    toArrayBuffer(await readBytes(path.join("data", synthetic.assets.metadata))),
  );
  if (metadata.snapshotId !== synthetic.snapshotId) fail("synthetic metadata snapshot id mismatch");
  if (metadata.fileCount !== synthetic.counts.files) fail("synthetic file_count mismatch");
  if (metadata.symbolCount !== synthetic.counts.symbols) fail("synthetic symbol_count mismatch");
  console.log(`data_check: synthetic stress fixture ${digest} = 10,000 points / 50,000 links`);
}

async function check(): Promise<void> {
  const manifest = parseManifest(await readFile(path.join("data", "manifest.json"), "utf8"));
  const worlds = manifest.worlds;
  if (worlds.length !== EXPECTED_WORLD_COUNT) fail(`expected 78 worlds, got ${worlds.length}`);

  const expected = (await readFile("expected_worlds.txt", "utf8"))
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .toSorted((a, b) => (a < b ? -1 : 1));
  if (expected.length !== EXPECTED_WORLD_COUNT) fail(`expected_worlds.txt has ${expected.length} entries`);

  const digests = worlds.map((world) => world.snapshotDigest).toSorted((a, b) => (a < b ? -1 : 1));
  if (digests.join("\n") !== expected.join("\n")) fail("manifest digests differ from ATLAS_WORLDS");
  for (let i = 1; i < worlds.length; i++) {
    const previous = worlds[i - 1];
    const current = worlds[i];
    if (previous === undefined || current === undefined) fail("sparse worlds");
    if (previous.snapshotId >= current.snapshotId) fail("worlds are not sorted by snapshot id");
  }

  for (const world of worlds) {
    await checkEntry(world);
  }
  await checkSynthetic(manifest);
  console.log(`data_check: ${worlds.length} worlds validated against manifest.json`);
}

async function run(): Promise<void> {
  try {
    await check();
    process.exitCode = 0;
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

void run();
