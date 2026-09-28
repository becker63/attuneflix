/**
 * Node CLI driven by the Bazel `:data` target (js_run_binary). Projects every
 * staged world, copies its Parquet inputs into the content-addressed output tree
 * `data/<snapshot-digest>/`, and writes `manifest.json`. Any world that fails to
 * project fails the action.
 *
 * Usage: cli --worlds <dir of <digest>/{metadata,entities,relations}.parquet>
 *            --out <dir>
 *            [--locations <dir of <digest>/locations.parquet>]
 *            [--families <dir of <digest>/{families,family_*}.parquet>]
 */
import { mkdir, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { ProjectionError } from "./errors.ts";
import {
  attachFamilies,
  FAMILY_TABLE_FILES,
  manifestEntry,
  serializeManifest,
  type FamiliesTableAssets,
  type FamiliesTableHashes,
  type WorldManifestEntry,
} from "./manifest.ts";
import { projectWorld } from "./project.ts";
import { sha256Hex } from "./sha256.ts";
import { fileExists, readBytes, readWorldDir } from "./world_dir.ts";

interface CliOptions {
  readonly worlds: string;
  readonly out: string;
  readonly locations: string | null;
  readonly families: string | null;
  readonly synthetic: string | null;
}

function parseArgs(argv: readonly string[]): CliOptions {
  let worlds: string | null = null;
  let out: string | null = null;
  let locations: string | null = null;
  let families: string | null = null;
  let synthetic: string | null = null;
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (flag === undefined) {
      throw new Error("unexpected end of arguments");
    }
    if (value === undefined || value.startsWith("--")) {
      throw new Error(`missing value for ${flag}`);
    }
    switch (flag) {
      case "--worlds":
        worlds = value;
        break;
      case "--out":
        out = value;
        break;
      case "--locations":
        locations = value;
        break;
      case "--families":
        families = value;
        break;
      case "--synthetic":
        synthetic = value;
        break;
      default:
        throw new Error(`unknown argument ${flag}`);
    }
    i += 1;
  }
  if (worlds === null || out === null) {
    throw new Error(
      "usage: cli --worlds <dir> --out <dir> [--locations <dir>] [--families <dir>] [--synthetic <dir>]",
    );
  }
  return { worlds, out, locations, families, synthetic };
}

/** One staged families table of a world: its file name and bytes. */
interface FamilyFile {
  readonly file: string;
  readonly bytes: ArrayBuffer;
}

/** The staged families export of one world, keyed by table. */
type FamilyFiles = Record<keyof FamiliesTableAssets, FamilyFile>;

/**
 * The staged families export of one world (every file of FAMILY_TABLE_FILES),
 * or null when the world has none. The export is the Flix-built science; this
 * CLI only ships its bytes.
 */
async function readFamilies(root: string, digest: string): Promise<FamilyFiles | null> {
  const dir = path.join(root, digest);
  if (!(await fileExists(dir))) return null;
  const read = async (table: keyof FamiliesTableAssets): Promise<FamilyFile> => {
    const file = FAMILY_TABLE_FILES[table];
    return { file, bytes: await readBytes(path.join(dir, file)) };
  };
  return {
    families: await read("families"),
    members: await read("members"),
    rollups: await read("rollups"),
    edges: await read("edges"),
    contributions: await read("contributions"),
  };
}

async function projectDir(
  dir: string,
  outDir: string,
  digest: string,
  locationsFile: string | null,
  families: FamilyFiles | null,
  synthetic: boolean,
): Promise<WorldManifestEntry> {
  const files = await readWorldDir(dir, locationsFile);
  const { metadata, entities, relations, locations } = files;

  const graph = await projectWorld(files);
  let entry = manifestEntry(graph, synthetic);
  if (entry.snapshotDigest !== digest) {
    throw new ProjectionError({
      kind: "snapshot-mismatch",
      table: "directory",
      row: 0,
      expected: digest,
      actual: entry.snapshotDigest,
    });
  }

  const assetDir = path.join(outDir, "data", digest);
  await mkdir(assetDir, { recursive: true });
  await writeFile(path.join(assetDir, "metadata.parquet"), new Uint8Array(metadata));
  await writeFile(path.join(assetDir, "entities.parquet"), new Uint8Array(entities));
  await writeFile(path.join(assetDir, "relations.parquet"), new Uint8Array(relations));
  if (locations !== undefined) {
    await writeFile(path.join(assetDir, "locations.parquet"), new Uint8Array(locations));
  }
  if (families !== null) {
    const ship = async ({ file, bytes }: FamilyFile): Promise<string> => {
      await writeFile(path.join(assetDir, file), new Uint8Array(bytes));
      return sha256Hex(bytes);
    };
    const hashes: FamiliesTableHashes = {
      families: await ship(families.families),
      members: await ship(families.members),
      rollups: await ship(families.rollups),
      edges: await ship(families.edges),
      contributions: await ship(families.contributions),
    };
    entry = attachFamilies(entry, hashes);
  }
  return entry;
}

async function projectOne(
  worldsDir: string,
  locationsDir: string | null,
  familiesDir: string | null,
  outDir: string,
  digest: string,
): Promise<WorldManifestEntry> {
  const locationsFile = locationsDir === null ? null : path.join(locationsDir, digest, "locations.parquet");
  const families = familiesDir === null ? null : await readFamilies(familiesDir, digest);
  return projectDir(path.join(worldsDir, digest), outDir, digest, locationsFile, families, false);
}

async function projectSynthetic(syntheticDir: string, outDir: string): Promise<WorldManifestEntry | null> {
  const digests = (await readdir(syntheticDir, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name);
  if (digests.length === 0) return null;
  if (digests.length > 1) {
    throw new Error(`synthetic fixture dir must hold exactly one world, found ${digests.length}`);
  }
  const digest = digests[0];
  if (digest === undefined) return null;
  const dir = path.join(syntheticDir, digest);
  return projectDir(dir, outDir, digest, path.join(dir, "locations.parquet"), null, true);
}

async function main(argv: readonly string[]): Promise<number> {
  const options = parseArgs(argv);
  const digests = (await readdir(options.worlds, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .toSorted((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  const entries: WorldManifestEntry[] = [];
  for (const digest of digests) {
    try {
      const entry = await projectOne(
        options.worlds,
        options.locations,
        options.families,
        options.out,
        digest,
      );
      entries.push(entry);
      console.log(
        `projected ${digest} ${entry.repository} points=${entry.counts.points} links=${entry.counts.links}`,
      );
    } catch (error) {
      if (error instanceof ProjectionError) {
        console.error(`projection failed for world ${digest}: ${error.message}`);
        return 1;
      }
      throw error;
    }
  }
  let synthetic: WorldManifestEntry | null = null;
  if (options.synthetic !== null) {
    synthetic = await projectSynthetic(options.synthetic, options.out);
    if (synthetic === null) {
      console.error(`synthetic dir ${options.synthetic} holds no world`);
      return 1;
    }
    console.log(
      `projected synthetic ${synthetic.snapshotDigest} points=${synthetic.counts.points} links=${synthetic.counts.links}`,
    );
  }
  await mkdir(options.out, { recursive: true });
  await writeFile(path.join(options.out, "manifest.json"), serializeManifest(entries, synthetic));
  console.log(`manifest.json: ${entries.length} worlds, synthetic=${synthetic !== null}`);
  return 0;
}

async function run(): Promise<void> {
  try {
    process.exitCode = await main(process.argv.slice(2));
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

void run();
