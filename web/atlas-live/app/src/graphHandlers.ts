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

export function onGraphRebuilt(stats: { readonly pointsCount: number; readonly linksCount: number }): void {
  handlers?.rebuilt(stats);
}

export function onZoom(): void {
  handlers?.zoom();
}

export function onGraphMount(instance: MountedCosmograph): void {
  mounted = instance;
}
