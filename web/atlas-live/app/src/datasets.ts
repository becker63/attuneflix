/**
 * The dataset picker's data model: the 78 census worlds plus the separately
 * labelled synthetic stress fixture, derived from the shipped `manifest.json`.
 * Pure functions only, so the label, short revision and ordering rules are
 * unit-testable without React or the renderer.
 */
import type { WorldManifest, WorldManifestEntry } from "./world.ts";

/**
 * Above this many links a single SwiftShader redraw of the drawn links is a
 * multi-second main-thread long task (research: 3.6-8.7 s at 50k, 0.4-1.0 s at
 * 2k-5k). Datasets over the budget keep every point, link and adjacency in the
 * graph and stay interactive, but the renderer does not draw their links; the
 * choice is reported as `renderLinks` in `window.__atlasLive` and documented in
 * the README. The 78 words keep their links except the very largest.
 */
export const LINK_RENDER_BUDGET = 10_000;

export interface DatasetOption {
  /** The select value: the manifest snapshot id. */
  readonly value: string;
  readonly entry: WorldManifestEntry;
  /** The repository name, or `"synthetic"` for the stress fixture. */
  readonly repository: string;
  /** The first 8 characters of the base revision, or `"synthetic"`. */
  readonly revision: string;
  readonly synthetic: boolean;
  /** The picker's primary line: repository + short revision, or the synthetic label. */
  readonly label: string;
  /** The picker's secondary line: the projected counts. */
  readonly detail: string;
}

export function shortRevision(baseRevision: string): string {
  return baseRevision.slice(0, 8);
}

function optionFor(entry: WorldManifestEntry): DatasetOption {
  const revision = shortRevision(entry.baseRevision);
  const counts = `${entry.counts.points} points · ${entry.counts.links} links`;
  return {
    value: entry.snapshotId,
    entry,
    repository: entry.repository,
    revision,
    synthetic: entry.synthetic,
    label: entry.synthetic ? "synthetic stress fixture" : `${entry.repository} @ ${revision}`,
    // A world that ships a families export says so; the others render exactly as before.
    detail: entry.assets.families === undefined ? counts : `${counts} · families`,
  };
}

/**
 * The picker's options: exactly the 78 worlds (manifest order, sorted by snapshot
 * id), then the synthetic stress fixture last. The fixture is never counted among
 * the 78.
 */
export function datasetOptions(manifest: WorldManifest): DatasetOption[] {
  const worlds = manifest.worlds.map(optionFor);
  return manifest.synthetic === null ? worlds : [...worlds, optionFor(manifest.synthetic)];
}

/** A human label for progress and error text: the world, or the synthetic fixture. */
export function datasetLabel(option: DatasetOption): string {
  return option.synthetic ? "the synthetic stress fixture" : `${option.repository}@${option.revision}`;
}

/** Whether the renderer draws this dataset's links (see LINK_RENDER_BUDGET). */
export function shouldRenderLinks(counts: { readonly links: number }): boolean {
  return counts.links <= LINK_RENDER_BUDGET;
}
