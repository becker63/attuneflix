/**
 * The families view layer (VAL-WEB-001..004 app side): deterministic family
 * tints, the family-edge listing and drill-down model, and the families-aware
 * link accessors. Exercises a hand-built two-family fixture (mirroring
 * graphFixture.ts) and the real preact export staged by
 * //web/atlas-live/projection:layout_worlds.
 */
import path from "node:path";

import { describe, expect, it } from "vitest";

import { buildViewerArrow } from "../../projection/src/arrow.ts";
import {
  decodeFamiliesFiles,
  familyOfPoint,
  projectFamilies,
  type FamilyTables,
  type WorldFamilies,
} from "../../projection/src/families.ts";
import type { ViewerGraph } from "../../projection/src/graph.ts";
import { projectWorld } from "../../projection/src/project.ts";
import { readFamiliesDir, readWorldDir } from "../../projection/src/world_dir.ts";
import { contributionLines, drillFamilyEdge, familyTint, topFamilyEdges } from "../src/families.ts";
import { linkColorAccessor, linkWidthAccessor } from "../src/linkAccessors.ts";
import { ALL_RELATIONS_MASK, relationMask } from "../src/selection.ts";
import { NO_FAMILY_COLOR, familyColor } from "../src/vocabulary.ts";
import { FIXTURE_SNAPSHOT_ID, fixtureGraph } from "./graphFixture.ts";

const PREACT = "6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9";
const PREACT_DIR = path.join("../projection/layout_worlds", PREACT);

/** One fixture family row (module scope: it captures nothing). */
const fixtureFamilyRow = (ordinal: number, seed: number, name: string) => ({
  snapshotId: FIXTURE_SNAPSHOT_ID,
  ordinal,
  familyId: `atlas-family-v1:${name}`,
  name,
  nameKind: "jev",
  named: true,
  seedFile: seed,
  members: 1,
  files: 1,
});

/**
 * Two families over the fixture graph: family 0 owns symbol 0 (frontier
 * membership), family 1 owns symbol 1 via the seed fallback (candidates 0).
 * Edges: the one import (file 0 -> file 1) and both calls.
 */
function fixtureFamilyTables(): FamilyTables {
  return {
    families: [fixtureFamilyRow(0, 0, "alpha-family"), fixtureFamilyRow(1, 1, "beta-family")],
    members: [
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        family: 0,
        familyId: "atlas-family-v1:alpha-family",
        entityId: 0,
        path: "a.ts",
        name: "alpha",
        startByte: 0,
        endByte: 5,
        candidates: 1,
        affinity: 1,
        structuralAffinity: 1,
        semanticAffinity: 0.5,
      },
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        family: 1,
        familyId: "atlas-family-v1:beta-family",
        entityId: 1,
        path: "b.ts",
        name: "beta",
        startByte: 0,
        endByte: 5,
        candidates: 0,
        affinity: 0,
        structuralAffinity: 0,
        semanticAffinity: 0,
      },
    ],
    rollups: [
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        level: "file",
        locationId: 0,
        location: "a.ts",
        family: 0,
        familyId: "atlas-family-v1:alpha-family",
        members: 1,
        locationMembers: 1,
        dominant: true,
      },
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        level: "file",
        locationId: 1,
        location: "b.ts",
        family: 1,
        familyId: "atlas-family-v1:beta-family",
        members: 1,
        locationMembers: 1,
        dominant: true,
      },
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        level: "directory",
        locationId: 2,
        location: "",
        family: 0,
        familyId: "atlas-family-v1:alpha-family",
        members: 2,
        locationMembers: 2,
        dominant: true,
      },
    ],
    edges: [
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        relation: "imports",
        grain: "file",
        edge: 0,
        sourceFamily: 0,
        sourceFamilyId: "atlas-family-v1:alpha-family",
        targetFamily: 1,
        targetFamilyId: "atlas-family-v1:beta-family",
        multiplicity: 1,
      },
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        relation: "calls",
        grain: "symbol",
        edge: 1,
        sourceFamily: 0,
        sourceFamilyId: "atlas-family-v1:alpha-family",
        targetFamily: 1,
        targetFamilyId: "atlas-family-v1:beta-family",
        multiplicity: 1,
      },
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        relation: "calls",
        grain: "symbol",
        edge: 2,
        sourceFamily: 1,
        sourceFamilyId: "atlas-family-v1:beta-family",
        targetFamily: 0,
        targetFamilyId: "atlas-family-v1:alpha-family",
        multiplicity: 1,
      },
    ],
    // Exact link order: defines (2), imports (1), calls (2), parent (3).
    contributions: [
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        relation: "imports",
        sourceDomain: "file",
        sourceId: 0,
        targetDomain: "file",
        targetId: 1,
        sourceFamily: 0,
        targetFamily: 1,
        edge: 0,
      },
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        relation: "calls",
        sourceDomain: "symbol",
        sourceId: 0,
        targetDomain: "symbol",
        targetId: 1,
        sourceFamily: 0,
        targetFamily: 1,
        edge: 1,
      },
      {
        snapshotId: FIXTURE_SNAPSHOT_ID,
        relation: "calls",
        sourceDomain: "symbol",
        sourceId: 1,
        targetDomain: "symbol",
        targetId: 0,
        sourceFamily: 1,
        targetFamily: 0,
        edge: 2,
      },
    ],
  };
}

function fixtureFamilies(): { graph: ViewerGraph; families: WorldFamilies } {
  const graph = fixtureGraph();
  return { graph, families: projectFamilies(fixtureFamilyTables(), graph) };
}

async function preactFamilies(): Promise<{ graph: ViewerGraph; families: WorldFamilies }> {
  const graph = await projectWorld(await readWorldDir(PREACT_DIR));
  const tables = await decodeFamiliesFiles(await readFamiliesDir(PREACT_DIR));
  return { graph, families: projectFamilies(tables, graph) };
}

describe("family palette", () => {
  it("is deterministic and valid hex", () => {
    for (let ordinal = 0; ordinal < 64; ordinal++) {
      expect(familyColor(ordinal)).toBe(familyColor(ordinal));
      expect(familyColor(ordinal)).toMatch(/^#[0-9a-f]{6}$/);
    }
  });

  it("separates neighbouring ordinals by the golden angle", () => {
    const colors = new Set<string>();
    for (let ordinal = 0; ordinal < 48; ordinal++) colors.add(familyColor(ordinal));
    expect(colors.size).toBe(48);
  });

  it("tints by domain: symbol by its family, file by dominant, none by the neutral tint", () => {
    const { graph, families } = fixtureFamilies();
    // Symbol 1 is a fallback member of family 1.
    expect(familyOfPoint(families, graph.fileCount + 1)).toBe(1);
    expect(familyTint(families, graph.fileCount + 1)).toBe(familyColor(1));
    // File 0's dominant family is 0.
    expect(familyTint(families, 0)).toBe(familyColor(0));
    // Directory "src/" (ordinal 1) holds no members: the neutral tint.
    const srcOrdinal = graph.fileCount + graph.symbolCount + 1;
    expect(familyTint(families, srcOrdinal)).toBe(NO_FAMILY_COLOR);
  });
});

describe("family edge listing and drill-down", () => {
  it("lists rendered edges by multiplicity, ties by edge ordinal, bounded", () => {
    const { families } = fixtureFamilies();
    const top = topFamilyEdges(families, 10);
    expect(top.map((edge) => edge.edge)).toEqual([0, 1, 2]);
    expect(top.every((edge) => edge.crossFamily)).toBe(true);
    expect(topFamilyEdges(families, 2)).toHaveLength(2);
  });

  it("orders the real preact edges by descending multiplicity", async () => {
    const { families } = await preactFamilies();
    const top = topFamilyEdges(families, 25);
    expect(top).toHaveLength(25);
    for (let i = 1; i < top.length; i++) {
      const previous = top[i - 1]?.multiplicity ?? 0;
      const current = top[i]?.multiplicity ?? 0;
      expect(previous).toBeGreaterThanOrEqual(current);
    }
    expect(top[0]?.multiplicity).toBeGreaterThan(1);
  });

  it("drills a family edge into its contributing exact links", () => {
    const { graph, families } = fixtureFamilies();
    // Edge 1 is the call symbol 0 -> symbol 1: exact link index 3 (defines 0-1,
    // imports 2, calls 3-4, parent 5-7).
    const drill = drillFamilyEdge(families, 1);
    expect(drill).not.toBeNull();
    expect(drill?.edge.relation).toBe("calls");
    expect(drill?.source.name).toBe("alpha-family");
    expect(drill?.target.name).toBe("beta-family");
    expect(drill?.links).toEqual([3]);
    expect(graph.linkSourceIndices[3]).toBe(graph.fileCount + 0);
    expect(graph.linkTargetIndices[3]).toBe(graph.fileCount + 1);
    expect(drillFamilyEdge(families, 99)).toBeNull();
  });

  it("renders contribution rows as bounded, labelled lines", async () => {
    const { graph, families } = await preactFamilies();
    const top = topFamilyEdges(families, 1)[0];
    if (top === undefined) throw new Error("no family edges");
    const drill = drillFamilyEdge(families, top.edge);
    if (drill === null) throw new Error("no drill");
    const { lines, remaining } = contributionLines(graph, drill.links, 5);
    expect(lines.length).toBeLessThanOrEqual(5);
    expect(lines.length + remaining).toBe(drill.links.length);
    for (const line of lines) {
      expect(["imports", "calls"]).toContain(line.relation);
      expect(line.source.length).toBeGreaterThan(0);
      expect(line.target.length).toBeGreaterThan(0);
      expect(line.sourceId).toMatch(/^(file|symbol):\d+$/);
    }
  });
});

describe("families-aware link accessors", () => {
  // Fixture links: defines 0-1, imports 2, calls 3-4, parent 5-7; family rows at
  // 8, 9, 10 (edges 0, 1, 2).
  const EXACT = 8;

  function build(overlay: "structure" | "families", drill: number | null, mask = ALL_RELATIONS_MASK) {
    const { graph, families } = fixtureFamilies();
    expect(buildViewerArrow(graph, { families }).links.numRows).toBe(EXACT + 3);
    const options = {
      mask,
      renderLinks: true,
      overlay,
      families,
      exactLinkCount: graph.linkCount,
      drill,
    };
    return { color: linkColorAccessor(options), width: linkWidthAccessor(options) };
  }

  it("structure overlay renders exactly as without families (family rows hidden)", () => {
    const { color, width } = build("structure", null);
    expect(color("imports", 2)).not.toEqual([0, 0, 0, 0]);
    expect(width("imports", 2)).toBe(1);
    for (const row of [EXACT, EXACT + 1, EXACT + 2]) {
      expect(color("imports", row)).toEqual([0, 0, 0, 0]);
      expect(width("imports", row)).toBe(0);
    }
    // The relation filter still governs exact links.
    const filtered = build("structure", null, relationMask(["defines"]));
    expect(filtered.width("imports", 2)).toBe(0);
  });

  it("families overlay hides exact links and draws family edges", () => {
    const { color, width } = build("families", null);
    for (let link = 0; link < EXACT; link++) {
      expect(width("imports", link)).toBe(0);
    }
    expect(width("imports", EXACT)).toBeGreaterThan(0);
    expect(color("calls", EXACT + 1)).not.toEqual([0, 0, 0, 0]);
    // The relation filter governs family edges too.
    const filtered = build("families", null, relationMask(["calls"]));
    expect(filtered.width("imports", EXACT)).toBe(0);
    expect(filtered.width("calls", EXACT + 1)).toBeGreaterThan(0);
  });

  it("drill-down reveals exactly the contributing exact links", () => {
    const { color, width } = build("families", 1);
    // Edge 1 contributes exact link 3 only.
    expect(width("calls", 3)).toBe(1);
    expect(color("calls", 3)).not.toEqual([0, 0, 0, 0]);
    for (const link of [0, 1, 2, 4, 5, 6, 7]) {
      expect(width("calls", link)).toBe(0);
    }
    // The drilled family edge stays visible, the others hide.
    expect(width("calls", EXACT + 1)).toBeGreaterThan(0);
    expect(width("imports", EXACT)).toBe(0);
    expect(width("calls", EXACT + 2)).toBe(0);
  });

  it("is referentially stable for identical view state", () => {
    const { graph, families } = fixtureFamilies();
    const options = {
      mask: ALL_RELATIONS_MASK,
      renderLinks: true,
      overlay: "families" as const,
      families,
      exactLinkCount: graph.linkCount,
      drill: null,
    };
    expect(linkColorAccessor(options)).toBe(linkColorAccessor(options));
    expect(linkWidthAccessor(options)).toBe(linkWidthAccessor(options));
    // A drill change is a new view state: new identities.
    expect(linkColorAccessor({ ...options, drill: 1 })).not.toBe(linkColorAccessor(options));
  });
});
