/**
 * Entry point of //web/atlas-live/projection:data_test (a plain js_test, not a
 * Vitest case). Validates the :data output: manifest.json lists the 78 frozen
 * census snapshots plus one pinned AttuneFlix snapshot, with every entry's
 * counts matching the formulas over the
 * shipped metadata.parquet, and every shipped file's sha256 matches the manifest.
 */
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { parquetMetadata, parquetReadObjects, parquetSchema } from "hyparquet";

import { FAMILY_TABLE_SCHEMAS } from "../src/families.ts";
import {
  FAMILY_TABLE_FILES,
  FAMILY_TABLE_NAMES,
  SNAPSHOT_ID_PREFIX,
  type WorldManifest,
  type WorldManifestEntry,
} from "../src/manifest.ts";
import { PHYSICAL_COLUMNS } from "../src/physical.ts";
import { ANCHOR_COLUMNS, SCENARIO_COLUMNS } from "../src/anchors.ts";
import { repositorySignatures } from "../src/signatures.ts";
import { decodeMetadata, toArrayBuffer } from "../src/tables.ts";

const EXPECTED_WORLD_COUNT = 79;
const SELF_REVISION = "88f97599901df1be52ce8cb06f2a701c464cbbbe";
const ANCHOR_TARGETS = new Map([
  ["002a462e6f58440bbf60071f1e945b38bb304fe46a38ca6fdfd578248693cf01", "packages/babel-types"],
  ["6bae5cbc218b494824fd4dbdd23e62cdad23301dc9243ee7040a32728daef59a", "src"],
  ["c09c5aceb7270db20383531fa1c5f16b9e592b3592cabb62da376e8a9a41a872", "src"],
  ["e5bfbed1587a474108acc0a043858b1b6c6f118463bcafd6344a0d6e47e4af70", "src/components"],
  ["6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9", "hooks"],
]);

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
  await checkPhysical(treeRoot, world);
  const anchorTarget = ANCHOR_TARGETS.get(digest);
  if (anchorTarget !== undefined) {
    if (world.assets.anchors === undefined || world.sha256.anchors === undefined) {
      fail(`${digest}: missing anchor evidence`);
    }
    for (const [name, expected] of [
      ["masses", ANCHOR_COLUMNS],
      ["scenarios", SCENARIO_COLUMNS],
    ] as const) {
      const asset = world.assets.anchors[name];
      if (asset !== `data/${digest}/${name === "masses" ? "anchors" : "scenarios"}.parquet`) {
        fail(`${digest}: bad anchor asset path`);
      }
      const bytes = await readBytes(path.join(treeRoot, asset));
      if (createHash("sha256").update(bytes).digest("hex") !== world.sha256.anchors[name]) {
        fail(`${digest}: anchor ${name} sha256 mismatch`);
      }
      const buffer = toArrayBuffer(bytes);
      const metadata = parquetMetadata(buffer);
      const columns = parquetSchema(metadata).children.map((child) => child.element.name);
      if (columns.join(",") !== expected.join(",")) fail(`${digest}: anchor ${name} schema mismatch`);
      const rows = await parquetReadObjects({ file: buffer, metadata });
      if (name === "masses") {
        const target = rows.filter((row) => row["anchor_path"] === anchorTarget);
        const file = target.find((row) => row["seed_domain"] === "file");
        const symbol = target.find((row) => row["seed_domain"] === "symbol");
        if (target.length !== 2 || file === undefined || symbol === undefined)
          fail(`${digest}: target anchor missing from both typed domains`);
        if (
          world.repository === "babel/babel" &&
          (Number(file["unique_containing_states"]) !== 0 ||
            Number(file["unique_live_states"]) !== 8 ||
            Number(symbol["unique_containing_states"]) !== 2834 ||
            Number(symbol["unique_live_states"]) !== 3761 ||
            Number(symbol["weighted_containing_observations"]) !== 5314 ||
            Number(symbol["live_observations"]) !== 8022)
        )
          fail(`${digest}: Babel known-answer anchor mass changed`);
      } else {
        if (rows.length !== 8) fail(`${digest}: expected baseline and three masks in both domains`);
        const baselineFile = rows.find(
          (row) => row["intervention"] === "baseline" && row["seed_domain"] === "file",
        );
        const maskedFile = rows.find(
          (row) => row["masked_anchor"] === anchorTarget && row["seed_domain"] === "file",
        );
        const baselineSymbol = rows.find(
          (row) => row["intervention"] === "baseline" && row["seed_domain"] === "symbol",
        );
        const maskedSymbol = rows.find(
          (row) => row["masked_anchor"] === anchorTarget && row["seed_domain"] === "symbol",
        );
        if (
          baselineFile === undefined ||
          baselineSymbol === undefined ||
          maskedFile === undefined ||
          maskedSymbol === undefined ||
          Number(maskedFile["masked_imports"]) + Number(maskedFile["masked_calls"]) <= 0 ||
          Number(maskedFile["observations"]) !== Number(baselineFile["observations"]) ||
          Number(maskedSymbol["observations"]) !== Number(baselineSymbol["observations"])
        )
          fail(`${digest}: target counterfactual is missing or inconsistent`);
        if (
          world.repository === "babel/babel" &&
          (Number(baselineFile?.["extinct_observations"]) !== 26095 ||
            Number(baselineFile?.["total_recurrence"]) !== 2623.2 ||
            Number(maskedFile?.["total_recurrence"]) !== 2623.2 ||
            Number(maskedSymbol?.["masked_calls"]) !== 2262 ||
            Number(maskedSymbol?.["unique_live_states"]) !== 2189 ||
            Number(maskedSymbol?.["live_recurrence"]) <= Number(baselineSymbol?.["live_recurrence"]))
        )
          fail(`${digest}: Babel known-answer counterfactual changed`);
      }
    }
  } else if (world.assets.anchors !== undefined || world.sha256.anchors !== undefined) {
    fail(`${digest}: anchor evidence attached to a different snapshot`);
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

/** Every real snapshot ships a complete measured table and an honest summary. */
async function checkPhysical(treeRoot: string, world: WorldManifestEntry): Promise<void> {
  const { snapshotDigest: digest, physicalSummary: summary } = world;
  const asset = world.assets.physical;
  const hash = world.sha256.physical;
  if (asset !== `data/${digest}/physical.parquet` || hash === undefined || summary === undefined) {
    fail(`${digest}: missing physical artifact or summary`);
  }
  const bytes = await readBytes(path.join(treeRoot, asset));
  if (createHash("sha256").update(bytes).digest("hex") !== hash) fail(`${digest}: physical sha256 mismatch`);
  const buffer = toArrayBuffer(bytes);
  const metadata = parquetMetadata(buffer);
  const columns = parquetSchema(metadata).children.map((child) => child.element.name);
  if (columns.join(",") !== PHYSICAL_COLUMNS.join(",")) fail(`${digest}: physical schema mismatch`);
  const rows = await parquetReadObjects({ file: buffer, metadata });
  if (rows.length !== world.counts.files + world.counts.symbols || summary.seeds !== rows.length) {
    fail(`${digest}: physical seed coverage mismatch`);
  }
  let requests = 0;
  let evaluations = 0;
  let reuses = 0;
  const fractions: number[] = [];
  for (const row of rows) {
    if (row["snapshot_id"] !== world.snapshotId) fail(`${digest}: foreign physical row`);
    const seedRequests = Number(row["physical_transition_requests"]);
    const seedEvaluations = Number(row["physical_transition_evaluations"]);
    const seedReuses = Number(row["physical_transition_reuses"]);
    if (seedRequests <= 0 || seedRequests !== seedEvaluations + seedReuses) {
      fail(`${digest}: physical seed work does not reconcile`);
    }
    requests += seedRequests;
    evaluations += seedEvaluations;
    reuses += seedReuses;
    fractions.push(seedReuses / seedRequests);
  }
  fractions.sort((a, b) => a - b);
  const median = fractions[Math.floor((fractions.length - 1) / 2)];
  if (
    requests !== evaluations + reuses ||
    requests !== summary.requests ||
    evaluations !== summary.evaluations ||
    reuses !== summary.reuses ||
    Math.abs(summary.reuseFraction - reuses / requests) > 1e-12 ||
    median === undefined ||
    Math.abs(summary.medianSeedFraction - median) > 1e-12
  ) {
    fail(`${digest}: physical work does not reconcile with manifest summary`);
  }
}

/**
 * Validates a world's shipped families export: every file's path and sha256
 * match the manifest, its columns and `protocol`/`snapshot_id` identity
 * columns match the declared typed schema, and the row counts satisfy the
 * edge no-invention sums against the world's counts (members = symbols;
 * contributions = imports + calls).
 */
async function checkFamilies(treeRoot: string, world: WorldManifestEntry): Promise<void> {
  const { snapshotDigest: digest, counts } = world;
  const assets = world.assets.families;
  const hashes = world.sha256.families;
  if (assets === undefined || hashes === undefined) fail(`${digest}: incomplete families manifest entry`);
  const rowCount = new Map<string, number>();
  for (const table of FAMILY_TABLE_NAMES) {
    const file = FAMILY_TABLE_FILES[table];
    const assetPath = assets[table];
    if (assetPath !== `data/${digest}/${file}`) fail(`${digest}: bad families asset path ${assetPath}`);
    const bytes = await readBytes(path.join(treeRoot, assetPath));
    const sha256 = createHash("sha256").update(bytes).digest("hex");
    if (sha256 !== hashes[table]) fail(`${digest}: sha256 mismatch for ${file}`);
    const { format, columns } = FAMILY_TABLE_SCHEMAS[table];
    const metadata = parquetMetadata(toArrayBuffer(bytes));
    const actual = parquetSchema(metadata).children.map((child) => child.element.name);
    if (actual.length !== columns.length || !columns.every((column, i) => actual[i] === column)) {
      fail(`${digest}: ${file} has columns ${actual.join(", ")}, expected ${columns.join(", ")}`);
    }
    const rows = await parquetReadObjects({ file: toArrayBuffer(bytes), metadata });
    rowCount.set(table, rows.length);
    for (const row of rows) {
      if (row["protocol"] !== format) fail(`${digest}: ${file} carries a foreign protocol`);
      if (row["snapshot_id"] !== world.snapshotId) fail(`${digest}: ${file} carries another snapshot`);
    }
    if (rows.length === 0) fail(`${digest}: ${file} is empty`);
    if (table === "families") {
      const summary = world.familySummary;
      if (summary === undefined) fail(`${digest}: missing family summary`);
      const sizes = rows.map((row) => Number(row["members"]));
      const largest = Math.max(...sizes);
      if (
        sizes.some((size) => !Number.isSafeInteger(size) || size <= 0) ||
        sizes.reduce((sum, size) => sum + size, 0) !== counts.symbols ||
        summary.count !== rows.length ||
        summary.largestMembers !== largest ||
        Math.abs(summary.largestShare - largest / counts.symbols) > 1e-12
      ) {
        fail(`${digest}: family summary differs from the typed table`);
      }
    }
  }
  if (rowCount.get("members") !== counts.symbols) {
    fail(`${digest}: family_members.parquet has ${rowCount.get("members")} rows, expected ${counts.symbols}`);
  }
  if (rowCount.get("contributions") !== counts.imports + counts.calls) {
    fail(
      `${digest}: family_contributions.parquet has ${rowCount.get("contributions")} rows, ` +
        `expected imports + calls = ${counts.imports + counts.calls}`,
    );
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
  if (worlds.length !== EXPECTED_WORLD_COUNT)
    fail(`expected ${EXPECTED_WORLD_COUNT} worlds, got ${worlds.length}`);

  const expected = (await readFile("expected_worlds.txt", "utf8"))
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .toSorted((a, b) => (a < b ? -1 : 1));
  if (expected.length !== EXPECTED_WORLD_COUNT) fail(`expected_worlds.txt has ${expected.length} entries`);

  const digests = worlds.map((world) => world.snapshotDigest).toSorted((a, b) => (a < b ? -1 : 1));
  if (digests.join("\n") !== expected.join("\n")) fail("manifest digests differ from ATLAS_WORLDS");
  const expectedFamilies = new Set(
    (await readFile("expected_families.txt", "utf8"))
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean),
  );
  const signatures = new Map(
    await repositorySignatures(toArrayBuffer(await readBytes("signatures/report/repositories.parquet"))),
  );
  const selfSignatures = await repositorySignatures(
    toArrayBuffer(await readBytes("self_signatures/signature_report/repositories.parquet")),
  );
  for (const [repository, signature] of selfSignatures) {
    if (signatures.has(repository)) fail(`duplicate signature source: ${repository}`);
    signatures.set(repository, signature);
  }
  const selfWorlds = worlds.filter((world) => world.repository === "attuneflix");
  if (selfWorlds.length !== 1 || selfWorlds[0]?.baseRevision !== SELF_REVISION) {
    fail("pinned AttuneFlix snapshot missing or duplicated");
  }
  for (let i = 1; i < worlds.length; i++) {
    const previous = worlds[i - 1];
    const current = worlds[i];
    if (previous === undefined || current === undefined) fail("sparse worlds");
    if (previous.snapshotId >= current.snapshotId) fail("worlds are not sorted by snapshot id");
  }

  for (const world of worlds) {
    await checkEntry(world);
    const hasFamilies = expectedFamilies.has(world.snapshotDigest);
    if (hasFamilies !== (world.assets.families !== undefined)) {
      fail(`${world.snapshotDigest}: Families export differs from sealed cohort`);
    }
    if (hasFamilies) await checkFamilies("data", world);
    if (JSON.stringify(world.signatureSummary) !== JSON.stringify(signatures.get(world.repository))) {
      fail(`${world.snapshotDigest}: signature differs from typed repository summary table`);
    }
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
