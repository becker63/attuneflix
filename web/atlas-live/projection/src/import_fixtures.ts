/**
 * Node CLI driven by the Bazel `//web/atlas-live/projection:import_fixtures`
 * target. It writes seven small local-import fixture folders, each a set of
 * canonical world Parquet files, so the local-import flow can be exercised
 * against the SAME projection the bundled worlds use:
 *
 *   valid/               metadata, entities, relations, locations (a 9-point world)
 *   no-locations/        the same folder without locations.parquet
 *   unresolved-endpoint/ relations.parquet with one endpoint that does not resolve
 *   snapshot-mismatch/   metadata from world A with entities and relations from world B
 *   missing-relations/   metadata, entities, locations; no relations.parquet
 *   not-parquet/         a text file renamed to relations.parquet
 *   wrong-schema/        a Parquet file whose columns are not the relations schema
 *
 * All bytes are deterministic (no timestamps), and every folder is built through
 * the shared `worldParquetFiles` writer, so the folder the viewer imports is the
 * same format the viewer reads.
 *
 * Usage: import_fixtures --out <dir>
 */
import { mkdir, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { SNAPSHOT_ID_PREFIX } from "./manifest.ts";
import { writeParquet } from "./parquet.ts";
import type { EntityRow, LocationRow, MetadataRow, RelationRow, WorldTables } from "./tables.ts";
import { worldParquetFiles } from "./world_parquet.ts";

/** F = 3 files, S = 4 symbols, D = 2 directories ("", "src/"), parent = F + D - 1 = 4. */
const FILES = 3;
const SYMBOLS = 4;
const DEFINES = 4;
const IMPORTS = 2;
const CALLS = 3;
const PARENT = 4;

interface FixtureSpec {
  readonly digest: string;
  readonly repository: string;
  readonly baseRevision: string;
  readonly sourceTreeIdentity: string;
  readonly factIdentity: string;
}

const WORLD_A: FixtureSpec = {
  digest: "a".repeat(64),
  repository: "fixture/alpha",
  baseRevision: "aaaa0001",
  sourceTreeIdentity: "source-tree-fixture-v1:alpha",
  factIdentity: "repository-facts-v2:alpha",
};

const WORLD_B: FixtureSpec = {
  digest: "b".repeat(64),
  repository: "fixture/beta",
  baseRevision: "bbbb0002",
  sourceTreeIdentity: "source-tree-fixture-v1:beta",
  factIdentity: "repository-facts-v2:beta",
};

function snapshotId(spec: FixtureSpec): string {
  return `${SNAPSHOT_ID_PREFIX}${spec.digest}`;
}

function metadata(spec: FixtureSpec): MetadataRow {
  return {
    repository: spec.repository,
    baseRevision: spec.baseRevision,
    sourceTreeIdentity: spec.sourceTreeIdentity,
    factIdentity: spec.factIdentity,
    snapshotId: snapshotId(spec),
    fileCount: FILES,
    symbolCount: SYMBOLS,
    definesCount: DEFINES,
    importsCount: IMPORTS,
    callsCount: CALLS,
    parentCount: PARENT,
    unresolvedImports: 0,
    unresolvedCalls: 0,
  };
}

function entities(spec: FixtureSpec): EntityRow[] {
  const s = snapshotId(spec);
  const files: EntityRow[] = [
    { snapshotId: s, domain: "file", entityId: 0, ordinal: 0, path: "index.ts", name: null, startByte: null, endByte: null },
    { snapshotId: s, domain: "file", entityId: 1, ordinal: 1, path: "src/a.ts", name: null, startByte: null, endByte: null },
    { snapshotId: s, domain: "file", entityId: 2, ordinal: 2, path: "src/b.ts", name: null, startByte: null, endByte: null },
  ];
  const symbols: EntityRow[] = [
    { snapshotId: s, domain: "symbol", entityId: 0, ordinal: 0, path: "index.ts", name: "main", startByte: 0, endByte: 10 },
    { snapshotId: s, domain: "symbol", entityId: 1, ordinal: 1, path: "src/a.ts", name: "alpha", startByte: 20, endByte: 40 },
    { snapshotId: s, domain: "symbol", entityId: 2, ordinal: 2, path: "src/b.ts", name: "beta", startByte: 5, endByte: 15 },
    { snapshotId: s, domain: "symbol", entityId: 3, ordinal: 3, path: "src/b.ts", name: "gamma", startByte: 50, endByte: 70 },
  ];
  return [...files, ...symbols];
}

function locations(spec: FixtureSpec): LocationRow[] {
  const s = snapshotId(spec);
  return [
    { snapshotId: s, locationId: 0, path: "index.ts", kind: "file" },
    { snapshotId: s, locationId: 1, path: "src/a.ts", kind: "file" },
    { snapshotId: s, locationId: 2, path: "src/b.ts", kind: "file" },
    { snapshotId: s, locationId: 3, path: "", kind: "directory" },
    { snapshotId: s, locationId: 4, path: "src/", kind: "directory" },
  ];
}

function relations(spec: FixtureSpec, badImportTarget: number | null): RelationRow[] {
  const s = snapshotId(spec);
  const imports: RelationRow[] = [
    { snapshotId: s, relation: "imports", sourceDomain: "file", sourceId: 0, targetDomain: "file", targetId: 1 },
    { snapshotId: s, relation: "imports", sourceDomain: "file", sourceId: 1, targetDomain: "file", targetId: 2 },
  ];
  if (badImportTarget !== null) {
    const first = imports[0];
    if (first === undefined) throw new Error("fixture imports must not be empty");
    imports[0] = { ...first, targetId: badImportTarget };
  }
  return [
    { snapshotId: s, relation: "defines", sourceDomain: "file", sourceId: 1, targetDomain: "symbol", targetId: 1 },
    { snapshotId: s, relation: "defines", sourceDomain: "file", sourceId: 0, targetDomain: "symbol", targetId: 0 },
    { snapshotId: s, relation: "defines", sourceDomain: "file", sourceId: 2, targetDomain: "symbol", targetId: 2 },
    { snapshotId: s, relation: "defines", sourceDomain: "file", sourceId: 2, targetDomain: "symbol", targetId: 3 },
    ...imports,
    { snapshotId: s, relation: "calls", sourceDomain: "symbol", sourceId: 1, targetDomain: "symbol", targetId: 2 },
    { snapshotId: s, relation: "calls", sourceDomain: "symbol", sourceId: 2, targetDomain: "symbol", targetId: 2 },
    { snapshotId: s, relation: "calls", sourceDomain: "symbol", sourceId: 3, targetDomain: "symbol", targetId: 1 },
    { snapshotId: s, relation: "parent", sourceDomain: "location", sourceId: 0, targetDomain: "location", targetId: 3 },
    { snapshotId: s, relation: "parent", sourceDomain: "location", sourceId: 1, targetDomain: "location", targetId: 4 },
    { snapshotId: s, relation: "parent", sourceDomain: "location", sourceId: 2, targetDomain: "location", targetId: 4 },
    { snapshotId: s, relation: "parent", sourceDomain: "location", sourceId: 4, targetDomain: "location", targetId: 3 },
  ];
}

function worldTables(spec: FixtureSpec, badImportTarget: number | null = null): WorldTables {
  return {
    metadata: metadata(spec),
    entities: entities(spec),
    relations: relations(spec, badImportTarget),
    locations: locations(spec),
  };
}

/** A Parquet file whose schema is not the relations table (a census-like table). */
function wrongSchemaRelations(): Uint8Array {
  return writeParquet([
    { name: "snapshot_id", kind: "string", values: [snapshotId(WORLD_A)] },
    { name: "seed_domain", kind: "string", values: ["file"] },
    { name: "seed_ordinal", kind: "int32", values: [0] },
  ]);
}

function parseOut(argv: readonly string[]): string {
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--out") {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith("--")) throw new Error("missing value for --out");
      return value;
    }
  }
  throw new Error("usage: import_fixtures --out <dir>");
}

async function writeFolder(dir: string, files: Readonly<Record<string, Uint8Array>>): Promise<void> {
  await mkdir(dir, { recursive: true });
  for (const [name, bytes] of Object.entries(files)) {
    await writeFile(path.join(dir, name), bytes);
  }
}

async function main(argv: readonly string[]): Promise<number> {
  const out = parseOut(argv);
  await rm(out, { recursive: true, force: true });

  const a = worldParquetFiles(worldTables(WORLD_A));
  const b = worldParquetFiles(worldTables(WORLD_B));

  await writeFolder(path.join(out, "valid"), {
    "metadata.parquet": a.metadata,
    "entities.parquet": a.entities,
    "relations.parquet": a.relations,
    "locations.parquet": a.locations,
  });
  await writeFolder(path.join(out, "no-locations"), {
    "metadata.parquet": a.metadata,
    "entities.parquet": a.entities,
    "relations.parquet": a.relations,
  });
  await writeFolder(path.join(out, "unresolved-endpoint"), {
    "metadata.parquet": a.metadata,
    "entities.parquet": a.entities,
    // The metadata still declares 2 imports; row 0's target file id 99 does not resolve.
    "relations.parquet": worldParquetFiles(worldTables(WORLD_A, 99)).relations,
    "locations.parquet": a.locations,
  });
  await writeFolder(path.join(out, "snapshot-mismatch"), {
    "metadata.parquet": a.metadata,
    "entities.parquet": b.entities,
    "relations.parquet": b.relations,
  });
  await writeFolder(path.join(out, "missing-relations"), {
    "metadata.parquet": a.metadata,
    "entities.parquet": a.entities,
    "locations.parquet": a.locations,
  });
  await writeFolder(path.join(out, "not-parquet"), {
    "metadata.parquet": a.metadata,
    "entities.parquet": a.entities,
    "relations.parquet": new TextEncoder().encode("this is a text file, not a Parquet file\n"),
    "locations.parquet": a.locations,
  });
  await writeFolder(path.join(out, "wrong-schema"), {
    "metadata.parquet": a.metadata,
    "entities.parquet": a.entities,
    "relations.parquet": wrongSchemaRelations(),
    "locations.parquet": a.locations,
  });

  console.log(`import fixtures written to ${out}: valid, no-locations, unresolved-endpoint, snapshot-mismatch, missing-relations, not-parquet, wrong-schema`);
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
