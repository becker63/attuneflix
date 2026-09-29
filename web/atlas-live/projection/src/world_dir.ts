/**
 * Node-only reading of one world folder (`metadata`, `entities`, `relations`
 * and an optional `locations` Parquet file) into `WorldFiles`. The Bazel CLI and
 * the Node test suites use it; the browser fetches the same files instead.
 */
import { readFile, stat } from "node:fs/promises";
import path from "node:path";

import type { FamiliesFiles } from "./families.ts";
import { FAMILY_TABLE_FILES, FAMILY_TABLE_NAMES } from "./manifest.ts";
import type { WorldFiles } from "./tables.ts";

/** A file's bytes in a fresh ArrayBuffer (hyparquet's AsyncBuffer shape). */
export async function readBytes(file: string): Promise<ArrayBuffer> {
  const buffer = await readFile(file);
  const copy = new Uint8Array(buffer.byteLength);
  copy.set(buffer);
  return copy.buffer;
}

export async function fileExists(file: string): Promise<boolean> {
  try {
    await stat(file);
    return true;
  } catch {
    return false;
  }
}

/**
 * Reads `<dir>/{metadata,entities,relations}.parquet`, plus the locations table
 * when `locationsFile` (default `<dir>/locations.parquet`) exists.
 */
export async function readWorldDir(
  dir: string,
  locationsFile: string | null = path.join(dir, "locations.parquet"),
): Promise<WorldFiles> {
  const metadata = await readBytes(path.join(dir, "metadata.parquet"));
  const entities = await readBytes(path.join(dir, "entities.parquet"));
  const relations = await readBytes(path.join(dir, "relations.parquet"));
  if (locationsFile === null || !(await fileExists(locationsFile))) {
    return { metadata, entities, relations };
  }
  return { metadata, entities, relations, locations: await readBytes(locationsFile) };
}

/**
 * Reads `<dir>/{families,family_members,family_rollups,family_edges,
 * family_contributions}.parquet`, the five files of a world's families export.
 */
export async function readFamiliesDir(dir: string): Promise<FamiliesFiles> {
  const [families, members, rollups, edges, contributions] = await Promise.all(
    FAMILY_TABLE_NAMES.map((table) => readBytes(path.join(dir, FAMILY_TABLE_FILES[table]))),
  );
  // FAMILY_TABLE_NAMES is the exhaustive key list in order, so the tuple is total.
  if (
    families === undefined ||
    members === undefined ||
    rollups === undefined ||
    edges === undefined ||
    contributions === undefined
  ) {
    throw new Error(`incomplete families export in ${dir}`);
  }
  return { families, members, rollups, edges, contributions };
}
