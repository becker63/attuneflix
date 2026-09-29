/**
 * Laws of the containment tree and the visible-frontier state
 * (VAL-FRONT-005: collapse is the exact inverse of expansion;
 * VAL-FRONT-006: π_F maps every raw entity to its deepest visible ancestor),
 * checked on the hand-computed fixture and the real preact world staged by
 * //web/atlas-live/projection:layout_worlds.
 */
import { beforeAll, describe, expect, it } from "vitest";

import type { ViewerGraph } from "../../projection/src/graph.ts";
import { projectWorld } from "../../projection/src/project.ts";
import { readWorldDir } from "../../projection/src/world_dir.ts";
import { containmentTree, isContainer } from "../src/frontier/containment.ts";
import {
  collapse,
  expand,
  frontierLevel,
  initialFrontier,
  isVisible,
  pi,
  projectedNodes,
  type VisibleFrontier,
} from "../src/frontier/frontier.ts";
import { FIXTURE_IDS, frontierFixtureGraph } from "./frontierFixture.ts";

const LAYOUT_WORLDS = "../projection/layout_worlds";
const PREACT = "6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9";

const ID = FIXTURE_IDS;

function nodeIds(tree: Parameters<typeof projectedNodes>[0], frontier: VisibleFrontier): string[] {
  return projectedNodes(tree, frontier).map((node) => node.id);
}

describe("containment tree on the hand-made fixture", () => {
  const graph = frontierFixtureGraph();
  const tree = containmentTree(graph);

  it("roots at the exported empty-path directory and nests by parent/defines evidence", () => {
    expect(graph.pointIds[tree.root]).toBe(ID.root);
    expect(tree.containerOf[tree.root]).toBe(-1);
    // Directories nest per the parent rows.
    const index = (id: string): number => graph.indexById.get(id) ?? -1;
    expect(tree.containerOf[index(ID.a)]).toBe(tree.root);
    expect(tree.containerOf[index(ID.b)]).toBe(tree.root);
    expect(tree.containerOf[index(ID.c)]).toBe(tree.root);
    expect(tree.containerOf[index(ID.sub)]).toBe(index(ID.a));
    // Files belong to their containing directory; the root-anchored file to the root.
    expect(tree.containerOf[index(ID.topFile)]).toBe(tree.root);
    expect(tree.containerOf[index(ID.xFile)]).toBe(index(ID.a));
    expect(tree.containerOf[index(ID.zFile)]).toBe(index(ID.sub));
    expect(tree.containerOf[index(ID.wFile)]).toBe(index(ID.b));
    // Symbols belong to their defining file.
    expect(tree.containerOf[index(ID.topSym)]).toBe(index(ID.topFile));
    expect(tree.containerOf[index(ID.xaSym)]).toBe(index(ID.xFile));
    expect(tree.containerOf[index(ID.zaSym)]).toBe(index(ID.zFile));
    // Depths: root 0, top-level 1, a/sub and a's files 2, a/sub/z.ts 3, its symbol 4.
    expect(tree.depthOf[tree.root]).toBe(0);
    expect(tree.depthOf[index(ID.a)]).toBe(1);
    expect(tree.depthOf[index(ID.sub)]).toBe(2);
    expect(tree.depthOf[index(ID.zFile)]).toBe(3);
    expect(tree.depthOf[index(ID.zaSym)]).toBe(4);
    // Containers are exactly the directories and files.
    expect(isContainer(tree, index(ID.a))).toBe(true);
    expect(isContainer(tree, index(ID.xFile))).toBe(true);
    expect(isContainer(tree, index(ID.xaSym))).toBe(false);
    // The tree is total: every non-root point has a container and a depth.
    for (let i = 0; i < graph.pointCount; i++) {
      if (i === tree.root) continue;
      expect(tree.containerOf[i]).toBeGreaterThanOrEqual(0);
      expect(tree.depthOf[i]).toBeGreaterThan(0);
    }
  });

  it("is memoized per graph and deterministic", () => {
    expect(containmentTree(graph)).toBe(tree);
    const again = containmentTree(frontierFixtureGraph());
    expect(Array.from(again.containerOf)).toEqual(Array.from(tree.containerOf));
    expect(Array.from(again.depthOf)).toEqual(Array.from(tree.depthOf));
  });
});

describe("visible frontier on the hand-made fixture", () => {
  const graph = frontierFixtureGraph();
  const tree = containmentTree(graph);

  it("opens with the root's children and the root-anchored files, and no symbols", () => {
    const frontier = initialFrontier();
    expect(frontier.expanded).toEqual([]);
    expect(frontier.revision).toBe(0);
    expect(frontierLevel(tree, frontier)).toBe("repository");
    expect(nodeIds(tree, frontier)).toEqual([ID.topFile, ID.a, ID.b, ID.c]);
  });

  it("expands a directory to reveal exactly its own files and child directories", () => {
    const frontier = expand(tree, initialFrontier(), ID.a);
    expect(frontier.expanded).toEqual([ID.a]);
    expect(frontier.revision).toBe(1);
    expect(frontierLevel(tree, frontier)).toBe("directory");
    expect(nodeIds(tree, frontier)).toEqual([ID.topFile, ID.xFile, ID.yFile, ID.a, ID.b, ID.sub, ID.c]);
    // The expanded region reports itself; the revealed children know their container.
    const nodes = projectedNodes(tree, frontier);
    const a = nodes.find((node) => node.id === ID.a);
    const sub = nodes.find((node) => node.id === ID.sub);
    const x = nodes.find((node) => node.id === ID.xFile);
    expect(a?.expanded).toBe(true);
    expect(a?.kind).toBe("directory");
    expect(a?.label).toBe("a");
    expect(nodes.some((node) => node.id === ID.b)).toBe(true);
    expect(sub?.container).toBe(ID.a);
    expect(x?.container).toBe(ID.a);
    expect(x?.expanded).toBe(false);
  });

  it("expands a file to reveal exactly its symbols (file level)", () => {
    let frontier = expand(tree, initialFrontier(), ID.a);
    frontier = expand(tree, frontier, ID.xFile);
    expect(frontier.expanded).toEqual([ID.xFile, ID.a]);
    expect(frontier.revision).toBe(2);
    expect(frontierLevel(tree, frontier)).toBe("file");
    expect(nodeIds(tree, frontier)).toEqual([
      ID.topFile,
      ID.xFile,
      ID.yFile,
      ID.xaSym,
      ID.xbSym,
      ID.a,
      ID.b,
      ID.sub,
      ID.c,
    ]);
  });

  it("rejects expanding symbols, unknown ids, and treats the root as permanently expanded", () => {
    const frontier = initialFrontier();
    expect(() => expand(tree, frontier, ID.xaSym)).toThrow(/container/);
    expect(() => expand(tree, frontier, "file:99")).toThrow(/unknown/);
    expect(() => collapse(tree, frontier, "file:99")).toThrow(/unknown/);
    expect(expand(tree, frontier, ID.root)).toBe(frontier);
    expect(collapse(tree, frontier, ID.root)).toBe(frontier);
    // Re-expanding an expanded container and collapsing a collapsed one are no-ops.
    const expanded = expand(tree, frontier, ID.a);
    expect(expand(tree, expanded, ID.a)).toBe(expanded);
    expect(collapse(tree, frontier, ID.a)).toBe(frontier);
  });

  it("never mutates the input frontier", () => {
    const frontier = initialFrontier();
    const expanded = expand(tree, frontier, ID.a);
    expect(frontier.expanded).toEqual([]);
    expect(frontier.revision).toBe(0);
    expect(expanded).not.toBe(frontier);
  });
});

describe("collapse is the exact inverse of expansion (VAL-FRONT-005)", () => {
  const graph = frontierFixtureGraph();
  const tree = containmentTree(graph);

  it("expand then collapse reproduces the initial projection state", () => {
    const initial = initialFrontier();
    let frontier = expand(tree, initial, ID.a);
    frontier = collapse(tree, frontier, ID.a);
    expect(frontier.expanded).toEqual(initial.expanded);
    expect(nodeIds(tree, frontier)).toEqual(nodeIds(tree, initial));
  });

  it("collapse removes expanded descendants along with the region", () => {
    const initial = initialFrontier();
    let frontier = expand(tree, initial, ID.a);
    frontier = expand(tree, frontier, ID.sub);
    frontier = expand(tree, frontier, ID.xFile);
    expect(frontier.expanded).toEqual([ID.xFile, ID.a, ID.sub]);
    frontier = collapse(tree, frontier, ID.a);
    expect(frontier.expanded).toEqual([]);
    expect(nodeIds(tree, frontier)).toEqual(nodeIds(tree, initial));
  });

  it("collapsing one region leaves independent expansions untouched", () => {
    let frontier = expand(tree, initialFrontier(), ID.a);
    frontier = expand(tree, frontier, ID.b);
    frontier = collapse(tree, frontier, ID.a);
    expect(frontier.expanded).toEqual([ID.b]);
    expect(nodeIds(tree, frontier)).toEqual([ID.topFile, ID.wFile, ID.a, ID.b, ID.c]);
  });
});

describe("π_F on the hand-made fixture (VAL-FRONT-006)", () => {
  const graph = frontierFixtureGraph();
  const tree = containmentTree(graph);
  const idOf = (index: number): string => graph.pointIds[index] ?? "";
  const pointIndexOf = (id: string): number => graph.indexById.get(id) ?? -1;

  it("maps every entity to its deepest visible ancestor at the default frontier", () => {
    const frontier = initialFrontier();
    const expected: Record<string, string> = {
      [ID.topFile]: ID.topFile,
      [ID.xFile]: ID.a,
      [ID.yFile]: ID.a,
      [ID.zFile]: ID.a,
      [ID.wFile]: ID.b,
      [ID.topSym]: ID.topFile,
      [ID.xaSym]: ID.a,
      [ID.xbSym]: ID.a,
      [ID.zaSym]: ID.a,
      [ID.waSym]: ID.b,
    };
    for (let index = 0; index < graph.fileCount + graph.symbolCount; index++) {
      expect(idOf(pi(tree, frontier, index)), `π_F(${idOf(index)})`).toBe(expected[idOf(index)]);
    }
  });

  it("maps to the file grain once the directory is expanded", () => {
    const frontier = expand(tree, initialFrontier(), ID.a);
    expect(idOf(pi(tree, frontier, pointIndexOf(ID.xFile)))).toBe(ID.xFile);
    expect(idOf(pi(tree, frontier, pointIndexOf(ID.zFile)))).toBe(ID.sub);
    expect(idOf(pi(tree, frontier, pointIndexOf(ID.xaSym)))).toBe(ID.xFile);
    expect(idOf(pi(tree, frontier, pointIndexOf(ID.zaSym)))).toBe(ID.sub);
    expect(idOf(pi(tree, frontier, pointIndexOf(ID.waSym)))).toBe(ID.b);
    expect(idOf(pi(tree, frontier, pointIndexOf(ID.topSym)))).toBe(ID.topFile);
  });

  it("maps a symbol to itself only once its file is expanded", () => {
    let frontier = expand(tree, initialFrontier(), ID.a);
    frontier = expand(tree, frontier, ID.xFile);
    expect(idOf(pi(tree, frontier, pointIndexOf(ID.xaSym)))).toBe(ID.xaSym);
    expect(idOf(pi(tree, frontier, pointIndexOf(ID.xbSym)))).toBe(ID.xbSym);
    // A symbol in a file that is visible but not expanded still projects to the file.
    expect(idOf(pi(tree, frontier, pointIndexOf(ID.zaSym)))).toBe(ID.sub);
    expect(isVisible(tree, frontier, pointIndexOf(ID.xaSym))).toBe(true);
    expect(isVisible(tree, frontier, pointIndexOf(ID.zFile))).toBe(false);
    expect(isVisible(tree, frontier, pointIndexOf(ID.sub))).toBe(true);
  });
});

describe("π_F over the full preact population (VAL-FRONT-006)", () => {
  let graph: ViewerGraph;
  let tree: ReturnType<typeof containmentTree>;

  beforeAll(async () => {
    graph = await projectWorld(await readWorldDir(`${LAYOUT_WORLDS}/${PREACT}`));
    tree = containmentTree(graph);
  });

  /** Every one of the 1,875 points maps to a visible node with no visible node between. */
  function expectTotalDeepestMapping(frontier: VisibleFrontier): void {
    const visible = new Set(projectedNodes(tree, frontier).map((node) => node.index));
    expect(graph.pointCount).toBe(1875);
    for (let index = 0; index < graph.pointCount; index++) {
      // The root is the implicit top container, never a projected node itself.
      if (index === tree.root) continue;
      const target = pi(tree, frontier, index);
      expect(visible.has(target), `π_F(${graph.pointIds[index]}) is a projected node`).toBe(true);
      if (visible.has(index)) expect(target).toBe(index);
      // Deepest: no visible node sits strictly between the entity and its projection.
      let cursor = index;
      while (cursor !== target) {
        cursor = tree.containerOf[cursor] ?? -1;
        expect(cursor, `π_F(${graph.pointIds[index]}) stays inside the tree`).toBeGreaterThanOrEqual(0);
        if (cursor === target) break;
        expect(
          visible.has(cursor),
          `no visible node between ${graph.pointIds[index]} and its projection`,
        ).toBe(false);
      }
    }
  }

  it("assigns every entity to a projected node at three frontier states", () => {
    const initial = initialFrontier();
    // Default: every entity projects to a root-child directory or a root-anchored file.
    const topLevel = new Set(projectedNodes(tree, initial).map((node) => node.index));
    for (const node of projectedNodes(tree, initial)) {
      expect(tree.containerOf[node.index]).toBe(tree.root);
      expect(node.kind).not.toBe("symbol");
    }
    for (let index = 0; index < graph.fileCount + graph.symbolCount; index++) {
      expect(topLevel.has(pi(tree, initial, index))).toBe(true);
    }
    expectTotalDeepestMapping(initial);

    // One directory expanded: preact's "src" region.
    const src = projectedNodes(tree, initial).find((node) => node.path === "src");
    if (src === undefined) throw new Error("preact has a src region");
    const directoryExpanded = expand(tree, initial, src.id);
    expect(frontierLevel(tree, directoryExpanded)).toBe("directory");
    expectTotalDeepestMapping(directoryExpanded);

    // A file inside it expanded as well.
    const file = projectedNodes(tree, directoryExpanded).find(
      (node) => node.kind === "file" && node.container === src.id,
    );
    if (file === undefined) throw new Error("the expanded src region holds a file");
    const fileExpanded = expand(tree, directoryExpanded, file.id);
    expect(frontierLevel(tree, fileExpanded)).toBe("file");
    expectTotalDeepestMapping(fileExpanded);
    // Every symbol of that file now projects to itself.
    for (const child of tree.childrenOf[file.index] ?? []) {
      expect(pi(tree, fileExpanded, child)).toBe(child);
    }

    // Collapse back to the default reproduces the default mapping exactly.
    const collapsed = collapse(tree, collapse(tree, fileExpanded, file.id), src.id);
    expect(collapsed.expanded).toEqual([]);
    for (let index = 0; index < graph.fileCount + graph.symbolCount; index++) {
      expect(pi(tree, collapsed, index)).toBe(pi(tree, initial, index));
    }
  });
});
