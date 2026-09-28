/**
 * Laws of the structural repository layout (VAL-LAYOUT-001..008, VAL-SIG-001),
 * checked on the layout's own output over real worlds staged by Bazel
 * (//web/atlas-live/projection:layout_worlds: preactjs/preact and babel/babel
 * with their locations tables), the synthetic stress world, and the local-import
 * fixtures (//web/atlas-live/projection:import_fixtures).
 */
import { createStore } from "jotai";
import { beforeAll, describe, expect, it } from "vitest";

import { projectTables, type ViewerGraph } from "../../projection/src/graph.ts";
import { projectWorld } from "../../projection/src/project.ts";
import { RELATION_ORDER, relationRank } from "../../projection/src/relation.ts";
import { syntheticWorld } from "../../projection/src/synthetic.ts";
import { decodeWorldFiles } from "../../projection/src/tables.ts";
import { readWorldDir } from "../../projection/src/world_dir.ts";
import {
  adoptGraphAtom,
  hoveredIndexAtom,
  overlayAtom,
  selectedAtom,
  setDepthAtom,
  setRelationMaskAtom,
  toggleSelectedAtom,
} from "../src/atoms.ts";
import { relationMask } from "../src/selection.ts";
import {
  FILE_CELL,
  REGION_GAP,
  STRUCTURE_VERSION,
  computeStructuralLayout,
  decomposeRepository,
  directoryPointIndex,
  structuralLayout,
  type StructuralLayout,
} from "../src/structure.ts";
import { centerOf, containsPoint, containsRect, disjoint, inset, type Rect } from "../src/geometry.ts";
import { fixtureGraph } from "./graphFixture.ts";

const LAYOUT_WORLDS = "../projection/layout_worlds";
const IMPORT_FIXTURES = "../projection/import_fixtures";
const PREACT = "6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9";
const BABEL = "002a462e6f58440bbf60071f1e945b38bb304fe46a38ca6fdfd578248693cf01";
const HASHES = { metadata: "0".repeat(64), entities: "1".repeat(64), relations: "2".repeat(64) };
const EPSILON = 1e-3;

async function stagedWorld(dir: string): Promise<ViewerGraph> {
  return projectWorld(await readWorldDir(dir));
}

function syntheticGraph(): ViewerGraph {
  return projectTables(syntheticWorld(), HASHES);
}

function pointAt(layout: StructuralLayout, index: number): [number, number] {
  return [layout.xy[index * 2] ?? Number.NaN, layout.xy[index * 2 + 1] ?? Number.NaN];
}

function distance(a: readonly [number, number], b: readonly [number, number]): number {
  return Math.hypot(a[0] - b[0], a[1] - b[1]);
}

function snapshot(layout: StructuralLayout): unknown {
  return {
    identity: layout.identity,
    xy: Array.from(layout.xy),
    regions: layout.directoryRegions,
    cells: layout.fileCells,
  };
}

/** Every file's cell lies in its directory's region and every ancestor's; files sit in their cells. */
function expectContiguous(graph: ViewerGraph, layout: StructuralLayout): void {
  const { directoryParent, fileDirectory } = layout.structure;
  let violations = 0;
  for (let file = 0; file < graph.fileCount; file++) {
    const cell = layout.fileCells[file];
    if (cell === undefined) throw new Error(`no cell for file ${file}`);
    const [x, y] = pointAt(layout, file);
    if (!containsPoint(cell, x, y, EPSILON)) violations++;
    for (let ordinal = fileDirectory[file] ?? -1; ordinal >= 0; ordinal = directoryParent[ordinal] ?? -1) {
      const region = layout.directoryRegions[ordinal];
      if (region === undefined || !containsRect(region, cell)) violations++;
    }
  }
  expect(violations, "files outside their own cell or outside an ancestor's region").toBe(0);
}

/** A rectangle grown by just under half a region gap. */
function grow(rect: Rect): Rect {
  return inset(rect, -(REGION_GAP / 2) * 0.99);
}

/**
 * Sibling regions are pairwise disjoint, at least one gap apart (growing both
 * by just under half a gap keeps them disjoint), and inside their parent's region.
 */
function expectSiblingsDisjoint(graph: ViewerGraph, layout: StructuralLayout): void {
  const { directoryParent } = layout.structure;
  const siblings = new Map<number, Rect[]>();
  let outside = 0;
  for (let ordinal = 0; ordinal < graph.directoryCount; ordinal++) {
    const parent = directoryParent[ordinal] ?? -1;
    if (parent < 0) continue;
    const region = layout.directoryRegions[ordinal];
    const parentRegion = layout.directoryRegions[parent];
    if (region === undefined || parentRegion === undefined) throw new Error("missing region");
    if (!containsRect(parentRegion, region)) outside++;
    const list = siblings.get(parent) ?? [];
    list.push(region);
    siblings.set(parent, list);
  }
  let overlapping = 0;
  let closer = 0;
  let pairs = 0;
  for (const list of siblings.values()) {
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const a = list[i];
        const b = list[j];
        if (a === undefined || b === undefined) continue;
        pairs++;
        if (!disjoint(a, b)) overlapping++;
        if (!disjoint(grow(a), grow(b))) closer++;
      }
    }
  }
  expect(outside, "child regions outside their parent's region").toBe(0);
  expect(overlapping, `overlapping sibling pairs among ${pairs}`).toBe(0);
  expect(closer, `sibling pairs closer than one gap among ${pairs}`).toBe(0);
}

/** Every symbol's slot lies inside its file's cell (or within one gap of it). */
function expectSymbolsInFileTerritory(graph: ViewerGraph, layout: StructuralLayout): number {
  const { symbolFile } = layout.structure;
  let outside = 0;
  let placed = 0;
  for (let symbol = 0; symbol < graph.symbolCount; symbol++) {
    const file = symbolFile[symbol] ?? -1;
    expect(file, `symbol ${symbol} has a defining file`).toBeGreaterThanOrEqual(0);
    const cell = layout.fileCells[file];
    if (cell === undefined) throw new Error(`no cell for file ${file}`);
    const [x, y] = pointAt(layout, graph.fileCount + symbol);
    if (!containsPoint(cell, x, y, EPSILON)) outside++;
    placed++;
  }
  expect(outside, "symbol slots outside their file's cell").toBe(0);
  return placed;
}

/** The map is near-square and file cells cover a meaningful share of it. */
function expectCompact(
  name: string,
  graph: ViewerGraph,
  layout: StructuralLayout,
  minimumFill: number,
): void {
  const region = layout.directoryRegions[layout.structure.root];
  if (region === undefined) throw new Error("missing root region");
  const w = region.x1 - region.x0;
  const h = region.y1 - region.y0;
  const fill = (graph.fileCount * FILE_CELL * FILE_CELL) / (w * h);
  console.log(`${name} map: ${w} x ${h} layout units, file cells fill ${(fill * 100).toFixed(1)}%`);
  expect(w / h).toBeGreaterThan(0.5);
  expect(w / h).toBeLessThan(2);
  expect(fill).toBeGreaterThan(minimumFill);
}

describe("structural layout on the hand-made fixture", () => {
  it("returns one finite coordinate pair per point", () => {
    const graph = fixtureGraph();
    const layout = computeStructuralLayout(graph);
    expect(layout.xy.length).toBe(graph.pointCount * 2);
    for (const value of layout.xy) expect(Number.isFinite(value)).toBe(true);
    expect(layout.identity.startsWith(`${STRUCTURE_VERSION}:`)).toBe(true);
  });

  it("takes the graph as its only input", () => {
    expect(computeStructuralLayout.length).toBe(1);
    expect(structuralLayout.length).toBe(1);
  });
});

describe("structural layout on preactjs/preact (the default world)", () => {
  let graph: ViewerGraph;
  let layout: StructuralLayout;

  beforeAll(async () => {
    graph = await stagedWorld(`${LAYOUT_WORLDS}/${PREACT}`);
    layout = structuralLayout(graph);
  });

  it("is bit-identical across repeated computation and memoized per graph (VAL-LAYOUT-001)", async () => {
    const again = computeStructuralLayout(graph);
    expect(again).not.toBe(layout);
    expect(snapshot(again)).toEqual(snapshot(layout));
    expect(new Uint8Array(again.xy.buffer)).toEqual(new Uint8Array(layout.xy.buffer));
    expect(structuralLayout(graph)).toBe(layout);
    // An independently decoded copy of the same world gets the same geometry.
    const reloaded = await stagedWorld(`${LAYOUT_WORLDS}/${PREACT}`);
    expect(reloaded).not.toBe(graph);
    expect(snapshot(structuralLayout(reloaded))).toEqual(snapshot(layout));
  });

  it("derives the tree from parent edges and membership that agrees with the exact evidence", () => {
    const structure = decomposeRepository(graph);
    expect(structure.directoryParent[structure.root]).toBe(-1);
    expect(graph.pointPaths[directoryPointIndex(graph, structure.root)]).toBe("");
    expect(Array.from(structure.directoryParent).filter((parent) => parent < 0)).toHaveLength(1);
    // Each file's path-derived directory is exactly the target of its parent edge.
    const parentOut = graph.adjacency.parent.out;
    for (let file = 0; file < graph.fileCount; file++) {
      const target = parentOut.points[parentOut.offsets[file] ?? 0] ?? -1;
      expect(directoryPointIndex(graph, structure.fileDirectory[file] ?? -1)).toBe(target);
    }
    // Each symbol belongs to the file whose defines edge reaches it.
    const definesRank = relationRank("defines");
    for (let link = 0; link < graph.linkCount; link++) {
      if (graph.linkRelations[link] !== definesRank) continue;
      const symbol = (graph.linkTargetIndices[link] ?? 0) - graph.fileCount;
      expect(structure.symbolFile[symbol]).toBe(graph.linkSourceIndices[link]);
    }
  });

  it("gives each directory a region containing all its files; siblings are disjoint (VAL-LAYOUT-002)", () => {
    expectContiguous(graph, layout);
    expectSiblingsDisjoint(graph, layout);
    expectCompact("preact", graph, layout, 0.2);
    for (let ordinal = 0; ordinal < graph.directoryCount; ordinal++) {
      const region = layout.directoryRegions[ordinal];
      if (region === undefined) throw new Error("missing region");
      const [cx, cy] = centerOf(region);
      const [x, y] = pointAt(layout, directoryPointIndex(graph, ordinal));
      expect(Math.abs(x - cx)).toBeLessThan(EPSILON);
      expect(Math.abs(y - cy)).toBeLessThan(EPSILON);
    }
  });

  it("places same-directory files much closer than cross-directory files (VAL-LAYOUT-007)", () => {
    const { fileDirectory } = layout.structure;
    let intraSum = 0;
    let intraPairs = 0;
    let interSum = 0;
    let interPairs = 0;
    for (let a = 0; a < graph.fileCount; a++) {
      for (let b = a + 1; b < graph.fileCount; b++) {
        const d = distance(pointAt(layout, a), pointAt(layout, b));
        if (fileDirectory[a] === fileDirectory[b]) {
          intraSum += d;
          intraPairs++;
        } else {
          interSum += d;
          interPairs++;
        }
      }
    }
    const intra = intraSum / intraPairs;
    const inter = interSum / interPairs;
    console.log(
      `VAL-LAYOUT-007 preact file distance: intra-directory mean ${intra.toFixed(3)} over ${intraPairs} pairs; ` +
        `inter-directory mean ${inter.toFixed(3)} over ${interPairs} pairs; ratio ${(intra / inter).toFixed(4)}`,
    );
    expect(intraPairs).toBeGreaterThan(0);
    expect(interPairs).toBeGreaterThan(0);
    expect(intra).toBeLessThan(inter * 0.5);
  });

  it("places intra-directory relation endpoints closer than cross-directory ones (VAL-SIG-001)", () => {
    const { fileDirectory, symbolFile } = layout.structure;
    const fileOf = (index: number): number =>
      index < graph.fileCount ? index : (symbolFile[index - graph.fileCount] ?? -1);
    const lines: string[] = [];
    for (const relation of ["imports", "calls"] as const) {
      const rank = relationRank(relation);
      let intraSum = 0;
      let intra = 0;
      let crossSum = 0;
      let cross = 0;
      for (let link = 0; link < graph.linkCount; link++) {
        if (graph.linkRelations[link] !== rank) continue;
        const source = graph.linkSourceIndices[link] ?? 0;
        const target = graph.linkTargetIndices[link] ?? 0;
        const d = distance(pointAt(layout, source), pointAt(layout, target));
        if (fileDirectory[fileOf(source)] === fileDirectory[fileOf(target)]) {
          intraSum += d;
          intra++;
        } else {
          crossSum += d;
          cross++;
        }
      }
      expect(intra).toBeGreaterThan(0);
      expect(cross).toBeGreaterThan(0);
      expect(intraSum / intra).toBeLessThan(crossSum / cross);
      lines.push(
        `${relation}: intra-directory ${intra} links, mean span ${(intraSum / intra).toFixed(3)}; ` +
          `cross-directory ${cross} links, mean span ${(crossSum / cross).toFixed(3)}; ` +
          `cross share ${(cross / (intra + cross)).toFixed(4)}`,
      );
    }
    console.log(`VAL-SIG-001 preact relation spans: ${lines.join(" | ")}`);
  });

  it("puts every symbol slot inside its file's cell (VAL-LAYOUT-008)", () => {
    expect(expectSymbolsInFileTerritory(graph, layout)).toBe(graph.symbolCount);
    // No symbol hides under its file: the centre slot is the file's.
    for (let symbol = 0; symbol < graph.symbolCount; symbol++) {
      const file = layout.structure.symbolFile[symbol] ?? 0;
      expect(distance(pointAt(layout, graph.fileCount + symbol), pointAt(layout, file))).toBeGreaterThan(0);
    }
  });

  it("ignores filters, overlays, depth, selection and hover (VAL-LAYOUT-003..006)", () => {
    const store = createStore();
    store.set(adoptGraphAtom, graph);
    const expected = snapshot(computeStructuralLayout(graph));
    const check = (): void => {
      expect(structuralLayout(graph)).toBe(layout);
      expect(snapshot(computeStructuralLayout(graph))).toEqual(expected);
    };
    for (let mask = 0; mask < 1 << RELATION_ORDER.length; mask++) {
      store.set(
        setRelationMaskAtom,
        relationMask(RELATION_ORDER.filter((_relation, bit) => (mask & (1 << bit)) !== 0)),
      );
      check();
    }
    store.set(overlayAtom, "structure");
    check();
    for (const depth of [1, 2, 3, 2, 1]) {
      store.set(setDepthAtom, depth);
      check();
    }
    store.set(toggleSelectedAtom, "file:0");
    check();
    store.set(toggleSelectedAtom, `symbol:${graph.symbolCount - 1}`);
    check();
    store.set(hoveredIndexAtom, 3);
    check();
    store.set(selectedAtom, new Set<string>());
    check();
  });

  it("is independent of imports and calls: removing them moves nothing", async () => {
    const tables = await decodeWorldFiles(await readWorldDir(`${LAYOUT_WORLDS}/${PREACT}`));
    const structural = projectTables(
      {
        ...tables,
        metadata: { ...tables.metadata, importsCount: 0, callsCount: 0 },
        relations: tables.relations.filter((row) => row.relation !== "imports" && row.relation !== "calls"),
      },
      HASHES,
    );
    expect(structural.relationCounts.calls).toBe(0);
    expect(snapshot(computeStructuralLayout(structural))).toEqual(snapshot(layout));
  });
});

describe("structural layout on babel/babel (the largest world)", () => {
  let graph: ViewerGraph;
  let layout: StructuralLayout;

  beforeAll(async () => {
    graph = await stagedWorld(`${LAYOUT_WORLDS}/${BABEL}`);
    const started = performance.now();
    layout = computeStructuralLayout(graph);
    console.log(
      `babel structural layout: ${graph.fileCount} files, ${graph.directoryCount} directories, ` +
        `${graph.symbolCount} symbols in ${(performance.now() - started).toFixed(1)} ms`,
    );
  });

  it("gives each directory a region containing all its files; siblings are disjoint (VAL-LAYOUT-002)", () => {
    expectContiguous(graph, layout);
    expectSiblingsDisjoint(graph, layout);
    // Babel has about three directories per four files (mostly one-file fixture
    // directories), so region margins and gaps dominate its area.
    expectCompact("babel", graph, layout, 0.08);
  });

  it("puts every symbol slot inside its file's cell (VAL-LAYOUT-008)", () => {
    expect(expectSymbolsInFileTerritory(graph, layout)).toBe(graph.symbolCount);
  });

  it("is deterministic (VAL-LAYOUT-001)", () => {
    expect(snapshot(computeStructuralLayout(graph))).toEqual(snapshot(layout));
  });
});

describe("structural layout on the synthetic stress world", () => {
  const graph = syntheticGraph();
  const layout = computeStructuralLayout(graph);

  it("is deterministic and distinct from the real worlds' identities (VAL-LAYOUT-001)", async () => {
    expect(snapshot(computeStructuralLayout(syntheticGraph()))).toEqual(snapshot(layout));
    const preact = structuralLayout(await stagedWorld(`${LAYOUT_WORLDS}/${PREACT}`));
    expect(layout.identity).not.toBe(preact.identity);
  });

  it("matches the synthetic parent edges, keeps regions contiguous and slots in file cells (VAL-LAYOUT-008)", () => {
    const parentOut = graph.adjacency.parent.out;
    for (let file = 0; file < graph.fileCount; file++) {
      const target = parentOut.points[parentOut.offsets[file] ?? 0] ?? -1;
      expect(directoryPointIndex(graph, layout.structure.fileDirectory[file] ?? -1)).toBe(target);
    }
    expectContiguous(graph, layout);
    expectSiblingsDisjoint(graph, layout);
    expect(expectSymbolsInFileTerritory(graph, layout)).toBe(graph.symbolCount);
  });
});

describe("structural layout fallbacks on the local-import fixtures", () => {
  it("assigns files by path prefix when the world has a locations table", async () => {
    const graph = await stagedWorld(`${IMPORT_FIXTURES}/valid`);
    const layout = computeStructuralLayout(graph);
    const { root, fileDirectory } = layout.structure;
    const src = graph.pointPaths.indexOf("src/") - graph.fileCount - graph.symbolCount;
    expect(src).toBeGreaterThanOrEqual(0);
    expect(Array.from(fileDirectory)).toEqual([root, src, src]);
    expectContiguous(graph, layout);
    expectSiblingsDisjoint(graph, layout);
    expectSymbolsInFileTerritory(graph, layout);
  });

  it("puts every file under the root, in evidence order, when the world has no locations table", async () => {
    const graph = await stagedWorld(`${IMPORT_FIXTURES}/no-locations`);
    const layout = computeStructuralLayout(graph);
    const { root, fileDirectory, directoryParent } = layout.structure;
    expect(Array.from(fileDirectory)).toEqual(Array.from({ length: graph.fileCount }, () => root));
    // The directory tree still comes from the parent edges; no directory is invented.
    expect(directoryParent).toHaveLength(graph.directoryCount);
    expect(Array.from(directoryParent).filter((parent) => parent < 0)).toEqual([-1]);
    for (const value of layout.xy) expect(Number.isFinite(value)).toBe(true);
    // Files fill the root's grid row-major in file (evidence ordinal) order.
    const cells = layout.fileCells;
    for (let file = 1; file < graph.fileCount; file++) {
      const previous = cells[file - 1];
      const current = cells[file];
      if (previous === undefined || current === undefined) throw new Error("missing cell");
      expect(current.y0 > previous.y0 || (current.y0 === previous.y0 && current.x0 > previous.x0)).toBe(true);
    }
    expectContiguous(graph, layout);
    expectSymbolsInFileTerritory(graph, layout);
    const withLocations = computeStructuralLayout(await stagedWorld(`${IMPORT_FIXTURES}/valid`));
    expect(layout.identity).not.toBe(withLocations.identity);
  });
});
