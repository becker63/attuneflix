/**
 * Entry point of //web/atlas-live/projection:import_fixtures_test. Reads the
 * fixture folders the sibling target produced and checks that each one projects
 * or fails exactly as the local-import contract requires: valid and
 * no-locations project (with the expected directory labelling), and each broken
 * folder fails with the specified typed error and no partial graph.
 */
import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { ProjectionError } from "../src/errors.ts";
import { projectTables, type FileHashes, type ViewerGraph } from "../src/graph.ts";
import { decodeWorldFiles, toArrayBuffer, type WorldFiles } from "../src/tables.ts";

const FIXTURES = "import_fixtures";

const HASHES: FileHashes = {
  metadata: "0".repeat(64),
  entities: "1".repeat(64),
  relations: "2".repeat(64),
  locations: "3".repeat(64),
};

function fail(message: string): never {
  throw new Error(`import_fixtures_check: ${message}`);
}

function check(condition: boolean, message: string): void {
  if (!condition) fail(message);
}

async function bytes(file: string): Promise<Uint8Array> {
  const buffer = await readFile(file);
  const copy = new Uint8Array(buffer.byteLength);
  copy.set(buffer);
  return copy;
}

type TableName = "metadata" | "entities" | "relations" | "locations";

async function readFolder(
  folder: string,
  names: readonly TableName[],
): Promise<{ files: WorldFiles; missing: readonly TableName[] }> {
  const present = new Map<TableName, Uint8Array>();
  const missing: TableName[] = [];
  for (const name of names) {
    try {
      present.set(name, await bytes(path.join(FIXTURES, folder, `${name}.parquet`)));
    } catch {
      missing.push(name);
    }
  }
  const metadata = present.get("metadata");
  const entities = present.get("entities");
  const relations = present.get("relations");
  if (metadata === undefined || entities === undefined || relations === undefined) {
    fail(`${folder}: readFolder needs metadata, entities and relations present`);
  }
  const locations = present.get("locations");
  return {
    files:
      locations === undefined
        ? { metadata: toArrayBuffer(metadata), entities: toArrayBuffer(entities), relations: toArrayBuffer(relations) }
        : {
            metadata: toArrayBuffer(metadata),
            entities: toArrayBuffer(entities),
            relations: toArrayBuffer(relations),
            locations: toArrayBuffer(locations),
          },
    missing,
  };
}

async function project(folder: string, names: readonly TableName[]): Promise<ViewerGraph> {
  const { files, missing } = await readFolder(folder, names);
  if (missing.length > 0) fail(`${folder}: missing ${missing.join(", ")}`);
  const tables = await decodeWorldFiles(files);
  return projectTables(tables, HASHES);
}

/** Projects a folder and requires it to fail with the given ProjectionError kind. */
async function expectProjectionError(folder: string, names: readonly TableName[], kind: string): Promise<void> {
  try {
    await project(folder, names);
  } catch (error) {
    if (error instanceof ProjectionError) {
      check(error.kind === kind, `${folder}: expected ${kind}, got ${error.kind} (${error.message})`);
      return;
    }
    fail(`${folder}: expected ProjectionError ${kind}, got ${String(error)}`);
  }
  fail(`${folder}: expected ProjectionError ${kind}, but projection succeeded`);
}

async function checkValid(): Promise<void> {
  const graph = await project("valid", ["metadata", "entities", "relations", "locations"]);
  check(graph.pointCount === 9, `valid: expected 9 points, got ${graph.pointCount}`);
  check(graph.directoryCount === 2, `valid: expected 2 directories, got ${graph.directoryCount}`);
  const root = graph.pointLabels[graph.fileCount + graph.symbolCount];
  const src = graph.pointLabels[graph.fileCount + graph.symbolCount + 1];
  check(root === "(repository root)", `valid: root label was ${String(root)}`);
  check(src === "src/", `valid: src label was ${String(src)}`);
  check(graph.provenance.repository === "fixture/alpha", "valid: repository mismatch");
}

async function checkNoLocations(): Promise<void> {
  const graph = await project("no-locations", ["metadata", "entities", "relations"]);
  check(graph.directoryCount === 2, `no-locations: expected 2 directories, got ${graph.directoryCount}`);
  const first = graph.fileCount + graph.symbolCount;
  check(graph.pointLabels[first] === "directory #3", `no-locations: first dir label ${String(graph.pointLabels[first])}`);
  check(graph.pointLabels[first + 1] === "directory #4", `no-locations: second dir label ${String(graph.pointLabels[first + 1])}`);
  check(graph.pointPaths[first] === null, "no-locations: an unlabelled directory must carry no path");
}

async function checkBrokenFolders(): Promise<void> {
  const all: readonly TableName[] = ["metadata", "entities", "relations", "locations"];
  await expectProjectionError("unresolved-endpoint", all, "unresolved-endpoint");
  await expectProjectionError("snapshot-mismatch", ["metadata", "entities", "relations"], "snapshot-mismatch");
  await expectProjectionError("not-parquet", all, "invalid-schema");
  await expectProjectionError("wrong-schema", all, "invalid-schema");
}

async function checkMissingRelations(): Promise<void> {
  const dir = path.join(FIXTURES, "missing-relations");
  for (const name of ["metadata", "entities", "locations"] as const) {
    await bytes(path.join(dir, `${name}.parquet`));
  }
  let relationsPresent = true;
  try {
    await bytes(path.join(dir, "relations.parquet"));
  } catch {
    relationsPresent = false;
  }
  check(!relationsPresent, "missing-relations: relations.parquet must be absent");
}

async function run(): Promise<void> {
  try {
    await checkValid();
    await checkNoLocations();
    await checkBrokenFolders();
    await checkMissingRelations();
    console.log("import_fixtures_check: valid/no-locations project; unresolved-endpoint, snapshot-mismatch, not-parquet, wrong-schema, missing-relations fail as specified");
    process.exitCode = 0;
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

void run();
