/**
 * A small hand-made world for app unit tests. F = 2 files, S = 2 symbols, D = 2
 * directories (root "" and "src/"), so parent_count = F + D - 1 = 3 and the
 * renderer order is file0, file1, symbol0, symbol1, directory root, directory
 * "src/". Link order is defines (2), imports (1), calls (2), parent (3).
 */
import { projectTables, type FileHashes, type ViewerGraph } from "../../projection/src/graph.ts";
import type { EntityRow, MetadataRow, RelationRow, WorldTables } from "../../projection/src/tables.ts";

export const FIXTURE_SNAPSHOT_ID =
  "repository-snapshot-v1:0000000000000000000000000000000000000000000000000000000000000000";

const HASHES: FileHashes = {
  metadata: "0".repeat(64),
  entities: "1".repeat(64),
  relations: "2".repeat(64),
};

function metadata(): MetadataRow {
  return {
    repository: "acme/fixture",
    baseRevision: "abcdef01",
    sourceTreeIdentity: "source-tree:aaaa",
    factIdentity: "facts:bbbb",
    snapshotId: FIXTURE_SNAPSHOT_ID,
    fileCount: 2,
    symbolCount: 2,
    definesCount: 2,
    importsCount: 1,
    callsCount: 2,
    parentCount: 3,
    unresolvedImports: 0,
    unresolvedCalls: 0,
  };
}

function entities(): EntityRow[] {
  return [
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      domain: "file",
      entityId: 0,
      ordinal: 0,
      path: "a.ts",
      name: null,
      startByte: null,
      endByte: null,
    },
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      domain: "file",
      entityId: 1,
      ordinal: 1,
      path: "b.ts",
      name: null,
      startByte: null,
      endByte: null,
    },
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      domain: "symbol",
      entityId: 0,
      ordinal: 0,
      path: "a.ts",
      name: "alpha",
      startByte: 0,
      endByte: 5,
    },
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      domain: "symbol",
      entityId: 1,
      ordinal: 1,
      path: "b.ts",
      name: "beta",
      startByte: 0,
      endByte: 5,
    },
  ];
}

function relations(): RelationRow[] {
  return [
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      relation: "defines",
      sourceDomain: "file",
      sourceId: 0,
      targetDomain: "symbol",
      targetId: 0,
    },
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      relation: "defines",
      sourceDomain: "file",
      sourceId: 1,
      targetDomain: "symbol",
      targetId: 1,
    },
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      relation: "imports",
      sourceDomain: "file",
      sourceId: 0,
      targetDomain: "file",
      targetId: 1,
    },
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      relation: "calls",
      sourceDomain: "symbol",
      sourceId: 0,
      targetDomain: "symbol",
      targetId: 1,
    },
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      relation: "calls",
      sourceDomain: "symbol",
      sourceId: 1,
      targetDomain: "symbol",
      targetId: 0,
    },
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      relation: "parent",
      sourceDomain: "location",
      sourceId: 0,
      targetDomain: "location",
      targetId: 2,
    },
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      relation: "parent",
      sourceDomain: "location",
      sourceId: 1,
      targetDomain: "location",
      targetId: 3,
    },
    {
      snapshotId: FIXTURE_SNAPSHOT_ID,
      relation: "parent",
      sourceDomain: "location",
      sourceId: 3,
      targetDomain: "location",
      targetId: 2,
    },
  ];
}

export function fixtureGraph(): ViewerGraph {
  const tables: WorldTables = {
    metadata: metadata(),
    entities: entities(),
    relations: relations(),
    locations: null,
  };
  return projectTables(tables, HASHES);
}
