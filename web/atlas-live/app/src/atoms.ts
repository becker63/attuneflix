/**
 * The Jotai state model for the viewer. Atoms hold identities (ids, masks,
 * counters) only; the graph data lives in GraphSession / the ViewerGraph and the
 * large per-entity state never becomes an atom. There is no atom (and no
 * component) per entity.
 *
 * The derived atoms below are the single source of every view decision that
 * depends on more than one atom: the hovered neighbourhood, the selection's
 * incident edges, the visible relation set, the active legend, the selection
 * provenance, and the set the renderer emphasises.
 */
import { atom } from "jotai";

import { DOMAIN_ORDER, type Domain } from "../../projection/src/domain.ts";
import type { WorldFamilies } from "../../projection/src/families.ts";
import type { ViewerGraph } from "../../projection/src/graph.ts";
import type { Relation } from "../../projection/src/relation.ts";
import {
  EMPTY_HIGHLIGHT,
  incidentCounts,
  incidentLinks,
  mergeHighlights,
  multiSourceHighlight,
  neighbourhoodAtDepth,
  type Highlight,
  type IncidentCounts,
} from "./neighbourhood.ts";
import {
  ALL_RELATIONS_MASK,
  DEFAULT_DEPTH,
  EMPTY_SELECTION,
  clampDepth,
  clickSelection,
  maskedRelations,
  pruneSelection,
  selectOnly,
  selectionIndices,
  toggleRelation,
  type RelationMask,
  type Selection,
} from "./selection.ts";
import { legendEntries, type LegendEntry, type OverlayName } from "./vocabulary.ts";

/** Renderer index of the hovered point, or null when nothing is hovered. */
export const hoveredIndexAtom = atom<number | null>(null);

/** The active node-colour overlay. "families" is selectable only while the session has families data. */
export const overlayAtom = atom<OverlayName>("structure");

/** The loaded session's families layer, or null for a world without families data. */
export const familiesAtom = atom<WorldFamilies | null>(null);

/** Bumped on every overlay change (a view revision, never a topology one). */
export const overlayRevisionAtom = atom<number>(0);

/** The drilled-down family edge ordinal, or null when nothing is drilled. */
export const drilledFamilyEdgeAtom = atom<number | null>(null);

/** The pinned selection: point ids, independent of what is hovered. */
export const selectedAtom = atom<Selection>(EMPTY_SELECTION);

/** Which relations are enabled; toggling one never changes the topology. */
export const relationMaskAtom = atom<RelationMask>(ALL_RELATIONS_MASK);

/** Hover/selection neighbourhood depth, 1..3. */
export const neighbourhoodDepthAtom = atom<number>(DEFAULT_DEPTH);

/** Bumped on every relation-filter change (a view revision, not a topology one). */
export const filterRevisionAtom = atom<number>(0);

/** The loaded graph's identity. Set by `adoptGraphAtom`; never per-entity state. */
export const graphAtom = atom<ViewerGraph | null>(null);

/** Bumped when a new GraphSession replaces the previous one. */
export const sessionRevisionAtom = atom<number>(0);

/** Bumped when the projected topology changes (never on an overlay change). */
export const topologyRevisionAtom = atom<number>(0);

/** True once the renderer has rebuilt the graph from the inserted tables. */
export const readyAtom = atom<boolean>(false);

/**
 * Adopts the graph of a newly loaded session. A pinned selection survives only
 * for the ids the new graph actually contains; ids it lacks are dropped.
 */
export const adoptGraphAtom = atom(null, (get, set, graph: ViewerGraph) => {
  set(graphAtom, graph);
  set(selectedAtom, pruneSelection(get(selectedAtom), graph));
});

/** Replaces the enabled relation set and bumps the filter revision. */
export const setRelationMaskAtom = atom(null, (get, set, mask: RelationMask) => {
  set(relationMaskAtom, mask);
  set(filterRevisionAtom, get(filterRevisionAtom) + 1);
});

/** Toggles one relation and bumps the filter revision. */
export const toggleRelationAtom = atom(null, (get, set, relation: Relation) => {
  set(relationMaskAtom, toggleRelation(get(relationMaskAtom), relation));
  set(filterRevisionAtom, get(filterRevisionAtom) + 1);
});

/**
 * Sets the active overlay. Choosing "families" without families data is a
 * no-op (the guard keeps a families-less world's rendering identical); leaving
 * the families overlay or switching overlays clears any family drill-down.
 */
export const setOverlayAtom = atom(null, (get, set, overlay: OverlayName) => {
  if (overlay === "families" && get(familiesAtom) === null) return;
  if (get(overlayAtom) === overlay) return;
  set(overlayAtom, overlay);
  set(overlayRevisionAtom, get(overlayRevisionAtom) + 1);
  set(drilledFamilyEdgeAtom, null);
});

/** Drills into one family edge (its contributing exact edges reappear), or clears the drill-down with null. */
export const drillFamilyEdgeAtom = atom(null, (_get, set, ordinal: number | null) => {
  set(drilledFamilyEdgeAtom, ordinal);
});

/** Sets the neighbourhood depth, clamped to 1..3. */
export const setDepthAtom = atom(null, (_get, set, depth: number) => {
  set(neighbourhoodDepthAtom, clampDepth(depth));
});

/** Adds or removes one entity (the documented modifier-click behaviour). */
export const toggleSelectedAtom = atom(null, (get, set, id: string) => {
  set(selectedAtom, clickSelection(get(selectedAtom), id, true));
});

/** Pins exactly one entity (a plain click). */
export const selectOnlyAtom = atom(null, (_get, set, id: string) => {
  set(selectedAtom, selectOnly(id));
});

/** Clears the pinned selection (empty-canvas click or Escape). */
export const clearSelectionAtom = atom(null, (_get, set) => {
  set(selectedAtom, EMPTY_SELECTION);
});

/** Enabled relations, in canonical order. */
export const visibleRelationSetAtom = atom<readonly Relation[]>((get) =>
  maskedRelations(get(relationMaskAtom)),
);

/** Renderer indices of the pinned selection that exist in the loaded graph. */
export const selectedIndicesAtom = atom<readonly number[]>((get) =>
  selectionIndices(get(graphAtom), get(selectedAtom)),
);

/** The hovered point's neighbourhood under the active filter and depth. */
export const hoveredNeighbourhoodAtom = atom<Highlight>((get) => {
  const graph = get(graphAtom);
  const index = get(hoveredIndexAtom);
  if (graph === null || index === null) return EMPTY_HIGHLIGHT;
  return neighbourhoodAtDepth(graph, index, get(visibleRelationSetAtom), get(neighbourhoodDepthAtom));
});

/** The union of the pinned selection's neighbourhoods under filter and depth. */
export const selectionHighlightAtom = atom<Highlight>((get) => {
  const graph = get(graphAtom);
  if (graph === null) return EMPTY_HIGHLIGHT;
  return multiSourceHighlight(
    graph,
    get(selectedIndicesAtom),
    get(visibleRelationSetAtom),
    get(neighbourhoodDepthAtom),
  );
});

/**
 * The set the renderer emphasises: the hovered neighbourhood unioned with the
 * pinned selection's, so a pinned selection stays emphasised while hovering and
 * hover emphasis never hides it.
 */
export const emphasisAtom = atom<Highlight>((get) =>
  mergeHighlights(get(hoveredNeighbourhoodAtom), get(selectionHighlightAtom)),
);

/** Incident link indices of the pinned selection, under the enabled relations. */
export const incidentEdgesAtom = atom<readonly number[]>((get) => {
  const graph = get(graphAtom);
  if (graph === null) return [];
  return incidentLinks(graph, get(selectedIndicesAtom), get(visibleRelationSetAtom));
});

/** The entity the details panel inspects: the selection, else the hovered point. */
export const inspectedIndexAtom = atom<number | null>((get) => {
  const indices = get(selectedIndicesAtom);
  const last = indices[indices.length - 1];
  return last ?? get(hoveredIndexAtom);
});

/** One provenance record per pinned entity, in ascending renderer-index order. */
export interface SelectedRecord {
  readonly id: string;
  readonly domain: Domain | null;
  readonly path: string | null;
  readonly name: string | null;
  readonly counts: IncidentCounts;
}

export const selectedProvenanceAtom = atom<readonly SelectedRecord[]>((get) => {
  const graph = get(graphAtom);
  if (graph === null) return [];
  return get(selectedIndicesAtom).map((index) => ({
    id: graph.pointIds[index] ?? "",
    domain: DOMAIN_ORDER[graph.pointDomains[index] ?? -1] ?? null,
    path: graph.pointPaths[index] ?? null,
    name: graph.pointNames[index] ?? null,
    counts: incidentCounts(graph, index),
  }));
});

/** The legend of the active overlay and filter, with disabled relations marked. */
export const activeLegendAtom = atom<readonly LegendEntry[]>((get) =>
  legendEntries(get(overlayAtom), get(visibleRelationSetAtom), { includeDisabledRelations: true }),
);
