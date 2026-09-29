/**
 * The hand-computed known-answer world for the frontier projection and metrics
 * laws. Every wire, multiplicity, provenance ordinal, and metric vector of this
 * world is worked out by hand in the tests that consume it.
 *
 * Tree (locations table included, so directories have real paths):
 *
 *   root ""                       location 5,  point 10
 *   ├── a/                        location 6,  point 11
 *   │   ├── a/x.ts                file 1, point 1 — symbols xa (s1, point 6), xb (s2, point 7)
 *   │   ├── a/y.ts                file 2, point 2 — no symbols
 *   │   └── a/sub/                location 8,  point 13
 *   │       └── a/sub/z.ts        file 3, point 3 — symbol za (s3, point 8)
 *   ├── b/                        location 7,  point 12
 *   │   └── b/w.ts                file 4, point 4 — symbol wa (s4, point 9)
 *   ├── c/                        location 9,  point 14 — empty (the isolated region)
 *   └── top.ts                    file 0, point 0 — symbol top (s0, point 5)
 *
 * Basis dependency edges (relations.parquet rows; the file writes them in
 * canonical relation order, so row ordinals are: defines 0-4, imports 5-11,
 * calls 12-16, parent 17-25):
 *
 *   imports (file -> file):
 *     row  5  a/x.ts   -> a/y.ts      internal to a
 *     row  6  a/x.ts   -> a/sub/z.ts  internal to a; crosses a/sub's boundary
 *     row  7  a/sub/z.ts -> b/w.ts    crosses a/sub, a, and b's boundaries
 *     row  8  b/w.ts   -> a/x.ts      crosses b and a's boundaries
 *     row  9  top.ts   -> top.ts      self-loop, internal to top.ts
 *     row 10  a/y.ts   -> b/w.ts      \
 *     row 11  a/y.ts   -> b/w.ts      / duplicate pair: multiplicity 2 at every grain
 *   calls (symbol -> symbol):
 *     row 12  xa -> xb                same file: internal to a/x.ts
 *     row 13  xa -> za                internal to a; ingress a/sub
 *     row 14  za -> wa                egress a/sub and a; ingress b
 *     row 15  top -> top              self-loop, internal to top.ts
 *     row 16  wa -> top               egress b; ingress top.ts
 */
import { projectTables, type FileHashes, type ViewerGraph } from "../../projection/src/graph.ts";
import type {
  EntityRow,
  LocationRow,
  MetadataRow,
  RelationRow,
  WorldTables,
} from "../../projection/src/tables.ts";

export const FRONTIER_SNAPSHOT_ID =
  "repository-snapshot-v1:1111111111111111111111111111111111111111111111111111111111111111";

const HASHES: FileHashes = {
  metadata: "3".repeat(64),
  entities: "4".repeat(64),
  relations: "5".repeat(64),
  locations: "6".repeat(64),
};

/** Point ids of the fixture, so the tests never hard-code the id scheme. */
export const FIXTURE_IDS = {
  topFile: "file:0",
  xFile: "file:1",
  yFile: "file:2",
  zFile: "file:3",
  wFile: "file:4",
  topSym: "symbol:0",
  xaSym: "symbol:1",
  xbSym: "symbol:2",
  zaSym: "symbol:3",
  waSym: "symbol:4",
  root: "location:5",
  a: "location:6",
  b: "location:7",
  sub: "location:8",
  c: "location:9",
} as const;

function metadata(): MetadataRow {
  return {
    repository: "acme/frontier-fixture",
    baseRevision: "abcdef02",
    sourceTreeIdentity: "source-tree:cccc",
    factIdentity: "facts:dddd",
    snapshotId: FRONTIER_SNAPSHOT_ID,
    fileCount: 5,
    symbolCount: 5,
    definesCount: 5,
    importsCount: 7,
    callsCount: 5,
    parentCount: 9,
    unresolvedImports: 0,
    unresolvedCalls: 0,
  };
}

function fileEntity(entityId: number, path: string): EntityRow {
  return {
    snapshotId: FRONTIER_SNAPSHOT_ID,
    domain: "file",
    entityId,
    ordinal: entityId,
    path,
    name: null,
    startByte: null,
    endByte: null,
  };
}

function symbolEntity(entityId: number, path: string, name: string): EntityRow {
  return {
    snapshotId: FRONTIER_SNAPSHOT_ID,
    domain: "symbol",
    entityId,
    ordinal: entityId,
    path,
    name,
    startByte: 10 * entityId,
    endByte: 10 * entityId + 5,
  };
}

function entities(): EntityRow[] {
  return [
    fileEntity(0, "top.ts"),
    fileEntity(1, "a/x.ts"),
    fileEntity(2, "a/y.ts"),
    fileEntity(3, "a/sub/z.ts"),
    fileEntity(4, "b/w.ts"),
    symbolEntity(0, "top.ts", "top"),
    symbolEntity(1, "a/x.ts", "xa"),
    symbolEntity(2, "a/x.ts", "xb"),
    symbolEntity(3, "a/sub/z.ts", "za"),
    symbolEntity(4, "b/w.ts", "wa"),
  ];
}

function locationRow(locationId: number, path: string, kind: string): LocationRow {
  return {
    snapshotId: FRONTIER_SNAPSHOT_ID,
    locationId,
    path,
    kind,
  };
}

function locations(): LocationRow[] {
  return [
    locationRow(0, "top.ts", "file"),
    locationRow(1, "a/x.ts", "file"),
    locationRow(2, "a/y.ts", "file"),
    locationRow(3, "a/sub/z.ts", "file"),
    locationRow(4, "b/w.ts", "file"),
    locationRow(5, "", "directory"),
    locationRow(6, "a", "directory"),
    locationRow(7, "b", "directory"),
    locationRow(8, "a/sub", "directory"),
    locationRow(9, "c", "directory"),
  ];
}

function relationRow(
  relation: string,
  sourceDomain: string,
  sourceId: number,
  targetDomain: string,
  targetId: number,
): RelationRow {
  return {
    snapshotId: FRONTIER_SNAPSHOT_ID,
    relation,
    sourceDomain,
    sourceId,
    targetDomain,
    targetId,
  };
}

function relations(): RelationRow[] {
  return [
    // defines (rows 0-4)
    relationRow("defines", "file", 0, "symbol", 0),
    relationRow("defines", "file", 1, "symbol", 1),
    relationRow("defines", "file", 1, "symbol", 2),
    relationRow("defines", "file", 3, "symbol", 3),
    relationRow("defines", "file", 4, "symbol", 4),
    // imports (rows 5-11)
    relationRow("imports", "file", 1, "file", 2),
    relationRow("imports", "file", 1, "file", 3),
    relationRow("imports", "file", 3, "file", 4),
    relationRow("imports", "file", 4, "file", 1),
    relationRow("imports", "file", 0, "file", 0),
    relationRow("imports", "file", 2, "file", 4),
    relationRow("imports", "file", 2, "file", 4),
    // calls (rows 12-16)
    relationRow("calls", "symbol", 1, "symbol", 2),
    relationRow("calls", "symbol", 1, "symbol", 3),
    relationRow("calls", "symbol", 3, "symbol", 4),
    relationRow("calls", "symbol", 0, "symbol", 0),
    relationRow("calls", "symbol", 4, "symbol", 0),
    // parent (rows 17-25): every file and every non-root directory has one parent
    relationRow("parent", "location", 0, "location", 5),
    relationRow("parent", "location", 1, "location", 6),
    relationRow("parent", "location", 2, "location", 6),
    relationRow("parent", "location", 3, "location", 8),
    relationRow("parent", "location", 4, "location", 7),
    relationRow("parent", "location", 6, "location", 5),
    relationRow("parent", "location", 7, "location", 5),
    relationRow("parent", "location", 8, "location", 6),
    relationRow("parent", "location", 9, "location", 5),
  ];
}

export function frontierFixtureTables(): WorldTables {
  return {
    metadata: metadata(),
    entities: entities(),
    relations: relations(),
    locations: locations(),
  };
}

export function frontierFixtureGraph(): ViewerGraph {
  return projectTables(frontierFixtureTables(), HASHES);
}
