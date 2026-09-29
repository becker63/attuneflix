/**
 * The web projection of the Atlas Families export (VAL-WEB-001..004 data layer).
 * The staged preact export (//web/atlas-live/projection:layout_worlds, the same
 * bytes `families_export_parity_test` holds to the Flix-built tables) is decoded
 * and projected against the exact ViewerGraph: membership coverage, the F3
 * findings (166 seed-fallback members, 29 singleton families), edge multiplicity
 * and no-invention, contribution-to-exact-link parity, and honest rollups.
 */
import path from "node:path";

import { describe, expect, it } from "vitest";

import {
  decodeFamiliesFiles,
  familyOfPoint,
  projectFamilies,
  summarizeFamilyTable,
  type FamilyTables,
} from "../src/families.ts";
import { buildViewerArrow } from "../src/arrow.ts";
import { projectWorld } from "../src/project.ts";
import type { ViewerGraph } from "../src/graph.ts";
import { readFamiliesDir, readWorldDir } from "../src/world_dir.ts";

const PREACT = "6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9";
const WORLD_DIR = path.join("layout_worlds", PREACT);

/** The recorded F3 findings over the preact clustering (commit 33e8c22e). */
const EXPECTED_FAMILIES = 159;
const EXPECTED_SINGLETONS = 29;
const EXPECTED_FALLBACK = 166;
const EXPECTED_UNATTRIBUTED = 36;

async function loadPreact(): Promise<{ graph: ViewerGraph; tables: FamilyTables }> {
  const graph = await projectWorld(await readWorldDir(WORLD_DIR));
  const tables = await decodeFamiliesFiles(await readFamiliesDir(WORLD_DIR));
  return { graph, tables };
}

describe("families export decode (preact)", () => {
  it("summarizes the typed families table for a census comparison", async () => {
    const graph = await projectWorld(await readWorldDir(WORLD_DIR));
    const files = await readFamiliesDir(WORLD_DIR);
    expect(await summarizeFamilyTable(files.families, graph)).toEqual({
      count: 159,
      largestMembers: 120,
      largestShare: 120 / graph.symbolCount,
    });
  });
  it("decodes the five typed tables with their declared row counts", async () => {
    const { graph, tables } = await loadPreact();
    expect(tables.families.length).toBe(EXPECTED_FAMILIES);
    expect(tables.members.length).toBe(graph.symbolCount);
    expect(tables.contributions.length).toBe(graph.relationCounts.imports + graph.relationCounts.calls);
    expect(tables.edges.length).toBeGreaterThan(0);
    expect(tables.rollups.length).toBeGreaterThan(0);
  });

  it("carries the world's snapshot id on every row of every table", async () => {
    const { tables } = await loadPreact();
    for (const row of tables.families) expect(row.ordinal).toBeGreaterThanOrEqual(0);
    for (const row of tables.members) expect(row.entityId).toBeGreaterThanOrEqual(0);
    for (const row of tables.edges) expect(row.edge).toBeGreaterThanOrEqual(0);
  });
});

describe("families projection over the exact ViewerGraph", () => {
  it("covers every symbol exactly once, as itself (no invention)", async () => {
    const { graph, tables } = await loadPreact();
    const families = projectFamilies(tables, graph);
    expect(families.familyCount).toBe(EXPECTED_FAMILIES);
    expect(families.symbolFamily.length).toBe(graph.symbolCount);
    const seen = new Set<number>();
    for (const member of tables.members) {
      expect(seen.has(member.entityId)).toBe(false);
      seen.add(member.entityId);
      // The member row is the exact admitted symbol row.
      const point = graph.fileCount + member.entityId;
      expect(graph.pointIds[point]).toBe(`symbol:${member.entityId}`);
      expect(graph.pointPaths[point]).toBe(member.path);
      expect(graph.pointNames[point]).toBe(member.name);
      expect(families.symbolFamily[member.entityId]).toBe(member.family);
      expect(member.family).toBeGreaterThanOrEqual(0);
      expect(member.family).toBeLessThan(families.familyCount);
    }
    expect(seen.size).toBe(graph.symbolCount);
  });

  it("pins the F3 findings: 166 seed-fallback members and 29 singleton families", async () => {
    const { graph, tables } = await loadPreact();
    const families = projectFamilies(tables, graph);
    expect(families.fallbackCount).toBe(EXPECTED_FALLBACK);
    expect(families.singletonCount).toBe(EXPECTED_SINGLETONS);
    let fallback = 0;
    for (const [symbol, family] of families.symbolFamily.entries()) {
      if (families.memberFallback[symbol] === 1) {
        fallback += 1;
        expect(families.memberCandidates[symbol]).toBe(0);
        expect(family).toBeGreaterThanOrEqual(0);
      }
    }
    expect(fallback).toBe(EXPECTED_FALLBACK);
    const singletons = families.families.filter((family) => family.singleton);
    expect(singletons.length).toBe(EXPECTED_SINGLETONS);
    for (const family of singletons) expect(family.members).toBe(1);
  });

  it("anchors every family at its seed file's point", async () => {
    const { graph, tables } = await loadPreact();
    const families = projectFamilies(tables, graph);
    for (const family of families.families) {
      expect(family.anchor).toBe(family.seedFile);
      expect(family.anchor).toBeLessThan(graph.fileCount);
      expect(graph.pointIds[family.anchor]).toBe(`file:${family.seedFile}`);
      expect(family.familyId.length).toBeGreaterThan(0);
      expect(family.name.length).toBeGreaterThan(0);
    }
  });

  it("maps every contribution row to its exact world link, endpoints equal", async () => {
    const { graph, tables } = await loadPreact();
    const families = projectFamilies(tables, graph);
    // Group the graph's exact links by relation, in canonical link order.
    const linksByRelation = new Map<string, number[]>();
    for (let link = 0; link < graph.linkCount; link++) {
      const rank = graph.linkRelations[link];
      // RELATION_ORDER: defines 0, imports 1, calls 2, parent 3.
      const key = rank === 1 ? "imports" : rank === 2 ? "calls" : "other";
      if (key === "other") continue;
      const list = linksByRelation.get(key) ?? [];
      list.push(link);
      linksByRelation.set(key, list);
    }
    const cursor = new Map<string, number>();
    let attributed = 0;
    for (const [row, contribution] of tables.contributions.entries()) {
      const links = linksByRelation.get(contribution.relation);
      if (links === undefined) throw new Error(`unexpected relation ${contribution.relation}`);
      const position = cursor.get(contribution.relation) ?? 0;
      cursor.set(contribution.relation, position + 1);
      const link = links[position];
      if (link === undefined) throw new Error(`no exact link for contribution ${row}`);
      expect(families.contributionLinks[row]).toBe(link);
      // The contribution row is the exact world edge: same relation, same endpoints.
      expect(graph.linkSourceIds[link]).toBe(contribution.sourceId);
      expect(graph.linkTargetIds[link]).toBe(contribution.targetId);
      if (contribution.edge === null) {
        expect(contribution.sourceFamily === null || contribution.targetFamily === null).toBe(true);
      } else {
        attributed += 1;
        const edge = families.edges[contribution.edge];
        expect(edge).toBeDefined();
        expect(edge?.relation).toBe(contribution.relation);
      }
    }
    expect(attributed).toBe(tables.contributions.length - EXPECTED_UNATTRIBUTED);
    expect(families.unattributed).toBe(EXPECTED_UNATTRIBUTED);
  });

  it("satisfies the edge no-invention law: multiplicity == contributing exact links", async () => {
    const { graph, tables } = await loadPreact();
    const families = projectFamilies(tables, graph);
    let total = 0;
    for (const edge of families.edges) {
      const links = families.edgeContributionLinks.get(edge.edge);
      expect(links).toBeDefined();
      expect(links?.length).toBe(edge.multiplicity);
      expect(edge.sourceFamily).toBeGreaterThanOrEqual(0);
      expect(edge.sourceFamily).toBeLessThan(families.familyCount);
      expect(edge.targetFamily).toBeGreaterThanOrEqual(0);
      expect(edge.targetFamily).toBeLessThan(families.familyCount);
      expect(edge.crossFamily).toBe(edge.sourceFamily !== edge.targetFamily);
      for (const link of links ?? []) {
        expect(link).toBeLessThan(graph.linkCount);
      }
      total += edge.multiplicity;
    }
    expect(total).toBe(tables.contributions.length - EXPECTED_UNATTRIBUTED);
    // Cross-family edges are the rendered ones; intra-family edges exist in data.
    expect(families.renderedEdges.length).toBe(families.edges.filter((edge) => edge.crossFamily).length);
    expect(families.renderedEdges.length).toBeGreaterThan(0);
  });

  it("tints files and directories by their dominant rollup family, honestly", async () => {
    const { graph, tables } = await loadPreact();
    const families = projectFamilies(tables, graph);
    expect(families.fileDominant.length).toBe(graph.fileCount);
    expect(families.directoryDominant.length).toBe(graph.directoryCount);
    // A file with family members has a dominant family whose members count is the
    // largest in that file; a file without members has none.
    const membersByFile = new Map<number, Map<number, number>>();
    for (const row of tables.rollups) {
      if (row.level !== "file") continue;
      const file = row.locationId;
      const byFamily = membersByFile.get(file) ?? new Map<number, number>();
      byFamily.set(row.family, row.members);
      membersByFile.set(file, byFamily);
      if (row.dominant) {
        expect(families.fileDominant[file]).toBe(row.family);
        expect(families.fileMembers[file]).toBe(row.locationMembers);
      }
    }
    for (const [file, byFamily] of membersByFile) {
      const dominant = families.fileDominant[file] ?? -1;
      expect(dominant).toBeGreaterThanOrEqual(0);
      const best = Math.max(...byFamily.values());
      expect(byFamily.get(dominant)).toBe(best);
    }
    let directoriesWithDominant = 0;
    for (let ordinal = 0; ordinal < graph.directoryCount; ordinal++) {
      if ((families.directoryDominant[ordinal] ?? -1) >= 0) directoriesWithDominant += 1;
    }
    expect(directoriesWithDominant).toBeGreaterThan(0);
  });

  it("is deterministic: two projections of the same bytes are identical", async () => {
    const { graph, tables } = await loadPreact();
    const a = projectFamilies(tables, graph);
    const b = projectFamilies(tables, graph);
    expect(Array.from(a.symbolFamily)).toEqual(Array.from(b.symbolFamily));
    expect(Array.from(a.memberFallback)).toEqual(Array.from(b.memberFallback));
    expect(Array.from(a.fileDominant)).toEqual(Array.from(b.fileDominant));
    expect(a.edges).toEqual(b.edges);
    expect(Array.from(a.contributionLinks)).toEqual(Array.from(b.contributionLinks));
  });

  it("resolves the family of any point by domain", async () => {
    const { graph, tables } = await loadPreact();
    const families = projectFamilies(tables, graph);
    // A symbol resolves to its own family.
    const member = tables.members[0];
    if (member === undefined) throw new Error("no members");
    expect(familyOfPoint(families, graph.fileCount + member.entityId)).toBe(member.family);
    // A file resolves to its dominant family (or -1 when it defines no member).
    for (let file = 0; file < graph.fileCount; file++) {
      expect(familyOfPoint(families, file)).toBe(families.fileDominant[file]);
    }
    // A directory resolves to its dominant family (or -1).
    for (let ordinal = 0; ordinal < graph.directoryCount; ordinal++) {
      expect(familyOfPoint(families, graph.fileCount + graph.symbolCount + ordinal)).toBe(
        families.directoryDominant[ordinal],
      );
    }
  });

  it("rejects a membership that is not the world's symbols", async () => {
    const { graph, tables } = await loadPreact();
    const truncated: FamilyTables = { ...tables, members: tables.members.slice(1) };
    expect(() => projectFamilies(truncated, graph)).toThrowError(/members/);
    const outOfRange: FamilyTables = {
      ...tables,
      members: tables.members.map((row, i) => (i === 0 ? { ...row, entityId: graph.symbolCount + 5 } : row)),
    };
    expect(() => projectFamilies(outOfRange, graph)).toThrowError(/entity/);
  });
});

describe("Arrow tables with families", () => {
  it("appends the cross-family edges as link rows after the exact links", async () => {
    const { graph, tables } = await loadPreact();
    const families = projectFamilies(tables, graph);
    const { links } = buildViewerArrow(graph, { families });
    expect(links.numRows).toBe(graph.linkCount + families.renderedEdges.length);

    // The exact prefix is untouched.
    const relation = links.getChild("relation");
    const sourceIndex = links.getChild("sourceIndex");
    const targetIndex = links.getChild("targetIndex");
    const row = links.getChild("row");
    for (let link = 0; link < graph.linkCount; link++) {
      expect(sourceIndex?.get(link)).toBe(graph.linkSourceIndices[link]);
      expect(targetIndex?.get(link)).toBe(graph.linkTargetIndices[link]);
      expect(row?.get(link)).toBe(graph.linkRows[link]);
    }

    // Each appended row is one rendered family edge between the two anchors.
    const index = links.getChild("index");
    const source = links.getChild("source");
    const target = links.getChild("target");
    const sourceDomain = links.getChild("sourceDomain");
    const sourceId = links.getChild("sourceId");
    for (const [k, edgeOrdinal] of families.renderedEdges.entries()) {
      const edge = families.edges[edgeOrdinal];
      if (edge === undefined) throw new Error(`no edge ${edgeOrdinal}`);
      const at = graph.linkCount + k;
      expect(index?.get(at)).toBe(at);
      expect(relation?.get(at)).toBe(edge.relation);
      expect(row?.get(at)).toBe(-1);
      expect(sourceIndex?.get(at)).toBe(edge.sourceAnchor);
      expect(targetIndex?.get(at)).toBe(edge.targetAnchor);
      expect(source?.get(at)).toBe(`file:${families.families[edge.sourceFamily]?.seedFile ?? -1}`);
      expect(target?.get(at)).toBe(`file:${families.families[edge.targetFamily]?.seedFile ?? -1}`);
      expect(sourceDomain?.get(at)).toBe("file");
      expect(sourceId?.get(at)).toBe(families.families[edge.sourceFamily]?.seedFile);
    }
  });

  it("builds the exact links table unchanged when no families are supplied", async () => {
    const { graph } = await loadPreact();
    const { links } = buildViewerArrow(graph);
    expect(links.numRows).toBe(graph.linkCount);
  });
});
