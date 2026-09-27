/**
 * Applies the current emphasis (hovered neighbourhood unioned with the pinned
 * selection) to the one Cosmograph instance through its selection/greyout
 * channel. The emphasised sets are computed from the projected adjacency, so
 * what the renderer greys out is exactly what the diagnostics hook reports.
 *
 * The last emphasised set is kept here so a graph rebuild (which clears the
 * renderer's selection) can re-apply it without a React re-render.
 */
import { mountedCosmograph } from "./graphHandlers.ts";

export interface Emphasis {
  readonly points: readonly number[];
  readonly links: readonly number[];
}

const EMPTY: Emphasis = { points: [], links: [] };

let current: Emphasis = EMPTY;

/** Replaces the emphasised set and applies it to the renderer. */
export function setEmphasis(next: Emphasis): void {
  current = next;
  applyEmphasis();
}

/** Re-applies the last emphasised set (after a graph rebuild). */
export function reapplyEmphasis(): void {
  applyEmphasis();
}

function applyEmphasis(): void {
  const instance = mountedCosmograph();
  if (instance === undefined) return;
  if (current.points.length === 0) {
    instance.unselectAllPoints();
    return;
  }
  // selectConnectedPoints is false: the emphasised set is exactly the computed
  // neighbourhood, not one expandable hop of the renderer's own adjacency.
  instance.selectPoints([...current.points], false, false);
  if (current.links.length > 0) instance.selectLinks([...current.links], true, false);
}
