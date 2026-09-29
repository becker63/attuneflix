/**
 * The dataset picker's data model: the 78 census worlds, one pinned self world, and the separately
 * labelled synthetic stress fixture, derived from the shipped `manifest.json`.
 * Pure functions only, so the label, short revision and ordering rules are
 * unit-testable without React or the renderer.
 */
import type { WorldManifest, WorldManifestEntry } from "./world.ts";

/**
 * Above this many links a single SwiftShader redraw of the drawn links is a
 * multi-second main-thread long task (research: 3.6-8.7 s at 50k, 0.4-1.0 s at
 * 2k-5k). Datasets over the budget keep every point, link and adjacency in the
 * graph. Their fitted overview stays quiet; zooming selects a bounded set of
 * exact projected connections near the camera. `renderLinks` in the diagnostics
 * hook reports whether the raw world fits the unrestricted budget at overview.
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
    detail: [
      counts,
      entry.familySummary === undefined ? null : `${entry.familySummary.count} families`,
      entry.physicalSummary === undefined
        ? null
        : `${(entry.physicalSummary.reuseFraction * 100).toFixed(2)}% reuse`,
    ]
      .filter((part) => part !== null)
      .join(" · "),
  };
}

/**
 * The picker's options: manifest worlds in snapshot-id order, then the
 * synthetic stress fixture last. The fixture is not a repository.
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
