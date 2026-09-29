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
import { legendEntries, type LegendEntry } from "./vocabulary.ts";

/** Renderer index of the hovered point, or null when nothing is hovered. */
export const hoveredIndexAtom = atom<number | null>(null);

/** The loaded session's families layer, or null for a world without families data. */
export const familiesAtom = atom<WorldFamilies | null>(null);

/** One scalar shades the same family-informed structural graph at a time. */
export type MeasurementMode = "structure" | "physical" | "locality" | "reach";
export const measurementModeAtom = atom<MeasurementMode>("physical");
/** Static structural separation is a view mode; physical lightness remains independent. */
export const landscapeModeAtom = atom<"structure" | "parallelism">("structure");
/** The same graph offers either pair separation or measured anchor evidence. */
export const landscapeViewAtom = atom<"separation" | "anchors">("separation");
export const selectedAnchorPathAtom = atom<string | null>(null);
export const landscapeDepthAtom = atom<1 | 2 | 3>(3);
export const landscapeThresholdAtom = atom<number>(0.25);
export const landscapeOriginsAtom = atom<{ readonly a: string | null; readonly b: string | null }>({
  a: null,
  b: null,
});
export const selectLandscapeOriginAtom = atom(
  null,
  (get, set, selection: { id: string; additive: boolean }) => {
    const current = get(landscapeOriginsAtom);
    set(
      landscapeOriginsAtom,
      selection.additive
        ? {
            a: current.a ?? selection.id,
            b: current.a === null ? null : selection.id === current.a ? null : selection.id,
          }
        : { a: selection.id, b: null },
    );
  },
);
export const measurementRevisionAtom = atom<number>(0);
export const setMeasurementModeAtom = atom(null, (get, set, mode: MeasurementMode) => {
  if (get(measurementModeAtom) === mode) return;
  set(measurementModeAtom, mode);
  set(measurementRevisionAtom, get(measurementRevisionAtom) + 1);
});

/** The drilled-down family edge ordinal, or null when nothing is drilled. */
export const drilledFamilyEdgeAtom = atom<number | null>(null);

/** One projected wire in the current view; the revision prevents stale drills. */
export const selectedWireAtom = atom<{ readonly index: number; readonly viewRevision: number } | null>(null);
export const wireConstituentsAtom = atom<boolean>(false);

export const selectWireAtom = atom(
  null,
  (_get, set, selection: { index: number; viewRevision: number } | null) => {
    set(selectedWireAtom, selection);
    set(wireConstituentsAtom, false);
  },
);

export const showWireConstituentsAtom = atom(null, (_get, set, show: boolean) => {
  set(wireConstituentsAtom, show);
});

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
  set(selectedWireAtom, null);
  set(wireConstituentsAtom, false);
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

/** Family hue is always part of the structural graph when families exist. */
export const activeLegendAtom = atom<readonly LegendEntry[]>((get) =>
  legendEntries(get(familiesAtom) !== null, get(visibleRelationSetAtom), { includeDisabledRelations: true }),
);
