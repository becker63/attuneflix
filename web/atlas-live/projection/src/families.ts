/**
 * The web projection of a world's Atlas Families export (`atlas-families-v1`).
 *
 * This module decodes the five typed tables the Flix exporter ships under
 * `data/<digest>/` and projects them against the exact ViewerGraph. It never
 * derives science: membership, rollups, edges and multiplicities are read from
 * the shipped tables and only re-validated (the same laws the Flix side proves:
 * membership is exactly the world's symbols, every contribution is an exact
 * world edge, multiplicity is the count of contributing edges). Inconsistent
 * evidence is a typed ProjectionError, never a partial families layer.
 *
 * Honesty rules the viewer relies on (F3 findings, commit 33e8c22e):
 * - a member with `candidates === 0` joined its defining file's seed family via
 *   the recorded fallback (no frontier held it) — surfaced as `memberFallback`;
 * - a family with `members === 1` is a singleton — surfaced as `singleton`;
 * - a contribution row with a null family endpoint (a file that defines no
 *   callable) names no family edge — counted as `unattributed`, never invented.
 */
import { ProjectionError } from "./errors.ts";
import type { ViewerGraph } from "./graph.ts";
import type { FamiliesTableAssets } from "./manifest.ts";
import { integer, optionalInteger, readTable, text } from "./tables.ts";

/** The family edge relations: imports at file grain, calls at symbol grain. */
export type FamilyRelation = "imports" | "calls";

/**
 * The declared typed schema (format identity + exact column order) of every
 * families table. The owners are `Families.Cluster.Table` and
 * `Families.Edge.Table` in the Flix experiment; this is the single web mirror,
 * read by both the decoder here and the `:data` validation in
 * `projection/test/data_check.ts`. The parity law
 * `//experiments/atlas-families:families_export_parity_test` holds the shipped
 * bytes to the Flix-built tables.
 */
export const FAMILY_TABLE_SCHEMAS: Record<
  keyof FamiliesTableAssets,
  { format: string; columns: readonly string[] }
> = {
  families: {
    format: "attune-atlas-families-v1",
    columns: [
      "protocol",
      "snapshot_id",
      "family",
      "family_id",
      "name",
      "name_kind",
      "named",
      "seed",
      "name_decision",
      "seed_files",
      "route",
      "state_id",
      "members",
      "files",
    ],
  },
  members: {
    format: "attune-atlas-families-members-v1",
    columns: [
      "protocol",
      "snapshot_id",
      "family",
      "family_id",
      "domain",
      "entity_id",
      "path",
      "name",
      "start_byte",
      "end_byte",
      "candidates",
      "affinity",
      "structural_affinity",
      "semantic_affinity",
    ],
  },
  rollups: {
    format: "attune-atlas-families-rollups-v1",
    columns: [
      "protocol",
      "snapshot_id",
      "level",
      "location_id",
      "location",
      "family",
      "family_id",
      "members",
      "location_members",
      "dominant",
    ],
  },
  edges: {
    format: "attune-atlas-family-edges-v1",
    columns: [
      "protocol",
      "snapshot_id",
      "relation",
      "grain",
      "edge",
      "source_family",
      "source_family_id",
      "target_family",
      "target_family_id",
      "multiplicity",
    ],
  },
  contributions: {
    format: "attune-atlas-family-edge-contributions-v1",
    columns: [
      "protocol",
      "snapshot_id",
      "relation",
      "source_domain",
      "source_id",
      "target_domain",
      "target_id",
      "source_family",
      "target_family",
      "edge",
    ],
  },
};

/** The five families tables of one world, as Parquet bytes (browser fetch or Node read). */
export type FamiliesFiles = Record<keyof FamiliesTableAssets, ArrayBuffer>;

/** One family row the web consumes (`seed_files`/`route` lists stay undecoded). */
export interface FamilyRow {
  readonly snapshotId: string;
  readonly ordinal: number;
  readonly familyId: string;
  readonly name: string;
  readonly nameKind: string;
  readonly named: boolean;
  /** Entity id of the family's seed file. */
  readonly seedFile: number;
  readonly members: number;
  readonly files: number;
}

/** One member row: the exact admitted symbol row plus its assignment record. */
export interface FamilyMemberRow {
  readonly snapshotId: string;
  readonly family: number;
  readonly familyId: string;
  readonly entityId: number;
  readonly path: string;
  readonly name: string;
  readonly startByte: number;
  readonly endByte: number;
  /** How many recorded frontiers held the symbol; 0 is the seed fallback. */
  readonly candidates: number;
  readonly affinity: number;
  readonly structuralAffinity: number;
  readonly semanticAffinity: number;
}

/** One rollup row: a family's presence in one file or directory. */
export interface FamilyRollupRow {
  readonly snapshotId: string;
  readonly level: "file" | "directory";
  readonly locationId: number;
  readonly location: string;
  readonly family: number;
  readonly familyId: string;
  readonly members: number;
  readonly locationMembers: number;
  readonly dominant: boolean;
}

/** One family edge: relation, endpoints (family ordinals), multiplicity. */
export interface FamilyEdgeRow {
  readonly snapshotId: string;
  readonly relation: FamilyRelation;
  readonly grain: string;
  readonly edge: number;
  readonly sourceFamily: number;
  readonly sourceFamilyId: string;
  readonly targetFamily: number;
  readonly targetFamilyId: string;
  readonly multiplicity: number;
}

/** One contribution row: an exact world edge and the family edge it feeds (nullable). */
export interface FamilyContributionRow {
  readonly snapshotId: string;
  readonly relation: FamilyRelation;
  readonly sourceDomain: string;
  readonly sourceId: number;
  readonly targetDomain: string;
  readonly targetId: number;
  readonly sourceFamily: number | null;
  readonly targetFamily: number | null;
  readonly edge: number | null;
}

export interface FamilyTables {
  readonly families: readonly FamilyRow[];
  readonly members: readonly FamilyMemberRow[];
  readonly rollups: readonly FamilyRollupRow[];
  readonly edges: readonly FamilyEdgeRow[];
  readonly contributions: readonly FamilyContributionRow[];
}

/** One family of a world, ready for the viewer. */
export interface WorldFamily {
  readonly ordinal: number;
  readonly familyId: string;
  readonly name: string;
  readonly named: boolean;
  readonly seedFile: number;
  readonly members: number;
  readonly files: number;
  readonly singleton: boolean;
  /** Point index of the family's seed file (file points are entity-id ordered). */
  readonly anchor: number;
}

/** One family edge, resolved against the viewer graph. */
export interface FamilyEdge {
  /** Ordinal in the family edges table. */
  readonly edge: number;
  readonly relation: FamilyRelation;
  readonly sourceFamily: number;
  readonly targetFamily: number;
  readonly multiplicity: number;
  /** False for intra-family edges (kept in data, never drawn as a canvas link). */
  readonly crossFamily: boolean;
  /** Point indices of the two families' seed-file anchors. */
  readonly sourceAnchor: number;
  readonly targetAnchor: number;
}

/** A world's families layer, projected and validated against its exact graph. */
export interface WorldFamilies {
  readonly snapshotId: string;
  readonly fileCount: number;
  readonly symbolCount: number;
  readonly directoryCount: number;
  readonly families: readonly WorldFamily[];
  readonly familyCount: number;
  /** Families with exactly one member. */
  readonly singletonCount: number;
  /** Members no recorded frontier held (candidates == 0, the seed fallback). */
  readonly fallbackCount: number;
  /** Symbol ordinal -> family ordinal (every symbol has exactly one). */
  readonly symbolFamily: Int32Array;
  /** Symbol ordinal -> 1 when the membership is the seed fallback. */
  readonly memberFallback: Uint8Array;
  /** Symbol ordinal -> recorded frontier candidate count. */
  readonly memberCandidates: Int32Array;
  /** File index -> dominant family ordinal, -1 when the file holds no member. */
  readonly fileDominant: Int32Array;
  /** File index -> total family members the file holds. */
  readonly fileMembers: Int32Array;
  /** Directory ordinal -> dominant family ordinal, -1 when it holds no member. */
  readonly directoryDominant: Int32Array;
  /** Directory ordinal -> total family members the directory holds. */
  readonly directoryMembers: Int32Array;
  /** Every family edge, in table order (intra-family included). */
  readonly edges: readonly FamilyEdge[];
  /** Cross-family edge ordinals, in table order (the rendered family links). */
  readonly renderedEdges: readonly number[];
  /** Exact link index of every contribution row, in table row order. */
  readonly contributionLinks: Int32Array;
  /** Family edge ordinal -> exact link indices of its contributing world edges. */
  readonly edgeContributionLinks: ReadonlyMap<number, readonly number[]>;
  /** Contribution rows that name no family edge (endpoints without callables). */
  readonly unattributed: number;
}

/**
 * The family of a point: a symbol's own family, a file's or directory's
 * dominant rollup family, or -1 when the point carries no family.
 */
export function familyOfPoint(families: WorldFamilies, index: number): number {
  if (index < 0 || index >= families.fileCount + families.symbolCount + families.directoryCount) return -1;
  if (index < families.fileCount) return families.fileDominant[index] ?? -1;
  if (index < families.fileCount + families.symbolCount) {
    return families.symbolFamily[index - families.fileCount] ?? -1;
  }
  return families.directoryDominant[index - families.fileCount - families.symbolCount] ?? -1;
}

function booleanCell(row: Record<string, unknown>, table: string, column: string): boolean {
  const value = row[column];
  if (typeof value !== "boolean") {
    throw new ProjectionError({
      kind: "invalid-schema",
      table,
      message: `column ${column} is not a boolean`,
    });
  }
  return value;
}

function floatCell(row: Record<string, unknown>, table: string, column: string): number {
  const value = row[column];
  const asNumber = typeof value === "bigint" ? Number(value) : value;
  if (typeof asNumber !== "number") {
    throw new ProjectionError({
      kind: "invalid-schema",
      table,
      message: `column ${column} is not a float`,
    });
  }
  return asNumber;
}

function familyRelation(row: Record<string, unknown>, table: string): FamilyRelation {
  const relation = text(row, table, "relation");
  if (relation !== "imports" && relation !== "calls") {
    throw new ProjectionError({
      kind: "invalid-schema",
      table,
      message: `unknown family edge relation ${relation}`,
    });
  }
  return relation;
}

async function decodeTable(
  file: ArrayBuffer,
  table: keyof FamiliesTableAssets,
): Promise<Record<string, unknown>[]> {
  const { format, columns } = FAMILY_TABLE_SCHEMAS[table];
  const rows = await readTable(file, table, columns);
  for (const [index, row] of rows.entries()) {
    if (row["protocol"] !== format) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table,
        message: `row ${index} carries protocol ${String(row["protocol"])}, expected ${format}`,
      });
    }
  }
  return rows;
}

/** Decodes the five families tables, checking each table's declared schema. */
export async function decodeFamiliesFiles(files: FamiliesFiles): Promise<FamilyTables> {
  const [families, members, rollups, edges, contributions] = await Promise.all([
    decodeTable(files.families, "families"),
    decodeTable(files.members, "members"),
    decodeTable(files.rollups, "rollups"),
    decodeTable(files.edges, "edges"),
    decodeTable(files.contributions, "contributions"),
  ]);
  return {
    families: families.map((row) => ({
      snapshotId: text(row, "families", "snapshot_id"),
      ordinal: integer(row, "families", "family"),
      familyId: text(row, "families", "family_id"),
      name: text(row, "families", "name"),
      nameKind: text(row, "families", "name_kind"),
      named: booleanCell(row, "families", "named"),
      seedFile: integer(row, "families", "seed"),
      members: integer(row, "families", "members"),
      files: integer(row, "families", "files"),
    })),
    members: members.map((row) => ({
      snapshotId: text(row, "members", "snapshot_id"),
      family: integer(row, "members", "family"),
      familyId: text(row, "members", "family_id"),
      entityId: integer(row, "members", "entity_id"),
      path: text(row, "members", "path"),
      name: text(row, "members", "name"),
      startByte: integer(row, "members", "start_byte"),
      endByte: integer(row, "members", "end_byte"),
      candidates: integer(row, "members", "candidates"),
      affinity: floatCell(row, "members", "affinity"),
      structuralAffinity: floatCell(row, "members", "structural_affinity"),
      semanticAffinity: floatCell(row, "members", "semantic_affinity"),
    })),
    rollups: rollups.map((row) => {
      const level = text(row, "rollups", "level");
      if (level !== "file" && level !== "directory") {
        throw new ProjectionError({
          kind: "invalid-schema",
          table: "rollups",
          message: `unknown rollup level ${level}`,
        });
      }
      return {
        snapshotId: text(row, "rollups", "snapshot_id"),
        level,
        locationId: integer(row, "rollups", "location_id"),
        location: text(row, "rollups", "location"),
        family: integer(row, "rollups", "family"),
        familyId: text(row, "rollups", "family_id"),
        members: integer(row, "rollups", "members"),
        locationMembers: integer(row, "rollups", "location_members"),
        dominant: booleanCell(row, "rollups", "dominant"),
      };
    }),
    edges: edges.map((row) => ({
      snapshotId: text(row, "edges", "snapshot_id"),
      relation: familyRelation(row, "edges"),
      grain: text(row, "edges", "grain"),
      edge: integer(row, "edges", "edge"),
      sourceFamily: integer(row, "edges", "source_family"),
      sourceFamilyId: text(row, "edges", "source_family_id"),
      targetFamily: integer(row, "edges", "target_family"),
      targetFamilyId: text(row, "edges", "target_family_id"),
      multiplicity: integer(row, "edges", "multiplicity"),
    })),
    contributions: contributions.map((row) => ({
      snapshotId: text(row, "contributions", "snapshot_id"),
      relation: familyRelation(row, "contributions"),
      sourceDomain: text(row, "contributions", "source_domain"),
      sourceId: integer(row, "contributions", "source_id"),
      targetDomain: text(row, "contributions", "target_domain"),
      targetId: integer(row, "contributions", "target_id"),
      sourceFamily: optionalInteger(row, "contributions", "source_family"),
      targetFamily: optionalInteger(row, "contributions", "target_family"),
      edge: optionalInteger(row, "contributions", "edge"),
    })),
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
 * Projects a world's families export against its exact ViewerGraph. Every law
 * the Flix side proves is re-validated here; a violation is a typed error and
 * the world loads without a families layer only by the caller's choice (the
 * export route keeps tables and world in lockstep, so this never fires in
 * practice).
 */
export function projectFamilies(tables: FamilyTables, graph: ViewerGraph): WorldFamilies {
  const snapshotId = graph.provenance.snapshotId;
  checkSnapshot(
    "families",
    tables.families.map((row) => row.snapshotId),
    snapshotId,
  );
  checkSnapshot(
    "members",
    tables.members.map((row) => row.snapshotId),
    snapshotId,
  );
  checkSnapshot(
    "rollups",
    tables.rollups.map((row) => row.snapshotId),
    snapshotId,
  );
  checkSnapshot(
    "edges",
    tables.edges.map((row) => row.snapshotId),
    snapshotId,
  );
  checkSnapshot(
    "contributions",
    tables.contributions.map((row) => row.snapshotId),
    snapshotId,
  );

  const { fileCount, symbolCount, directoryCount } = graph;

  // Families: contiguous ordinals from zero, valid seed files.
  if (tables.families.length === 0) {
    throw new ProjectionError({ kind: "invalid-schema", table: "families", message: "no families" });
  }
  const families: WorldFamily[] = [];
  for (const [ordinal, row] of tables.families.entries()) {
    if (row.ordinal !== ordinal) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "families",
        message: `family ordinals must be contiguous from zero (row ${ordinal} carries ${row.ordinal})`,
      });
    }
    if (row.seedFile < 0 || row.seedFile >= fileCount) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "families",
        message: `family ${ordinal} seed file ${row.seedFile} is outside 0..${fileCount - 1}`,
      });
    }
    families.push({
      ordinal,
      familyId: row.familyId,
      name: row.name,
      named: row.named,
      seedFile: row.seedFile,
      members: row.members,
      files: row.files,
      singleton: row.members === 1,
      anchor: row.seedFile,
    });
  }
  const familyCount = families.length;

  // Members: exactly the world's symbols, each once, each an exact entity row.
  if (tables.members.length !== symbolCount) {
    throw new ProjectionError({
      kind: "count-mismatch",
      what: "family members == symbols",
      expected: symbolCount,
      actual: tables.members.length,
    });
  }
  const symbolFamily = new Int32Array(symbolCount).fill(-1);
  const memberFallback = new Uint8Array(symbolCount);
  const memberCandidates = new Int32Array(symbolCount);
  let fallbackCount = 0;
  for (const [row, member] of tables.members.entries()) {
    if (member.entityId < 0 || member.entityId >= symbolCount) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "members",
        message: `row ${row} entity ${member.entityId} is outside 0..${symbolCount - 1}`,
      });
    }
    if (symbolFamily[member.entityId] !== -1) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "members",
        message: `symbol ${member.entityId} appears twice`,
      });
    }
    if (member.family < 0 || member.family >= familyCount) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "members",
        message: `row ${row} names unknown family ${member.family}`,
      });
    }
    // The member row is the exact admitted symbol row: path and span agree.
    const point = fileCount + member.entityId;
    if (graph.pointPaths[point] !== member.path) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "members",
        message: `row ${row} path ${member.path} is not symbol ${member.entityId}'s path`,
      });
    }
    symbolFamily[member.entityId] = member.family;
    memberCandidates[member.entityId] = member.candidates;
    if (member.candidates === 0) {
      memberFallback[member.entityId] = 1;
      fallbackCount += 1;
    }
  }

  // Rollups: one dominant family per file/directory that holds members.
  const fileDominant = new Int32Array(fileCount).fill(-1);
  const fileMembers = new Int32Array(fileCount);
  const directoryDominant = new Int32Array(directoryCount).fill(-1);
  const directoryMembers = new Int32Array(directoryCount);
  for (const [row, rollup] of tables.rollups.entries()) {
    if (rollup.family < 0 || rollup.family >= familyCount) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "rollups",
        message: `row ${row} names unknown family ${rollup.family}`,
      });
    }
    if (rollup.level === "file") {
      if (rollup.locationId < 0 || rollup.locationId >= fileCount) {
        throw new ProjectionError({
          kind: "invalid-schema",
          table: "rollups",
          message: `row ${row} file ${rollup.locationId} is outside 0..${fileCount - 1}`,
        });
      }
      if (rollup.dominant && fileDominant[rollup.locationId] === -1) {
        fileDominant[rollup.locationId] = rollup.family;
        fileMembers[rollup.locationId] = rollup.locationMembers;
      }
    } else {
      const ordinal = rollup.locationId - fileCount;
      if (ordinal < 0 || ordinal >= directoryCount) {
        throw new ProjectionError({
          kind: "invalid-schema",
          table: "rollups",
          message: `row ${row} directory location ${rollup.locationId} is outside ${fileCount}..${fileCount + directoryCount - 1}`,
        });
      }
      if (rollup.dominant && directoryDominant[ordinal] === -1) {
        directoryDominant[ordinal] = rollup.family;
        directoryMembers[ordinal] = rollup.locationMembers;
      }
    }
  }

  // Edges: contiguous ordinals, valid families.
  const edges: FamilyEdge[] = [];
  const renderedEdges: number[] = [];
  for (const [ordinal, row] of tables.edges.entries()) {
    if (row.edge !== ordinal) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "edges",
        message: `edge ordinals must be contiguous from zero (row ${ordinal} carries ${row.edge})`,
      });
    }
    for (const [side, family] of [
      ["source", row.sourceFamily],
      ["target", row.targetFamily],
    ] as const) {
      if (family < 0 || family >= familyCount) {
        throw new ProjectionError({
          kind: "invalid-schema",
          table: "edges",
          message: `edge ${ordinal} ${side} family ${family} is unknown`,
        });
      }
    }
    const sourceAnchor = families[row.sourceFamily]?.anchor ?? 0;
    const targetAnchor = families[row.targetFamily]?.anchor ?? 0;
    const crossFamily = row.sourceFamily !== row.targetFamily;
    edges.push({
      edge: ordinal,
      relation: row.relation,
      sourceFamily: row.sourceFamily,
      targetFamily: row.targetFamily,
      multiplicity: row.multiplicity,
      crossFamily,
      sourceAnchor,
      targetAnchor,
    });
    if (crossFamily) renderedEdges.push(ordinal);
  }

  // Contributions: one row per exact imports/calls edge, in per-relation order;
  // the k-th contribution of a relation is the k-th exact link of that relation.
  if (tables.contributions.length !== graph.relationCounts.imports + graph.relationCounts.calls) {
    throw new ProjectionError({
      kind: "count-mismatch",
      what: "family contributions == imports + calls",
      expected: graph.relationCounts.imports + graph.relationCounts.calls,
      actual: tables.contributions.length,
    });
  }
  const linkBuckets: Record<FamilyRelation, number[]> = { imports: [], calls: [] };
  for (let link = 0; link < graph.linkCount; link++) {
    const rank = graph.linkRelations[link];
    const relation = rank === 1 ? "imports" : rank === 2 ? "calls" : null;
    if (relation !== null) linkBuckets[relation].push(link);
  }
  const bucketCursor: Record<FamilyRelation, number> = { imports: 0, calls: 0 };
  const contributionLinks = new Int32Array(tables.contributions.length);
  const edgeLinks = new Map<number, number[]>();
  let unattributed = 0;
  for (const [row, contribution] of tables.contributions.entries()) {
    const bucket = linkBuckets[contribution.relation];
    const position = bucketCursor[contribution.relation];
    bucketCursor[contribution.relation] = position + 1;
    const link = bucket[position];
    if (link === undefined) {
      throw new ProjectionError({
        kind: "count-mismatch",
        what: `family contributions of relation ${contribution.relation}`,
        expected: bucket.length,
        actual: position + 1,
      });
    }
    // The contribution row is the exact world edge: endpoints must agree.
    if (
      graph.linkSourceIds[link] !== contribution.sourceId ||
      graph.linkTargetIds[link] !== contribution.targetId
    ) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "contributions",
        message:
          `row ${row} (${contribution.relation} ${contribution.sourceId} -> ${contribution.targetId}) ` +
          `is not exact link ${link}`,
      });
    }
    contributionLinks[row] = link;
    if (contribution.edge === null) {
      // An unattributed exact edge: an endpoint defines no callable, so no
      // family edge may be named for it.
      if (contribution.sourceFamily !== null && contribution.targetFamily !== null) {
        throw new ProjectionError({
          kind: "invalid-schema",
          table: "contributions",
          message: `row ${row} names no edge but carries two families`,
        });
      }
      unattributed += 1;
      continue;
    }
    const edge = edges[contribution.edge];
    if (edge === undefined) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "contributions",
        message: `row ${row} names unknown edge ${contribution.edge}`,
      });
    }
    if (
      edge.relation !== contribution.relation ||
      contribution.sourceFamily !== edge.sourceFamily ||
      contribution.targetFamily !== edge.targetFamily
    ) {
      throw new ProjectionError({
        kind: "invalid-schema",
        table: "contributions",
        message: `row ${row} does not carry its edge ${contribution.edge}'s relation and families`,
      });
    }
    const list = edgeLinks.get(contribution.edge) ?? [];
    list.push(link);
    edgeLinks.set(contribution.edge, list);
  }

  // Edge no-invention: multiplicity is exactly the count of contributing links.
  for (const edge of edges) {
    const contributing = edgeLinks.get(edge.edge)?.length ?? 0;
    if (contributing !== edge.multiplicity) {
      throw new ProjectionError({
        kind: "count-mismatch",
        what: `family edge ${edge.edge} multiplicity`,
        expected: edge.multiplicity,
        actual: contributing,
      });
    }
  }

  return {
    snapshotId,
    fileCount,
    symbolCount,
    directoryCount,
    families,
    familyCount,
    singletonCount: families.filter((family) => family.singleton).length,
    fallbackCount,
    symbolFamily,
    memberFallback,
    memberCandidates,
    fileDominant,
    fileMembers,
    directoryDominant,
    directoryMembers,
    edges,
    renderedEdges,
    contributionLinks,
    edgeContributionLinks: edgeLinks,
    unattributed,
  };
}
