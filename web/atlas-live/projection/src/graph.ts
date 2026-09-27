/**
 * The viewer graph: a deterministic, columnar projection of one repository world.
 *
 * Laws (see the mission's architecture.md 4.1 and validation contract):
 * - Points are ordered by domain (file, symbol, location-directory), then by
 *   ascending entity_id. Point ids are "<domain>:<entity_id>"; the renderer index
 *   is the position in these arrays.
 * - A location endpoint with id < file_count is the file with the same id (an
 *   admission law); it maps onto the file point. Location ids in
 *   [file_count, file_count + directory_count) are directory points.
 * - Links are ordered by canonical relation order (defines, imports, calls,
 *   parent), then by original row order within the relation. Each link keeps its
 *   relation name, its typed (domain, id) endpoints, and the resolved indices.
 * - Directory labels come only from the optional locations table; without it a
 *   directory point is labelled "directory #<id>" and carries no path. The
 *   projection never derives a directory path from file paths.
 * - Rows whose endpoints do not resolve, whose snapshot_id differs from metadata,
 *   or whose per-relation counts disagree with metadata are rejected with a
 *   typed ProjectionError. No partial graph is returned.
 */
import { DOMAIN_ORDER, domainRank, type Domain } from "./domain.ts";
import { ProjectionError } from "./errors.ts";
import { RELATION_ORDER, endpointDomains, isRelation, relationRank, type Relation } from "./relation.ts";
import type { EntityRow, LocationRow, RelationRow, WorldTables } from "./tables.ts";

/** sha256 hex digests of the input Parquet files. */
export interface FileHashes {
  readonly metadata: string;
  readonly entities: string;
  readonly relations: string;
  readonly locations?: string;
}

export interface Provenance {
  readonly snapshotId: string;
  readonly repository: string;
  readonly baseRevision: string;
  readonly sourceTreeIdentity: string;
  readonly factIdentity: string;
  readonly fileSha256: FileHashes;
}

/** Compressed-sparse-row adjacency over point indices, in ascending link order. */
export interface Csr {
  /** Length pointCount + 1, monotonically non-decreasing. */
  readonly offsets: Uint32Array;
  /** Neighbour point index per entry. */
  readonly points: Uint32Array;
  /** Link index that produced each entry (for edge highlighting). */
  readonly links: Uint32Array;
}

export interface RelationAdjacency {
  /** out[x]: links whose source is x; neighbour = target point. */
  readonly out: Csr;
  /** in[x]: links whose target is x; neighbour = source point. */
  readonly in: Csr;
}

export interface ViewerGraph {
  readonly provenance: Provenance;
  readonly fileCount: number;
  readonly symbolCount: number;
  readonly directoryCount: number;
  readonly pointCount: number;
  readonly linkCount: number;
  /** index -> "<domain>:<entity_id>" */
  readonly pointIds: readonly string[];
  /** index -> rank into DOMAIN_ORDER */
  readonly pointDomains: Uint8Array;
  readonly pointEntityIds: Int32Array;
  readonly pointLabels: readonly string[];
  /** File/symbol path, exported directory path, or null when unknown. */
  readonly pointPaths: ReadonlyArray<string | null>;
  /** Symbol name; null for files and directories. */
  readonly pointNames: ReadonlyArray<string | null>;
  /** Symbol byte span; -1 when absent. */
  readonly pointStartBytes: Int32Array;
  readonly pointEndBytes: Int32Array;
  /** point id -> renderer index */
  readonly indexById: ReadonlyMap<string, number>;
  /** index -> rank into RELATION_ORDER */
  readonly linkRelations: Uint8Array;
  /** Original row of the link within relations.parquet. */
  readonly linkRows: Int32Array;
  readonly linkSourceDomains: Uint8Array;
  readonly linkSourceIds: Int32Array;
  readonly linkTargetDomains: Uint8Array;
  readonly linkTargetIds: Int32Array;
  readonly linkSourceIndices: Uint32Array;
  readonly linkTargetIndices: Uint32Array;
  readonly relationCounts: Readonly<Record<Relation, number>>;
  readonly adjacency: Readonly<Record<Relation, RelationAdjacency>>;
}

export function pointId(graph: ViewerGraph, index: number): string {
  const id = graph.pointIds[index];
  if (id === undefined) throw new Error(`point index out of range: ${index}`);
  return id;
}

export function pointDomain(graph: ViewerGraph, index: number): Domain {
  return domainAtRank(graph.pointDomains[index] ?? -1);
}

export function linkRelation(graph: ViewerGraph, index: number): Relation {
  const relation = RELATION_ORDER[graph.linkRelations[index] ?? -1];
  if (relation === undefined) throw new Error(`link index out of range: ${index}`);
  return relation;
}

export function linkSourceDomain(graph: ViewerGraph, index: number): Domain {
  return domainAtRank(graph.linkSourceDomains[index] ?? -1);
}

export function linkTargetDomain(graph: ViewerGraph, index: number): Domain {
  return domainAtRank(graph.linkTargetDomains[index] ?? -1);
}

function domainAtRank(rank: number): Domain {
  const domain = DOMAIN_ORDER[rank];
  if (domain === undefined) throw new Error(`invalid domain rank: ${rank}`);
  return domain;
}

/** Label of the root directory (path ""). */
export const ROOT_DIRECTORY_LABEL = "(repository root)";

export function projectTables(tables: WorldTables, fileSha256: FileHashes): ViewerGraph {
  const { metadata, entities, relations, locations } = tables;
  const snapshotId = metadata.snapshotId;
  const fileCount = metadata.fileCount;
  const symbolCount = metadata.symbolCount;
  // parent_count = F + D - 1 (every file and every non-root directory has exactly
  // one parent; the root has none), so D = parent_count - F + 1.
  const directoryCount = metadata.parentCount - fileCount + 1;
  if (directoryCount < 1) {
    throw new ProjectionError({
      kind: "count-mismatch",
      what: "parent_count >= file_count",
      expected: fileCount,
      actual: metadata.parentCount,
    });
  }

  checkSnapshot(
    "entities",
    entities.map((row) => row.snapshotId),
    snapshotId,
  );
  checkSnapshot(
    "relations",
    relations.map((row) => row.snapshotId),
    snapshotId,
  );
  if (locations !== null) {
    checkSnapshot(
      "locations",
      locations.map((row) => row.snapshotId),
      snapshotId,
    );
  }

  const files = partitionEntities(entities, "file", fileCount);
  const symbols = partitionEntities(entities, "symbol", symbolCount);
  const directoryPaths = readDirectoryPaths(locations, fileCount, directoryCount);

  const pointCount = fileCount + symbolCount + directoryCount;
  const pointIds: string[] = [];
  const pointDomains = new Uint8Array(pointCount);
  const pointEntityIds = new Int32Array(pointCount);
  const pointLabels: string[] = [];
  const pointPaths: (string | null)[] = [];
  const pointNames: (string | null)[] = [];
  const pointStartBytes = new Int32Array(pointCount).fill(-1);
  const pointEndBytes = new Int32Array(pointCount).fill(-1);
  const indexById = new Map<string, number>();

  let point = 0;
  const pushPoint = (
    domain: Domain,
    entityId: number,
    label: string,
    path: string | null,
    name: string | null,
    startByte: number,
    endByte: number,
  ): void => {
    const id = `${domain}:${entityId}`;
    pointIds.push(id);
    pointDomains[point] = domainRank(domain);
    pointEntityIds[point] = entityId;
    pointLabels.push(label);
    pointPaths.push(path);
    pointNames.push(name);
    pointStartBytes[point] = startByte;
    pointEndBytes[point] = endByte;
    indexById.set(id, point);
    point += 1;
  };

  for (const file of files) {
    pushPoint("file", file.entityId, file.path, file.path, null, -1, -1);
  }
  for (const symbol of symbols) {
    pushPoint(
      "symbol",
      symbol.entityId,
      symbol.name ?? symbol.path,
      symbol.path,
      symbol.name,
      symbol.startByte ?? -1,
      symbol.endByte ?? -1,
    );
  }
  for (let id = fileCount; id < fileCount + directoryCount; id++) {
    const exported = directoryPaths.get(id);
    const label =
      exported === undefined ? `directory #${id}` : exported === "" ? ROOT_DIRECTORY_LABEL : exported;
    pushPoint("location", id, label, exported ?? null, null, -1, -1);
  }

  const resolve = (domain: string, id: number): number | undefined => {
    switch (domain) {
      case "file":
        return id >= 0 && id < fileCount ? id : undefined;
      case "symbol":
        return id >= 0 && id < symbolCount ? fileCount + id : undefined;
      case "location":
        if (id >= 0 && id < fileCount) return id;
        if (id >= fileCount && id < fileCount + directoryCount)
          return fileCount + symbolCount + (id - fileCount);
        return undefined;
      default:
        return undefined;
    }
  };

  // Bucket rows by relation, preserving the row order of relations.parquet.
  const buckets = new Map<Relation, Array<{ row: number; data: RelationRow }>>();
  for (const relation of RELATION_ORDER) buckets.set(relation, []);
  for (const [row, data] of relations.entries()) {
    if (!isRelation(data.relation)) {
      throw new ProjectionError(invalidRelation(row, data));
    }
    const [sourceDomain, targetDomain] = endpointDomains(data.relation);
    if (data.sourceDomain !== sourceDomain || data.targetDomain !== targetDomain) {
      throw new ProjectionError(invalidRelation(row, data));
    }
    buckets.get(data.relation)?.push({ row, data });
  }

  const expectedCounts: Record<Relation, number> = {
    defines: metadata.definesCount,
    imports: metadata.importsCount,
    calls: metadata.callsCount,
    parent: metadata.parentCount,
  };
  const relationCounts: Record<Relation, number> = { defines: 0, imports: 0, calls: 0, parent: 0 };
  for (const relation of RELATION_ORDER) {
    const actual = buckets.get(relation)?.length ?? 0;
    const expected = expectedCounts[relation];
    if (actual !== expected) {
      throw new ProjectionError({ kind: "count-mismatch", what: relation, expected, actual });
    }
    relationCounts[relation] = actual;
  }

  let linkCount = 0;
  for (const relation of RELATION_ORDER) linkCount += relationCounts[relation];
  const linkRelations = new Uint8Array(linkCount);
  const linkRows = new Int32Array(linkCount);
  const linkSourceDomains = new Uint8Array(linkCount);
  const linkSourceIds = new Int32Array(linkCount);
  const linkTargetDomains = new Uint8Array(linkCount);
  const linkTargetIds = new Int32Array(linkCount);
  const linkSourceIndices = new Uint32Array(linkCount);
  const linkTargetIndices = new Uint32Array(linkCount);

  let link = 0;
  for (const relation of RELATION_ORDER) {
    for (const { row, data } of buckets.get(relation) ?? []) {
      const sourceIndex = resolve(data.sourceDomain, data.sourceId);
      if (sourceIndex === undefined) {
        throw new ProjectionError({
          kind: "unresolved-endpoint",
          relation,
          row,
          side: "source",
          domain: data.sourceDomain,
          id: data.sourceId,
        });
      }
      const targetIndex = resolve(data.targetDomain, data.targetId);
      if (targetIndex === undefined) {
        throw new ProjectionError({
          kind: "unresolved-endpoint",
          relation,
          row,
          side: "target",
          domain: data.targetDomain,
          id: data.targetId,
        });
      }
      // The endpoint domains were validated against the admission triple, so the
      // canonical domains of this relation are exactly the row's domains.
      const [sourceDomain, targetDomain] = endpointDomains(relation);
      linkRelations[link] = relationRank(relation);
      linkRows[link] = row;
      linkSourceDomains[link] = domainRank(sourceDomain);
      linkSourceIds[link] = data.sourceId;
      linkTargetDomains[link] = domainRank(targetDomain);
      linkTargetIds[link] = data.targetId;
      linkSourceIndices[link] = sourceIndex;
      linkTargetIndices[link] = targetIndex;
      link += 1;
    }
  }

  const linkOffsets: number[] = [0];
  for (const relation of RELATION_ORDER) {
    linkOffsets.push((linkOffsets[linkOffsets.length - 1] ?? 0) + relationCounts[relation]);
  }
  const adjacency: Record<Relation, RelationAdjacency> = {
    defines: buildAdjacency(
      pointCount,
      linkSourceIndices,
      linkTargetIndices,
      linkOffsets[0] ?? 0,
      linkOffsets[1] ?? 0,
    ),
    imports: buildAdjacency(
      pointCount,
      linkSourceIndices,
      linkTargetIndices,
      linkOffsets[1] ?? 0,
      linkOffsets[2] ?? 0,
    ),
    calls: buildAdjacency(
      pointCount,
      linkSourceIndices,
      linkTargetIndices,
      linkOffsets[2] ?? 0,
      linkOffsets[3] ?? 0,
    ),
    parent: buildAdjacency(
      pointCount,
      linkSourceIndices,
      linkTargetIndices,
      linkOffsets[3] ?? 0,
      linkOffsets[4] ?? 0,
    ),
  };

  return {
    provenance: {
      snapshotId,
      repository: metadata.repository,
      baseRevision: metadata.baseRevision,
      sourceTreeIdentity: metadata.sourceTreeIdentity,
      factIdentity: metadata.factIdentity,
      fileSha256,
    },
    fileCount,
    symbolCount,
    directoryCount,
    pointCount,
    linkCount,
    pointIds,
    pointDomains,
    pointEntityIds,
    pointLabels,
    pointPaths,
    pointNames,
    pointStartBytes,
    pointEndBytes,
    indexById,
    linkRelations,
    linkRows,
    linkSourceDomains,
    linkSourceIds,
    linkTargetDomains,
    linkTargetIds,
    linkSourceIndices,
    linkTargetIndices,
    relationCounts,
    adjacency,
  };
}

function invalidRelation(row: number, data: RelationRow): ProjectionError["detail"] {
  return {
    kind: "invalid-relation",
    row,
    relation: data.relation,
    sourceDomain: data.sourceDomain,
    targetDomain: data.targetDomain,
  };
}

function checkSnapshot(table: string, snapshotIds: readonly string[], expected: string): void {
  for (const [row, actual] of snapshotIds.entries()) {
    if (actual !== expected) {
      throw new ProjectionError({ kind: "snapshot-mismatch", table, row, expected, actual });
    }
  }
}

/**
 * Splits out one entity domain, checks its count against metadata, and returns
 * the rows sorted by ascending entity_id (which must be dense 0..n-1).
 */
function partitionEntities(
  entities: readonly EntityRow[],
  domain: "file" | "symbol",
  expectedCount: number,
): EntityRow[] {
  const rows: EntityRow[] = [];
  for (const row of entities) {
    if (row.domain !== "file" && row.domain !== "symbol") {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "entities",
        message: `unknown entity domain ${row.domain}`,
      });
    }
    if (row.domain === domain) rows.push(row);
  }
  if (rows.length !== expectedCount) {
    throw new ProjectionError({
      kind: "count-mismatch",
      what: `${domain} entities`,
      expected: expectedCount,
      actual: rows.length,
    });
  }
  rows.sort((a, b) => a.entityId - b.entityId);
  for (const [index, row] of rows.entries()) {
    if (row.entityId !== index) {
      throw new ProjectionError({
        kind: "count-mismatch",
        what: `dense ${domain} entity ids`,
        expected: index,
        actual: row.entityId,
      });
    }
  }
  return rows;
}

/** Validates the optional locations table; returns directory location_id -> path. */
function readDirectoryPaths(
  locations: readonly LocationRow[] | null,
  fileCount: number,
  directoryCount: number,
): Map<number, string> {
  const paths = new Map<number, string>();
  if (locations === null) return paths;
  for (const row of locations) {
    if (row.kind !== "file" && row.kind !== "directory") {
      throw new ProjectionError({
        kind: "invalid-locations",
        message: `unknown kind ${row.kind} for location ${row.locationId}`,
      });
    }
    const lo = row.kind === "file" ? 0 : fileCount;
    const hi = row.kind === "file" ? fileCount : fileCount + directoryCount;
    if (row.locationId < lo || row.locationId >= hi) {
      throw new ProjectionError({
        kind: "invalid-locations",
        message: `${row.kind} location ${row.locationId} is outside ${lo}..${hi - 1}`,
      });
    }
    if (paths.has(row.locationId)) {
      throw new ProjectionError({
        kind: "invalid-locations",
        message: `duplicate location ${row.locationId}`,
      });
    }
    paths.set(row.locationId, row.path);
  }
  const directories = new Map<number, string>();
  for (const [id, path] of paths) {
    if (id >= fileCount) directories.set(id, path);
  }
  return directories;
}

function buildAdjacency(
  pointCount: number,
  linkSourceIndices: Uint32Array,
  linkTargetIndices: Uint32Array,
  start: number,
  end: number,
): RelationAdjacency {
  const outDegree = new Uint32Array(pointCount);
  const inDegree = new Uint32Array(pointCount);
  for (let link = start; link < end; link++) {
    const source = linkSourceIndices[link];
    const target = linkTargetIndices[link];
    if (source === undefined || target === undefined) throw new Error(`link index out of range: ${link}`);
    outDegree[source] = (outDegree[source] ?? 0) + 1;
    inDegree[target] = (inDegree[target] ?? 0) + 1;
  }
  const out = allocateCsr(outDegree);
  const inbound = allocateCsr(inDegree);
  const outCursor = Uint32Array.from(out.offsets.slice(0, pointCount));
  const inCursor = Uint32Array.from(inbound.offsets.slice(0, pointCount));
  for (let link = start; link < end; link++) {
    const source = linkSourceIndices[link] ?? 0;
    const target = linkTargetIndices[link] ?? 0;
    const outSlot = outCursor[source] ?? 0;
    out.points[outSlot] = target;
    out.links[outSlot] = link;
    outCursor[source] = outSlot + 1;
    const inSlot = inCursor[target] ?? 0;
    inbound.points[inSlot] = source;
    inbound.links[inSlot] = link;
    inCursor[target] = inSlot + 1;
  }
  return { out, in: inbound };
}

function allocateCsr(degrees: Uint32Array): {
  offsets: Uint32Array;
  points: Uint32Array;
  links: Uint32Array;
} {
  const offsets = new Uint32Array(degrees.length + 1);
  for (const [i, degree] of degrees.entries()) {
    offsets[i + 1] = (offsets[i] ?? 0) + degree;
  }
  const total = offsets[degrees.length] ?? 0;
  return { offsets, points: new Uint32Array(total), links: new Uint32Array(total) };
}
