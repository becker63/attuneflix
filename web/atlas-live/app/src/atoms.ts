/**
 * The minimal Jotai state model for this slice. Atoms hold identities and
 * revision counters only; the graph data lives in GraphSession and typed arrays.
 * There is no atom (and no component) per entity.
 */
import { atom } from "jotai";

import { EMPTY_HIGHLIGHT, type Highlight } from "./neighbourhood.ts";
import type { OverlayName } from "./vocabulary.ts";

/** Renderer index of the hovered point, or null when nothing is hovered. */
export const hoveredIndexAtom = atom<number | null>(null);

/** The computed depth-1 neighbourhood of the hovered point. */
export const highlightedAtom = atom<Highlight>(EMPTY_HIGHLIGHT);

/** The active node-colour overlay. Slice A ships only the Structure overlay. */
export const overlayAtom = atom<OverlayName>("structure");

/** Bumped when a new GraphSession replaces the previous one. */
export const sessionRevisionAtom = atom<number>(0);

/** Bumped when the projected topology changes (never on an overlay change). */
export const topologyRevisionAtom = atom<number>(0);

/** True once the renderer has rebuilt the graph from the inserted tables. */
export const readyAtom = atom<boolean>(false);
