/**
 * Loading the bundled default world in the browser. The same projection package
 * that Bazel runs under Node runs here: fetch the content-addressed Parquet
 * assets, decode with hyparquet, project into a ViewerGraph, compute its
 * structural layout, and build the Arrow tables the renderer consumes. Nothing is
 * inferred; provenance comes from the shipped manifest entry.
 */
import { buildViewerArrow, type ViewerArrowTables } from "../../projection/src/arrow.ts";
import {
  decodeFamiliesFiles,
  projectFamilies,
  type FamiliesFiles,
  type WorldFamilies,
} from "../../projection/src/families.ts";
import { projectTables, type ViewerGraph } from "../../projection/src/graph.ts";
import {
  FAMILY_TABLE_NAMES,
  type WorldManifest,
  type WorldManifestEntry,
} from "../../projection/src/manifest.ts";
import { decodeWorldFiles, toArrayBuffer, type WorldFiles } from "../../projection/src/tables.ts";
import { PHYSICAL_ASSET, projectPhysical, type WorldPhysical } from "../../projection/src/physical.ts";
import { structuralLayout, type StructuralLayout } from "./structure.ts";
import { unifiedTopologyLayout } from "./topology.ts";

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
  /** The world's structural layout (every point's coordinates, computed once). */
  readonly layout: StructuralLayout;
  /**
   * The world's families layer when the manifest ships one (Atlas Families
   * export), or null — a world without families renders exactly as before.
   */
  readonly families: WorldFamilies | null;
  /** Bazel-derived depth-7 physical work for every Preact file and symbol, if present. */
  readonly physical: WorldPhysical | null;
  /** Milliseconds spent computing the structural layout. */
  readonly layoutMs: number;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isWorldManifest(value: unknown): value is WorldManifest {
  return (
    isRecord(value) &&
    value.version === 1 &&
    Array.isArray(value.worlds) &&
    (value.synthetic === null || isRecord(value.synthetic))
  );
}

export async function fetchManifest(url = "manifest.json", signal?: AbortSignal): Promise<WorldManifest> {
  const response = await fetch(url, { cache: "no-cache", signal });
  if (!response.ok) throw new Error(`manifest.json: HTTP ${response.status}`);
  const value: unknown = await response.json();
  if (!isWorldManifest(value)) throw new Error("manifest.json has an unexpected shape");
  return value;
}

/**
 * The default world: the smallest snapshot of `preactjs/preact`, a real census
 * world. The synthetic fixture is never eligible.
 */
export function chooseDefaultWorld(manifest: WorldManifest): WorldManifestEntry {
  const candidates = manifest.worlds.filter((world) => world.repository === DEFAULT_REPOSITORY);
  if (candidates.length === 0) {
    throw new Error(`manifest.json has no world for ${DEFAULT_REPOSITORY}`);
  }
  return candidates.reduce((best, world) => (world.counts.points < best.counts.points ? world : best));
}

async function fetchBytes(url: string, signal: AbortSignal | undefined): Promise<ArrayBuffer> {
  const response = await fetch(url, { signal });
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return toArrayBuffer(new Uint8Array(await response.arrayBuffer()));
}

async function fetchWorldFiles(
  entry: WorldManifestEntry,
  signal: AbortSignal | undefined,
): Promise<WorldFiles> {
  const { assets } = entry;
  const [metadata, entities, relations, locations] = await Promise.all([
    fetchBytes(assets.metadata, signal),
    fetchBytes(assets.entities, signal),
    fetchBytes(assets.relations, signal),
    assets.locations === undefined ? Promise.resolve(undefined) : fetchBytes(assets.locations, signal),
  ]);
  return locations === undefined
    ? { metadata, entities, relations }
    : { metadata, entities, relations, locations };
}

/**
 * The five families tables of a world that ships them, or undefined. The bytes
 * are the Flix-built export; the web side only decodes and validates them
 * against the exact graph (see projection/src/families.ts).
 */
async function fetchFamiliesFiles(
  entry: WorldManifestEntry,
  signal: AbortSignal | undefined,
): Promise<FamiliesFiles | undefined> {
  const assets = entry.assets.families;
  if (assets === undefined) return undefined;
  const buffers = await Promise.all(FAMILY_TABLE_NAMES.map((table) => fetchBytes(assets[table], signal)));
  const [families, members, rollups, edges, contributions] = buffers;
  if (
    families === undefined ||
    members === undefined ||
    rollups === undefined ||
    edges === undefined ||
    contributions === undefined
  ) {
    throw new Error("incomplete families assets");
  }
  return { families, members, rollups, edges, contributions };
}

export async function loadWorld(entry: WorldManifestEntry, signal?: AbortSignal): Promise<LoadedWorld> {
  const [files, familiesFiles, physicalFile] = await Promise.all([
    fetchWorldFiles(entry, signal),
    fetchFamiliesFiles(entry, signal),
    fetchBytes(PHYSICAL_ASSET, signal),
  ]);
  const decoded = await decodeWorldFiles(files);
  const graph = projectTables(decoded, entry.sha256);
  const familyTables = familiesFiles === undefined ? undefined : await decodeFamiliesFiles(familiesFiles);
  const families = familyTables === undefined ? null : projectFamilies(familyTables, graph);
  const physical = await projectPhysical(physicalFile, graph);
  const beforeLayout = performance.now();
  const structural = structuralLayout(graph);
  const layout = families === null ? structural : unifiedTopologyLayout(structural, families);
  const layoutMs = Math.round(performance.now() - beforeLayout);
  const tables = buildViewerArrow(graph, families === null ? { xy: layout.xy } : { xy: layout.xy, families });
  return { entry, graph, tables, layout, families, physical, layoutMs };
}
