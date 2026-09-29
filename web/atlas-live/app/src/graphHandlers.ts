/**
 * Stable module-level renderer callbacks. Cosmograph's React wrapper compares
 * every prop by identity (functions by reference) and rebuilds the whole config
 * when one changes, so hover and rebuild handlers must never be recreated per
 * render. These constants delegate to a handler object that the mounted
 * GraphView registers once per session.
 *
 * `onMount` is also stable here; the mounted instance is captured through it
 * rather than through a React `ref`, which the memoized wrapper did not populate.
 */
import type { CosmographRef } from "@cosmograph/react";

export type MountedCosmograph = NonNullable<CosmographRef>;

export interface GraphHandlers {
  enter(index: number): void;
  leave(): void;
  click(index: number, additive: boolean): void;
  /** A link row was clicked (an exact link or an appended family edge row). */
  linkClick(linkIndex: number): void;
  background(): void;
  rebuilt(stats: { readonly pointsCount: number; readonly linksCount: number }): void;
  zoom(): void;
}

let handlers: GraphHandlers | null = null;
let mounted: MountedCosmograph | undefined;

export function setGraphHandlers(next: GraphHandlers | null): void {
  handlers = next;
}

/** The live renderer instance, captured through the stable `onMount` prop. */
export function mountedCosmograph(): MountedCosmograph | undefined {
  return mounted;
}

export function clearMountedCosmograph(): void {
  mounted = undefined;
}

export function onPointMouseOver(index: number): void {
  handlers?.enter(index);
}

export function onPointMouseOut(): void {
  handlers?.leave();
}

/**
 * A click pins a selection. Shift, Ctrl or Meta is the documented modifier that
 * adds/removes instead of replacing; the renderer's own selection-on-click is
 * disabled, so this handler is the only writer of the selection.
 */
export function onPointClick(index: number, _pointPosition: readonly number[], event: MouseEvent): void {
  handlers?.click(index, event.shiftKey || event.ctrlKey || event.metaKey);
}

/** An empty-canvas click clears the pinned selection. */
export function onBackgroundClick(): void {
  handlers?.background();
}

/**
 * A link click drills into a family edge (the session resolves whether the row
 * is a family edge). The renderer's own link selection is disabled, so this
 * handler is the only drill-down writer.
 */
export function onLinkClick(linkIndex: number): void {
  handlers?.linkClick(linkIndex);
}

export function onGraphRebuilt(stats: { readonly pointsCount: number; readonly linksCount: number }): void {
  handlers?.rebuilt(stats);
}

export function onZoom(): void {
  handlers?.zoom();
}

export function onGraphMount(instance: MountedCosmograph): void {
  mounted = instance;
}
