/**
 * A small hand-made fixture world. Sizes: F = 3 files, S = 4 symbols, D = 2
 * directories (root "" and "src/"), so parent_count = F + D - 1 = 4.
 *
 * Directory location ids follow admission semantics: ids < F are the files,
 * ids F .. F+D-1 are directories in sorted-prefix order (3 = "" root, 4 = "src/").
 */
import type { FileHashes } from "../src/graph.ts";
import type { EntityRow, LocationRow, MetadataRow, RelationRow, WorldTables } from "../src/tables.ts";

export const FIXTURE_SNAPSHOT_ID =
  "repository-snapshot-v1:f17tu2e0000000000000000000000000000000000000000000000000000000";

export const FIXTURE_HASHES: FileHashes = {
  metadata: "0".repeat(64),
  entities: "1".repeat(64),
  relations: "2".repeat(64),
};

export const FIXTURE_HASHES_WITH_LOCATIONS: FileHashes = {
  ...FIXTURE_HASHES,
  locations: "3".repeat(64),
};

export function fixtureMetadata(): MetadataRow {
  return {
    repository: "acme/fixture",
    baseRevision: "f00dcafe",
    sourceTreeIdentity: "source-tree-fixture-v1:aaaa",
    factIdentity: "repository-facts-v2:bbbb",
    snapshotId: FIXTURE_SNAPSHOT_ID,
    fileCount: 3,
    symbolCount: 4,
    definesCount: 4,
    importsCount: 2,
    callsCount: 3,
    parentCount: 4,
    unresolvedImports: 0,
    unresolvedCalls: 0,
  };
}

export function fixtureEntities(): EntityRow[] {
  const s = FIXTURE_SNAPSHOT_ID;
  return [
    {
      snapshotId: s,
      domain: "file",
      entityId: 0,
      ordinal: 0,
      path: "index.ts",
      name: null,
      startByte: null,
      endByte: null,
    },
    {
      snapshotId: s,
      domain: "file",
      entityId: 1,
      ordinal: 1,
      path: "src/a.ts",
      name: null,
      startByte: null,
      endByte: null,
    },
    {
      snapshotId: s,
      domain: "file",
      entityId: 2,
      ordinal: 2,
      path: "src/b.ts",
      name: null,
      startByte: null,
      endByte: null,
    },
    {
      snapshotId: s,
      domain: "symbol",
      entityId: 0,
      ordinal: 0,
      path: "index.ts",
      name: "main",
      startByte: 0,
      endByte: 10,
    },
    {
      snapshotId: s,
      domain: "symbol",
      entityId: 1,
      ordinal: 1,
      path: "src/a.ts",
      name: "alpha",
      startByte: 20,
      endByte: 40,
    },
    {
      snapshotId: s,
      domain: "symbol",
      entityId: 2,
      ordinal: 2,
      path: "src/b.ts",
      name: "beta",
      startByte: 5,
      endByte: 15,
    },
    {
      snapshotId: s,
      domain: "symbol",
      entityId: 3,
      ordinal: 3,
      path: "src/b.ts",
      name: "gamma",
      startByte: 50,
      endByte: 70,
    },
  ];
}

/** Rows in relations.parquet order: grouped by relation, unsorted within a relation. */
export function fixtureRelations(): RelationRow[] {
  const s = FIXTURE_SNAPSHOT_ID;
  return [
    // defines (file -> symbol)
    {
      snapshotId: s,
      relation: "defines",
      sourceDomain: "file",
      sourceId: 1,
      targetDomain: "symbol",
      targetId: 1,
    },
    {
      snapshotId: s,
      relation: "defines",
      sourceDomain: "file",
      sourceId: 0,
      targetDomain: "symbol",
      targetId: 0,
    },
    {
      snapshotId: s,
      relation: "defines",
      sourceDomain: "file",
      sourceId: 2,
      targetDomain: "symbol",
      targetId: 2,
    },
    {
      snapshotId: s,
      relation: "defines",
      sourceDomain: "file",
      sourceId: 2,
      targetDomain: "symbol",
      targetId: 3,
    },
    // imports (file -> file)
    {
      snapshotId: s,
      relation: "imports",
      sourceDomain: "file",
      sourceId: 0,
      targetDomain: "file",
      targetId: 1,
    },
    {
      snapshotId: s,
      relation: "imports",
      sourceDomain: "file",
      sourceId: 1,
      targetDomain: "file",
      targetId: 2,
    },
    // calls (symbol -> symbol), row 7 is a self-loop
    {
      snapshotId: s,
      relation: "calls",
      sourceDomain: "symbol",
      sourceId: 1,
      targetDomain: "symbol",
      targetId: 2,
    },
    {
      snapshotId: s,
      relation: "calls",
      sourceDomain: "symbol",
      sourceId: 2,
      targetDomain: "symbol",
      targetId: 2,
    },
    {
      snapshotId: s,
      relation: "calls",
      sourceDomain: "symbol",
      sourceId: 3,
      targetDomain: "symbol",
      targetId: 1,
    },
    // parent (location -> location)
    {
      snapshotId: s,
      relation: "parent",
      sourceDomain: "location",
      sourceId: 0,
      targetDomain: "location",
      targetId: 3,
    },
    {
      snapshotId: s,
      relation: "parent",
      sourceDomain: "location",
      sourceId: 1,
      targetDomain: "location",
      targetId: 4,
    },
    {
      snapshotId: s,
      relation: "parent",
      sourceDomain: "location",
      sourceId: 2,
      targetDomain: "location",
      targetId: 4,
    },
    {
      snapshotId: s,
      relation: "parent",
      sourceDomain: "location",
      sourceId: 4,
      targetDomain: "location",
      targetId: 3,
    },
  ];
}

/** The same rows interleaved across relations; per-relation row order is preserved. */
export function fixtureRelationsShuffled(): RelationRow[] {
  const rows = fixtureRelations();
  const pick = [0, 4, 6, 9, 1, 5, 7, 10, 2, 8, 11, 3, 12];
  return pick.map((i) => {
    const row = rows[i];
    if (row === undefined) throw new Error(`fixture pick ${i}`);
    return row;
  });
}

export function fixtureLocations(): LocationRow[] {
  const s = FIXTURE_SNAPSHOT_ID;
  return [
    { snapshotId: s, locationId: 0, path: "index.ts", kind: "file" },
    { snapshotId: s, locationId: 1, path: "src/a.ts", kind: "file" },
    { snapshotId: s, locationId: 2, path: "src/b.ts", kind: "file" },
    { snapshotId: s, locationId: 3, path: "", kind: "directory" },
    { snapshotId: s, locationId: 4, path: "src/", kind: "directory" },
  ];
}

export function fixtureTables(withLocations: boolean): WorldTables {
  return {
    metadata: fixtureMetadata(),
    entities: fixtureEntities(),
    relations: fixtureRelations(),
    locations: withLocations ? fixtureLocations() : null,
  };
}
