/**
 * The containment tree over the admitted world: the single spatial hierarchy the
 * frontier projection and the region metrics read. This is the tree view of the
 * same decomposition the structural layout computes (`decomposeRepository` in
 * ../structure.ts — reused, not reinvented): directories nest by their `parent`
 * edges, files belong to their containing directory (path-derived, root as the
 * fallback), symbols belong to their defining file (the `defines` edge, with the
 * same-path file and then the root as fallbacks).
 *
 * The tree is evidence-derived and view-independent: it reads the immutable
 * ViewerGraph once and never changes under expansion, filters, or overlays.
 * `parent` and `defines` facts appear here as structure only — never as wires.
 *
 * Representation: every array is indexed by the graph's point index (files,
 * then symbols, then directories), so tree walks are pointer chasing with no
 * string lookups. The root directory is the unique point with no container.
 */
import type { ViewerGraph } from "../../../projection/src/graph.ts";
import { decomposeRepository, directoryPointIndex } from "../structure.ts";

export interface ContainmentTree {
  /** The admitted evidence this tree is built over (never mutated). */
  readonly graph: ViewerGraph;
  /** Point index of the root directory (the only point whose container is -1). */
  readonly root: number;
  /**
   * Point index -> containing point index; -1 for the root. A file's container
   * is its directory; a symbol's container is its defining file (or the root
   * when no file defines it); a directory's container is its parent directory.
   */
  readonly containerOf: Int32Array;
  /** Container point index -> member point indices, ascending. */
  readonly childrenOf: readonly (readonly number[])[];
  /** Point index -> containment depth (root = 0). Total: every point is placed. */
  readonly depthOf: Int32Array;
}

/** A container is a directory or a file (files contain their symbols). */
export function isContainer(tree: ContainmentTree, index: number): boolean {
  return index < tree.graph.fileCount || index >= tree.graph.fileCount + tree.graph.symbolCount;
}

/** Builds the containment tree of a world. Pure; prefer the memoized `containmentTree`. */
export function buildContainmentTree(graph: ViewerGraph): ContainmentTree {
  const structure = decomposeRepository(graph);
  const { fileCount, symbolCount, directoryCount, pointCount } = graph;
  const root = directoryPointIndex(graph, structure.root);

  const containerOf = new Int32Array(pointCount).fill(-1);
  for (let ordinal = 0; ordinal < directoryCount; ordinal++) {
    const point = directoryPointIndex(graph, ordinal);
    containerOf[point] =
      ordinal === structure.root
        ? -1
        : directoryPointIndex(graph, structure.directoryParent[ordinal] ?? structure.root);
  }
  for (let file = 0; file < fileCount; file++) {
    containerOf[file] = directoryPointIndex(graph, structure.fileDirectory[file] ?? structure.root);
  }
  for (let symbol = 0; symbol < symbolCount; symbol++) {
    const file = structure.symbolFile[symbol] ?? -1;
    containerOf[fileCount + symbol] = file >= 0 ? file : root;
  }

  const childrenOf: number[][] = Array.from({ length: pointCount }, () => []);
  for (let index = 0; index < pointCount; index++) {
    const container = containerOf[index] ?? -1;
    if (container >= 0) childrenOf[container]?.push(index);
  }

  // Breadth-first from the root assigns every depth. The tree is total:
  // decomposeRepository attaches unreachable directories to the root, every
  // file has a directory, and every symbol has a file or the root.
  const depthOf = new Int32Array(pointCount);
  const queue = [root];
  for (let head = 0; head < queue.length; head++) {
    const point = queue[head] ?? root;
    for (const child of childrenOf[point] ?? []) {
      depthOf[child] = (depthOf[point] ?? 0) + 1;
      queue.push(child);
    }
  }
  return { graph, root, containerOf, childrenOf, depthOf };
}

const memo = new WeakMap<ViewerGraph, ContainmentTree>();

/** The containment tree of a world, computed at most once per ViewerGraph. */
export function containmentTree(graph: ViewerGraph): ContainmentTree {
  const cached = memo.get(graph);
  if (cached !== undefined) return cached;
  const tree = buildContainmentTree(graph);
  memo.set(graph, tree);
  return tree;
}
