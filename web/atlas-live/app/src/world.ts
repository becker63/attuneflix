/**
 * Loading the bundled default world in the browser. The same projection package
 * that Bazel runs under Node runs here: fetch the content-addressed Parquet
 * assets, decode with hyparquet, project into a ViewerGraph, lay it out, and build
 * the Arrow tables the renderer consumes. Nothing is inferred; provenance comes
 * from the shipped manifest entry.
 */
import { buildViewerArrow, type ViewerArrowTables } from "../../projection/src/arrow.ts";
import { projectTables, type ViewerGraph } from "../../projection/src/graph.ts";
import type { WorldManifest, WorldManifestEntry } from "../../projection/src/manifest.ts";
import { decodeWorldFiles, toArrayBuffer, type WorldFiles } from "../../projection/src/tables.ts";
import { computeLayout } from "./layout.ts";

export type { WorldManifest, WorldManifestEntry };

/**
 * The chosen default world: the smallest snapshot of `preactjs/preact` (a small,
 * medium-sized real world with all four relations well represented). Recorded
 * here so the choice is explicit and reproducible from the manifest.
 */
export const DEFAULT_REPOSITORY = "preactjs/preact";

export interface LoadedWorld {
  readonly entry: WorldManifestEntry;
  readonly graph: ViewerGraph;
  readonly tables: ViewerArrowTables;
  /** Interleaved [x0, y0, x1, y1, ...] positions, in renderer index order. */
  readonly xy: Float32Array;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isWorldManifest(value: unknown): value is WorldManifest {
  return isRecord(value) && value.version === 1 && Array.isArray(value.worlds);
}

export async function fetchManifest(url = "manifest.json"): Promise<WorldManifest> {
  const response = await fetch(url, { cache: "no-cache" });
  if (!response.ok) throw new Error(`manifest.json: HTTP ${response.status}`);
  const value: unknown = await response.json();
  if (!isWorldManifest(value)) throw new Error("manifest.json has an unexpected shape");
  return value;
}

export function chooseDefaultWorld(manifest: WorldManifest): WorldManifestEntry {
  const candidates = manifest.worlds.filter((world) => world.repository === DEFAULT_REPOSITORY);
  if (candidates.length === 0) {
    throw new Error(`manifest.json has no world for ${DEFAULT_REPOSITORY}`);
  }
  return candidates.reduce((best, world) => (world.counts.points < best.counts.points ? world : best));
}

async function fetchBytes(url: string): Promise<ArrayBuffer> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return toArrayBuffer(new Uint8Array(await response.arrayBuffer()));
}

async function fetchWorldFiles(entry: WorldManifestEntry): Promise<WorldFiles> {
  const { assets } = entry;
  const [metadata, entities, relations, locations] = await Promise.all([
    fetchBytes(assets.metadata),
    fetchBytes(assets.entities),
    fetchBytes(assets.relations),
    assets.locations === undefined ? Promise.resolve(undefined) : fetchBytes(assets.locations),
  ]);
  return locations === undefined
    ? { metadata, entities, relations }
    : { metadata, entities, relations, locations };
}

export async function loadWorld(entry: WorldManifestEntry): Promise<LoadedWorld> {
  const files = await fetchWorldFiles(entry);
  const decoded = await decodeWorldFiles(files);
  const graph = projectTables(decoded, entry.sha256);
  const xy = computeLayout(graph);
  const tables = buildViewerArrow(graph, { xy });
  return { entry, graph, tables, xy };
}
