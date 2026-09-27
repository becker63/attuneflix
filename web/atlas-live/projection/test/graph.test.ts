import { describe, expect, it } from "vitest";

import { ProjectionError } from "../src/errors.ts";
import {
  linkRelation,
  linkSourceDomain,
  linkTargetDomain,
  pointId,
  projectTables,
  type ViewerGraph,
} from "../src/graph.ts";
import { RELATION_ORDER, type Relation } from "../src/relation.ts";
import type { RelationRow, WorldTables } from "../src/tables.ts";
import {
  FIXTURE_HASHES,
  FIXTURE_HASHES_WITH_LOCATIONS,
  fixtureRelationsShuffled,
  fixtureTables,
} from "./fixture.ts";
import { graphSnapshot } from "./snapshot.ts";

function projectFixture(withLocations = false): ViewerGraph {
  return projectTables(
    fixtureTables(withLocations),
    withLocations ? FIXTURE_HASHES_WITH_LOCATIONS : FIXTURE_HASHES,
  );
}

function withRelations(tables: WorldTables, relations: readonly RelationRow[]): WorldTables {
  return { ...tables, relations };
}

function catchProjectionError(fn: () => unknown): ProjectionError {
  try {
    fn();
  } catch (error) {
    if (error instanceof ProjectionError) return error;
    throw error;
  }
  throw new Error("expected a ProjectionError");
}

function expectProjectionError(tables: WorldTables, detail: object): void {
  const error = catchProjectionError(() => projectTables(tables, FIXTURE_HASHES));
  expect(error.detail).toEqual(detail);
}

describe("point order and ids (VAL-PROJ-001)", () => {
  it("orders points file, symbol, location-directory; then ascending entity_id", () => {
    const graph = projectFixture();
    expect([...graph.pointIds]).toEqual([
      "file:0",
      "file:1",
      "file:2",
      "symbol:0",
      "symbol:1",
      "symbol:2",
      "symbol:3",
      "location:3",
      "location:4",
    ]);
    expect(graph.pointCount).toBe(9);
  });

  it("is stable across independent projector runs", () => {
    const a = projectFixture();
    const b = projectFixture(true);
    const c = projectFixture();
    expect(graphSnapshot(a)).toEqual(graphSnapshot(c));
    expect([...b.pointIds]).toEqual([...a.pointIds]);
    for (const [id, index] of a.indexById) {
      expect(b.indexById.get(id)).toBe(index);
      expect(pointId(a, index)).toBe(id);
    }
  });
});

describe("typed endpoints (VAL-PROJ-002)", () => {
  it("keeps the typed (domain, id) endpoints and resolves renderer indices", () => {
    const graph = projectFixture();
    const expected: Array<[Relation, string, number, string, number, number, number]> = [
      ["defines", "file", 1, "symbol", 1, 1, 4],
      ["defines", "file", 0, "symbol", 0, 0, 3],
      ["defines", "file", 2, "symbol", 2, 2, 5],
      ["defines", "file", 2, "symbol", 3, 2, 6],
      ["imports", "file", 0, "file", 1, 0, 1],
      ["imports", "file", 1, "file", 2, 1, 2],
      ["calls", "symbol", 1, "symbol", 2, 4, 5],
      ["calls", "symbol", 2, "symbol", 2, 5, 5],
      ["calls", "symbol", 3, "symbol", 1, 6, 4],
      ["parent", "location", 0, "location", 3, 0, 7],
      ["parent", "location", 1, "location", 4, 1, 8],
      ["parent", "location", 2, "location", 4, 2, 8],
      ["parent", "location", 4, "location", 3, 8, 7],
    ];
    expect(graph.linkCount).toBe(expected.length);
    for (const [i, [relation, sd, si, td, ti, sourceIndex, targetIndex]] of expected.entries()) {
      expect(linkRelation(graph, i)).toBe(relation);
      expect([linkSourceDomain(graph, i), graph.linkSourceIds[i]]).toEqual([sd, si]);
      expect([linkTargetDomain(graph, i), graph.linkTargetIds[i]]).toEqual([td, ti]);
      expect(graph.linkSourceIndices[i]).toBe(sourceIndex);
      expect(graph.linkTargetIndices[i]).toBe(targetIndex);
      // location endpoints with id < F resolve to the file point
      const expectPointId = (domain: string, id: number): string =>
        domain === "location" && id < graph.fileCount ? `file:${id}` : `${domain}:${id}`;
      expect(graph.pointIds[sourceIndex]).toBe(expectPointId(sd, si));
      expect(graph.pointIds[targetIndex]).toBe(expectPointId(td, ti));
    }
  });
});

describe("canonical link order (VAL-PROJ-003)", () => {
  it("orders links by canonical relation order, then original row order", () => {
    const graph = projectFixture();
    expect([...graph.linkRelations]).toEqual([
      0,
      0,
      0,
      0, // defines
      1,
      1, // imports
      2,
      2,
      2, // calls
      3,
      3,
      3,
      3, // parent
    ]);
    expect([...graph.linkRows]).toEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
    expect(graph.relationCounts).toEqual({ defines: 4, imports: 2, calls: 3, parent: 4 });
    expect(graph.linkCount).toBe(13);
  });

  it("preserves per-relation row order even when relations are interleaved in the file", () => {
    const tables = fixtureTables(false);
    const shuffled = withRelations(tables, fixtureRelationsShuffled());
    const graph = projectTables(shuffled, FIXTURE_HASHES);
    const reference = projectFixture();
    // Same canonical link content; only the original-row bookkeeping differs.
    expect([...graph.linkRelations]).toEqual([...reference.linkRelations]);
    expect([...graph.linkSourceDomains]).toEqual([...reference.linkSourceDomains]);
    expect([...graph.linkSourceIds]).toEqual([...reference.linkSourceIds]);
    expect([...graph.linkTargetDomains]).toEqual([...reference.linkTargetDomains]);
    expect([...graph.linkTargetIds]).toEqual([...reference.linkTargetIds]);
    expect([...graph.linkSourceIndices]).toEqual([...reference.linkSourceIndices]);
    expect([...graph.linkTargetIndices]).toEqual([...reference.linkTargetIndices]);
    // Row order within each relation follows the order of the input file.
    expect(Array.from(graph.linkRows.slice(0, 4))).toEqual([0, 4, 8, 11]);
    expect(Array.from(graph.linkRows.slice(4, 6))).toEqual([1, 5]);
    expect(Array.from(graph.linkRows.slice(6, 9))).toEqual([2, 6, 9]);
    expect(Array.from(graph.linkRows.slice(9, 13))).toEqual([3, 7, 10, 12]);
    // Adjacency is content-identical (it is indexed by link position).
    for (const relation of RELATION_ORDER) {
      const a = graph.adjacency[relation];
      const b = reference.adjacency[relation];
      expect([...a.out.offsets]).toEqual([...b.out.offsets]);
      expect([...a.out.points]).toEqual([...b.out.points]);
      expect([...a.out.links]).toEqual([...b.out.links]);
      expect([...a.in.offsets]).toEqual([...b.in.offsets]);
      expect([...a.in.points]).toEqual([...b.in.points]);
      expect([...a.in.links]).toEqual([...b.in.links]);
    }
  });
});

describe("CSR adjacency (VAL-PROJ-004)", () => {
  it("matches a naive recomputation from the link list, per relation", () => {
    const graph = projectFixture();
    for (const relation of RELATION_ORDER) {
      const naiveOut: number[][] = Array.from({ length: graph.pointCount }, () => []);
      const naiveIn: number[][] = Array.from({ length: graph.pointCount }, () => []);
      for (let link = 0; link < graph.linkCount; link++) {
        if (linkRelation(graph, link) !== relation) continue;
        naiveOut[graph.linkSourceIndices[link] ?? -1]?.push(link);
        naiveIn[graph.linkTargetIndices[link] ?? -1]?.push(link);
      }
      const { out, in: inbound } = graph.adjacency[relation];
      expect(out.offsets.length).toBe(graph.pointCount + 1);
      expect(inbound.offsets.length).toBe(graph.pointCount + 1);
      for (let point = 0; point < graph.pointCount; point++) {
        const outStart = out.offsets[point] ?? -1;
        const outEnd = out.offsets[point + 1] ?? -1;
        expect(outStart).toBeLessThanOrEqual(outEnd);
        expect(Array.from(out.links.slice(outStart, outEnd))).toEqual(naiveOut[point]);
        const outPoints = naiveOut[point]?.map((link) => graph.linkTargetIndices[link]);
        expect(Array.from(out.points.slice(outStart, outEnd))).toEqual(outPoints);
        const inStart = inbound.offsets[point] ?? -1;
        const inEnd = inbound.offsets[point + 1] ?? -1;
        expect(inStart).toBeLessThanOrEqual(inEnd);
        expect(Array.from(inbound.links.slice(inStart, inEnd))).toEqual(naiveIn[point]);
        const inPoints = naiveIn[point]?.map((link) => graph.linkSourceIndices[link]);
        expect(Array.from(inbound.points.slice(inStart, inEnd))).toEqual(inPoints);
      }
    }
  });

  it("lists a calls self-loop once as an out-neighbour and once as an in-neighbour", () => {
    const graph = projectFixture();
    const self = 5; // symbol:2
    const { out, in: inbound } = graph.adjacency.calls;
    const outStart = out.offsets[self] ?? -1;
    const outEnd = out.offsets[self + 1] ?? -1;
    expect(Array.from(out.points.slice(outStart, outEnd))).toEqual([5]);
    expect(Array.from(out.links.slice(outStart, outEnd))).toEqual([7]);
    const inStart = inbound.offsets[self] ?? -1;
    const inEnd = inbound.offsets[self + 1] ?? -1;
    expect(Array.from(inbound.points.slice(inStart, inEnd))).toEqual([4, 5]);
    expect(Array.from(inbound.links.slice(inStart, inEnd))).toEqual([6, 7]);
  });
});

describe("typed rejection errors (VAL-PROJ-005)", () => {
  it("rejects an imports row whose target file id does not exist", () => {
    const rows = fixtureTables(false).relations.map((row, i) => (i === 4 ? { ...row, targetId: 99 } : row));
    expectProjectionError(withRelations(fixtureTables(false), rows), {
      kind: "unresolved-endpoint",
      relation: "imports",
      row: 4,
      side: "target",
      domain: "file",
      id: 99,
    });
  });

  it("rejects a defines row whose target symbol id has no entity row", () => {
    const rows = fixtureTables(false).relations.map((row, i) => (i === 0 ? { ...row, targetId: 9 } : row));
    expectProjectionError(withRelations(fixtureTables(false), rows), {
      kind: "unresolved-endpoint",
      relation: "defines",
      row: 0,
      side: "target",
      domain: "symbol",
      id: 9,
    });
  });

  it("rejects a parent row whose target location id is outside 0..F+D-1", () => {
    const rows = fixtureTables(false).relations.map((row, i) => (i === 9 ? { ...row, targetId: 5 } : row));
    expectProjectionError(withRelations(fixtureTables(false), rows), {
      kind: "unresolved-endpoint",
      relation: "parent",
      row: 9,
      side: "target",
      domain: "location",
      id: 5,
    });
  });

  it("rejects an unknown relation name", () => {
    const tables = fixtureTables(false);
    const rows = tables.relations.map((row, i) => (i === 0 ? { ...row, relation: "frobs" } : row));
    expectProjectionError(withRelations(tables, rows), {
      kind: "invalid-relation",
      row: 0,
      relation: "frobs",
      sourceDomain: "file",
      targetDomain: "symbol",
    });
  });

  it("rejects a relation whose endpoint domains do not match the admission triples", () => {
    const tables = fixtureTables(false);
    const rows = tables.relations.map((row, i) =>
      i === 0 ? { ...row, sourceDomain: "symbol", targetDomain: "file" } : row,
    );
    expectProjectionError(withRelations(tables, rows), {
      kind: "invalid-relation",
      row: 0,
      relation: "defines",
      sourceDomain: "symbol",
      targetDomain: "file",
    });
  });

  it("rejects relation rows whose count disagrees with metadata", () => {
    const tables = fixtureTables(false);
    const rows = tables.relations.filter((_, i) => i !== 3);
    const error = catchProjectionError(() => projectTables(withRelations(tables, rows), FIXTURE_HASHES));
    expect(error.detail).toEqual({
      kind: "count-mismatch",
      what: "defines",
      expected: 4,
      actual: 3,
    });
  });
});

describe("determinism (VAL-PROJ-006)", () => {
  it("produces identical structures for identical inputs", () => {
    expect(graphSnapshot(projectFixture(true))).toEqual(graphSnapshot(projectFixture(true)));
  });
});

describe("location points (VAL-PROJ-007, VAL-PROJ-008)", () => {
  it("maps file locations onto file points and adds exactly D directory points", () => {
    const graph = projectFixture(true);
    for (const id of graph.pointIds) {
      expect(id.startsWith("location:0") || id === "location:1" || id === "location:2").toBe(false);
    }
    expect(graph.pointIds.filter((id) => id.startsWith("location:"))).toEqual(["location:3", "location:4"]);
    expect(graph.directoryCount).toBe(2);
    // parent link from location:0 resolves to the file point file:0 (index 0)
    expect(graph.linkSourceIndices[9]).toBe(0);
  });

  it("labels directories from locations.parquet, with the root labelled as the repository root", () => {
    const graph = projectFixture(true);
    expect(graph.pointLabels[7]).toBe("(repository root)");
    expect(graph.pointPaths[7]).toBe("");
    expect(graph.pointLabels[8]).toBe("src/");
    expect(graph.pointPaths[8]).toBe("src/");
  });

  it("labels directories 'directory #<id>' without a locations table and carries no path", () => {
    const graph = projectFixture(false);
    expect(graph.pointLabels[7]).toBe("directory #3");
    expect(graph.pointLabels[8]).toBe("directory #4");
    expect(graph.pointPaths[7]).toBeNull();
    expect(graph.pointPaths[8]).toBeNull();
  });

  it("rejects a locations row whose id is outside the world", () => {
    const tables = fixtureTables(true);
    const bad = (tables.locations ?? []).map((row) =>
      row.locationId === 4 ? { ...row, locationId: 9 } : row,
    );
    const error = catchProjectionError(() =>
      projectTables({ ...tables, locations: bad }, FIXTURE_HASHES_WITH_LOCATIONS),
    );
    expect(error.kind).toBe("invalid-locations");
  });
});

describe("provenance (VAL-PROJ-009)", () => {
  it("copies metadata fields and input sha256 values verbatim", () => {
    const graph = projectFixture(true);
    expect(graph.provenance).toEqual({
      snapshotId: "repository-snapshot-v1:f17tu2e0000000000000000000000000000000000000000000000000000000",
      repository: "acme/fixture",
      baseRevision: "f00dcafe",
      sourceTreeIdentity: "source-tree-fixture-v1:aaaa",
      factIdentity: "repository-facts-v2:bbbb",
      fileSha256: FIXTURE_HASHES_WITH_LOCATIONS,
    });
  });

  it("rejects entities whose snapshot_id differs from metadata", () => {
    const tables = fixtureTables(false);
    const entities = tables.entities.map((row, i) =>
      i === 0 ? { ...row, snapshotId: "repository-snapshot-v1:other" } : row,
    );
    const error = catchProjectionError(() => projectTables({ ...tables, entities }, FIXTURE_HASHES));
    expect(error.detail).toEqual({
      kind: "snapshot-mismatch",
      table: "entities",
      row: 0,
      expected: "repository-snapshot-v1:f17tu2e0000000000000000000000000000000000000000000000000000000",
      actual: "repository-snapshot-v1:other",
    });
  });

  it("rejects relations whose snapshot_id differs from metadata", () => {
    const tables = fixtureTables(false);
    const relations = tables.relations.map((row, i) =>
      i === 12 ? { ...row, snapshotId: "repository-snapshot-v1:other" } : row,
    );
    const error = catchProjectionError(() => projectTables({ ...tables, relations }, FIXTURE_HASHES));
    expect(error.kind).toBe("snapshot-mismatch");
  });

  it("rejects a locations table whose snapshot_id differs from metadata", () => {
    const tables = fixtureTables(true);
    const locations = (tables.locations ?? []).map((row, i) =>
      i === 0 ? { ...row, snapshotId: "repository-snapshot-v1:other" } : row,
    );
    const error = catchProjectionError(() =>
      projectTables({ ...tables, locations }, FIXTURE_HASHES_WITH_LOCATIONS),
    );
    expect(error.kind).toBe("snapshot-mismatch");
  });
});
