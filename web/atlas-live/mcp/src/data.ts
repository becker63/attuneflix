/** Read the same content-addressed world files that Atlas Live serves to its browser. */
import { containmentTree } from "../../app/src/frontier/containment.ts";
import type { ContainmentTree } from "../../app/src/frontier/containment.ts";
import { projectTables, type ViewerGraph } from "../../projection/src/graph.ts";
import type { WorldManifest, WorldManifestEntry } from "../../projection/src/manifest.ts";
import { projectPhysical, type WorldPhysical } from "../../projection/src/physical.ts";
import { decodeWorldFiles, type WorldFiles } from "../../projection/src/tables.ts";

export interface PublishedWorld {
  readonly entry: WorldManifestEntry;
  readonly graph: ViewerGraph;
  readonly tree: ContainmentTree;
}

const manifests = new Map<string, Promise<WorldManifest>>();
const worlds = new Map<string, Promise<PublishedWorld>>();
const physical = new Map<string, Promise<WorldPhysical | null>>();

async function jsonAt(origin: string, path: string): Promise<unknown> {
  const response = await fetch(new URL(path, origin));
  if (!response.ok) throw new Error(`published asset ${path} returned ${response.status}`);
  const value: unknown = await response.json();
  return value;
}

function isManifest(value: unknown): value is WorldManifest {
  return typeof value === "object" && value !== null && "version" in value && value.version === 1
    && "worlds" in value && Array.isArray(value.worlds)
    && value.worlds.every((world: unknown) => typeof world === "object" && world !== null
      && "snapshotId" in world && typeof world.snapshotId === "string"
      && "snapshotDigest" in world && typeof world.snapshotDigest === "string"
      && "repository" in world && typeof world.repository === "string");
}

async function bytesAt(origin: string, entry: WorldManifestEntry, asset: string): Promise<ArrayBuffer> {
  if (!asset.startsWith(`data/${entry.snapshotDigest}/`) || !asset.endsWith(".parquet")) {
    throw new Error("manifest asset path is outside its snapshot");
  }
  const response = await fetch(new URL(`/${asset}`, origin));
  if (!response.ok) throw new Error(`published asset ${asset} returned ${response.status}`);
  return response.arrayBuffer();
}

function retainTwo<T>(cache: Map<string, Promise<T>>, key: string, value: Promise<T>): Promise<T> {
  cache.set(key, value);
  while (cache.size > 2) cache.delete(cache.keys().next().value!);
  void value.catch(() => { if (cache.get(key) === value) cache.delete(key); });
  return value;
}

export function publishedManifest(origin: string): Promise<WorldManifest> {
  const cached = manifests.get(origin);
  if (cached !== undefined) return cached;
  const request = jsonAt(origin, "/manifest.json").then((manifest) => {
    if (!isManifest(manifest)) throw new Error("invalid published manifest");
    return manifest;
  });
  manifests.set(origin, request);
  void request.catch(() => { if (manifests.get(origin) === request) manifests.delete(origin); });
  return request;
}

export async function publishedEntry(origin: string, snapshotId: string): Promise<WorldManifestEntry> {
  const manifest = await publishedManifest(origin);
  const entry = manifest.worlds.find((candidate) =>
    candidate.snapshotId === snapshotId || candidate.snapshotDigest === snapshotId);
  if (entry === undefined) throw new Error(`snapshot not in the published manifest: ${snapshotId}`);
  return entry;
}

export async function publishedWorld(origin: string, entry: WorldManifestEntry): Promise<PublishedWorld> {
  const key = `${origin}/${entry.snapshotDigest}`;
  const cached = worlds.get(key);
  if (cached !== undefined) return cached;
  const request = (async () => {
    const assets = entry.assets;
    const [metadata, entities, relations, locations] = await Promise.all([
      bytesAt(origin, entry, assets.metadata),
      bytesAt(origin, entry, assets.entities),
      bytesAt(origin, entry, assets.relations),
      assets.locations === undefined ? Promise.resolve(undefined) : bytesAt(origin, entry, assets.locations),
    ]);
    const files: WorldFiles = locations === undefined
      ? { metadata, entities, relations }
      : { metadata, entities, relations, locations };
    const tables = await decodeWorldFiles(files);
    const graph = projectTables(tables, entry.sha256);
    if (graph.provenance.snapshotId !== entry.snapshotId) throw new Error("manifest/world snapshot mismatch");
    return { entry, graph, tree: containmentTree(graph) };
  })();
  return retainTwo(worlds, key, request);
}

export async function publishedPhysical(origin: string, world: PublishedWorld): Promise<WorldPhysical | null> {
  const asset = world.entry.assets.physical;
  if (asset === undefined) return null;
  const key = `${origin}/${world.entry.snapshotDigest}`;
  const cached = physical.get(key);
  if (cached !== undefined) return cached;
  const request = bytesAt(origin, world.entry, asset).then((bytes) => projectPhysical(bytes, world.graph));
  return retainTwo(physical, key, request);
}
