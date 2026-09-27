/**
 * Pure selection and relation-filter logic, independent of React, Jotai and the
 * renderer. Atoms in `atoms.ts` hold the results; these functions are the only
 * place the semantics live, so they can be unit-tested directly.
 *
 * The relation filter is a bitmask over the canonical relation order, so
 * enabling or disabling a relation never touches the projected topology: it only
 * selects which CSR adjacency the derived neighbourhood reads and which links
 * the renderer draws.
 */
import type { ViewerGraph } from "../../projection/src/graph.ts";
import { RELATION_ORDER, type Relation } from "../../projection/src/relation.ts";

/** The pinned selection: namespaced point ids (`domain:entity_id`), unordered. */
export type Selection = ReadonlySet<string>;

export const EMPTY_SELECTION: Selection = new Set<string>();

/** A plain click pins exactly the clicked entity. */
export function selectOnly(id: string): Selection {
  return new Set([id]);
}

/** A modifier click adds the entity, or removes it when already pinned. */
export function toggleSelection(selected: Selection, id: string): Selection {
  const next = new Set(selected);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  return next;
}

/** Click semantics: `additive` is the documented modifier (shift/ctrl/meta). */
export function clickSelection(selected: Selection, id: string, additive: boolean): Selection {
  return additive ? toggleSelection(selected, id) : selectOnly(id);
}

/** Selection ids in a stable (sorted) order, for the diagnostics hook. */
export function sortedSelection(selected: Selection): string[] {
  return [...selected].toSorted();
}

/**
 * Renderer indices of the selected entities, ascending. Ids the graph does not
 * contain are ignored (never fabricated), so a stale id can never resolve to
 * another entity.
 */
export function selectionIndices(graph: ViewerGraph | null, selected: Selection): number[] {
  if (graph === null) return [];
  const indices: number[] = [];
  for (const id of selected) {
    const index = graph.indexById.get(id);
    if (index !== undefined) indices.push(index);
  }
  return indices.toSorted((a, b) => a - b);
}

/** Drops selected ids the new graph does not contain (called on a dataset change). */
export function pruneSelection(selected: Selection, graph: ViewerGraph): Selection {
  const kept = [...selected].filter((id) => graph.indexById.has(id));
  return kept.length === selected.size ? selected : new Set(kept);
}

/** Bitmask over `RELATION_ORDER`; a set bit means the relation is enabled. */
export type RelationMask = number;

export const ALL_RELATIONS_MASK: RelationMask = RELATION_ORDER.reduce(
  (mask, relation, rank) => mask | (1 << rank),
  0,
);

export function relationMask(relations: readonly Relation[]): RelationMask {
  let mask = 0;
  for (const relation of relations) mask |= 1 << RELATION_ORDER.indexOf(relation);
  return mask;
}

/** Enabled relations in canonical order. */
export function maskedRelations(mask: RelationMask): Relation[] {
  return RELATION_ORDER.filter((_relation, rank) => (mask & (1 << rank)) !== 0);
}

export function isRelationEnabled(mask: RelationMask, relation: Relation): boolean {
  return (mask & (1 << RELATION_ORDER.indexOf(relation))) !== 0;
}

export function toggleRelation(mask: RelationMask, relation: Relation): RelationMask {
  return mask ^ (1 << RELATION_ORDER.indexOf(relation));
}

/** Neighbourhood depth bounds, per the validation contract (1..3). */
export const MIN_DEPTH = 1;
export const MAX_DEPTH = 3;
export const DEFAULT_DEPTH = 1;

/** Clamps a depth control value into `[MIN_DEPTH, MAX_DEPTH]` (non-finite → default). */
export function clampDepth(value: number): number {
  if (!Number.isFinite(value)) return DEFAULT_DEPTH;
  return Math.min(MAX_DEPTH, Math.max(MIN_DEPTH, Math.trunc(value)));
}
