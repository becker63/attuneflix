/**
 * The visible frontier: the expansion state of the hierarchical view, and the
 * derived visibility of every point of the admitted world.
 *
 * A `VisibleFrontier` is a small immutable value: the set of expanded container
 * ids plus a revision counter that advances on every state-changing transition.
 * The root directory is permanently expanded and never listed. Everything else
 * — which points are visible, what π_F maps to — is derived, never stored here.
 *
 * Visibility rule: a point is visible when its container is expanded (the root
 * counts as expanded). So the default frontier shows exactly the root's child
 * directories and the root-anchored files; expanding a directory reveals its
 * own files and child directories at their pre-assigned slots; expanding a file
 * reveals its symbols. A container stays visible while expanded.
 *
 * π_F (the projection of one raw entity): the entity itself when it is visible,
 * otherwise its nearest visible ancestor — the DEEPEST visible ancestor, since
 * the walk stops at the first visible point on the container chain.
 *
 * Collapse is the exact inverse of expansion: collapsing a container removes it
 * and every expanded descendant from the expanded set, restoring the projection
 * that preceded the expansion.
 */
import type { ViewerGraph } from "../../../projection/src/graph.ts";
import { isContainer, type ContainmentTree } from "./containment.ts";

/** The semantic zoom level the expansion state has reached. */
export type FrontierLevel = "repository" | "directory" | "file" | "symbol";

export interface VisibleFrontier {
  /**
   * Expanded container point ids, sorted by point index (canonical order, so
   * equal states have equal arrays). Never contains the root or a symbol.
   */
  readonly expanded: readonly string[];
  /** Count of state-changing expand/collapse transitions applied so far. */
  readonly revision: number;
}

/** The empty frontier: nothing expanded below the root. */
export function initialFrontier(): VisibleFrontier {
  return { expanded: [], revision: 0 };
}

export type ProjectedNodeKind = "directory" | "file" | "symbol";

/** One visible member of the frontier: a region block, a file, or a symbol. */
export interface ProjectedNode {
  /** The graph's point id ("file:3", "symbol:17", "location:9"). */
  readonly id: string;
  /** Renderer/evidence point index in the ViewerGraph. */
  readonly index: number;
  readonly kind: ProjectedNodeKind;
  /** Human identity: the admitted path (files/directories) or name (symbols). */
  readonly label: string;
  readonly path: string | null;
  readonly name: string | null;
  /** Containment depth (root children sit at depth 1). */
  readonly depth: number;
  /** Point id of the containing point (the root for top-level nodes). */
  readonly container: string;
  /** Whether this node is a container the frontier currently has expanded. */
  readonly expanded: boolean;
}

function pointIdOf(graph: ViewerGraph, index: number): string {
  const id = graph.pointIds[index];
  if (id === undefined) throw new Error(`point index out of range: ${index}`);
  return id;
}

function resolveContainer(tree: ContainmentTree, id: string, what: string): number {
  const index = tree.graph.indexById.get(id);
  if (index === undefined) throw new Error(`unknown ${what} id: ${id}`);
  if (!isContainer(tree, index)) throw new Error(`cannot ${what} a non-container: ${id}`);
  return index;
}

/** Expanded set as a point-index mask; the root is implicitly expanded. */
function expandedMask(tree: ContainmentTree, frontier: VisibleFrontier): Uint8Array {
  const mask = new Uint8Array(tree.graph.pointCount);
  for (const id of frontier.expanded) {
    const index = tree.graph.indexById.get(id);
    if (index === undefined) throw new Error(`frontier carries an id outside this world: ${id}`);
    mask[index] = 1;
  }
  mask[tree.root] = 1;
  return mask;
}

function visibleWith(tree: ContainmentTree, expanded: Uint8Array, index: number): boolean {
  if (index === tree.root) return false;
  const container = tree.containerOf[index] ?? -1;
  return container >= 0 && expanded[container] === 1;
}

/** Whether the point is a visible member of the frontier. */
export function isVisible(tree: ContainmentTree, frontier: VisibleFrontier, index: number): boolean {
  return visibleWith(tree, expandedMask(tree, frontier), index);
}

/**
 * π_F(index): the point itself when visible, else its deepest visible ancestor.
 * Falls back to the root only for malformed input; over an admitted world every
 * entity's chain meets a root child (always visible) or a root-anchored file
 * (visible) first.
 */
export function pi(tree: ContainmentTree, frontier: VisibleFrontier, index: number): number {
  const expanded = expandedMask(tree, frontier);
  let point = index;
  while (point !== tree.root && !visibleWith(tree, expanded, point)) {
    point = tree.containerOf[point] ?? tree.root;
  }
  return point;
}

/** Expands a container, revealing its children. No-op for the root or an already-expanded id. */
export function expand(tree: ContainmentTree, frontier: VisibleFrontier, id: string): VisibleFrontier {
  const index = resolveContainer(tree, id, "expand");
  if (index === tree.root || frontier.expanded.includes(id)) return frontier;
  const expanded = [...frontier.expanded, id].toSorted(
    (a, b) => (tree.graph.indexById.get(a) ?? 0) - (tree.graph.indexById.get(b) ?? 0),
  );
  return { expanded, revision: frontier.revision + 1 };
}

/**
 * Collapses a container: removes it and every expanded descendant, the exact
 * inverse of the expansions that revealed them. No-op for the root or an id
 * whose subtree holds no expanded container.
 */
export function collapse(tree: ContainmentTree, frontier: VisibleFrontier, id: string): VisibleFrontier {
  const index = resolveContainer(tree, id, "collapse");
  if (index === tree.root) return frontier;
  const mask = expandedMask(tree, frontier);
  mask[tree.root] = 0;
  const removed = new Set<number>();
  const stack = [index];
  for (let head = 0; head < stack.length; head++) {
    const point = stack[head] ?? index;
    if (mask[point] === 1) removed.add(point);
    for (const child of tree.childrenOf[point] ?? []) stack.push(child);
  }
  if (removed.size === 0) return frontier;
  const expanded = frontier.expanded.filter((candidate) => {
    const candidateIndex = tree.graph.indexById.get(candidate) ?? -1;
    return !removed.has(candidateIndex);
  });
  return { expanded, revision: frontier.revision + 1 };
}

/** The visible members of the frontier, in ascending point-index order. */
export function projectedNodes(tree: ContainmentTree, frontier: VisibleFrontier): ProjectedNode[] {
  const { graph } = tree;
  const expanded = expandedMask(tree, frontier);
  const nodes: ProjectedNode[] = [];
  for (let index = 0; index < graph.pointCount; index++) {
    if (!visibleWith(tree, expanded, index)) continue;
    const container = tree.containerOf[index] ?? tree.root;
    const kind: ProjectedNodeKind =
      index < graph.fileCount ? "file" : index < graph.fileCount + graph.symbolCount ? "symbol" : "directory";
    nodes.push({
      id: pointIdOf(graph, index),
      index,
      kind,
      label: graph.pointLabels[index] ?? "",
      path: graph.pointPaths[index] ?? null,
      name: graph.pointNames[index] ?? null,
      depth: tree.depthOf[index] ?? 0,
      container: pointIdOf(graph, container),
      expanded: isContainer(tree, index) && index !== tree.root && expanded[index] === 1,
    });
  }
  return nodes;
}

/**
 * The coarsest-to-finest grain the expansion state has reached: `repository`
 * while nothing is expanded, `directory` once a directory is expanded, `file`
 * once a file is expanded. (`symbol` is reserved for the symbol-focus drill
 * states of later features; revealing symbols happens by expanding a file,
 * which is file grain.)
 */
export function frontierLevel(tree: ContainmentTree, frontier: VisibleFrontier): FrontierLevel {
  let level: FrontierLevel = "repository";
  for (const id of frontier.expanded) {
    const index = tree.graph.indexById.get(id);
    if (index === undefined) throw new Error(`frontier carries an id outside this world: ${id}`);
    if (index < tree.graph.fileCount) return "file";
    level = "directory";
  }
  return level;
}
