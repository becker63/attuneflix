/** Bounded read-only MCP tools over the same frontier modules as the viewer. */
import { isVisible, expand, initialFrontier, type VisibleFrontier } from "../../app/src/frontier/frontier.ts";
import { computeProjectionMetrics } from "../../app/src/frontier/metrics.ts";
import {
  convergenceGraph, greedySeparatedSet, greedyStructuralWaves, neighborhoodIds,
  neighborhoodIndex, originNeighborhood, pairGeometry, separationDecay, sharedNeighborhoodIds,
  type StructuralDepth,
} from "../../app/src/frontier/parallelism.ts";
import { projectFrontier, normalizeWireRelations } from "../../app/src/frontier/wires.ts";
import { regionReuse } from "../../app/src/physicalRegion.ts";
import { structuralLayout } from "../../app/src/structure.ts";
import type { WorldManifestEntry } from "../../projection/src/manifest.ts";
import { publishedEntry, publishedManifest, publishedPhysical, publishedWorld, type PublishedWorld } from "./data.ts";

export type ToolName = "list_worlds" | "get_world" | "list_origins" | "get_region" | "compare_origins" | "get_landscape";

type Arguments = Record<string, unknown>;

function stringArg(args: Arguments, key: string, required = true): string | null {
  const value = args[key];
  if (value === undefined || value === null) {
    if (required) throw new Error(`${key} is required`);
    return null;
  }
  if (typeof value !== "string" || value.length > 256 || value.length === 0) throw new Error(`${key} must be a nonempty string of at most 256 characters`);
  return value;
}

function numberArg(args: Arguments, key: string, fallback: number, min: number, max: number): number {
  const value = args[key] ?? fallback;
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw new Error(`${key} must be a number in [${min}, ${max}]`);
  }
  return value;
}

function page(args: Arguments): { offset: number; limit: number } {
  const offset = numberArg(args, "offset", 0, 0, 100000);
  const limit = numberArg(args, "limit", 20, 1, 50);
  if (!Number.isInteger(offset) || !Number.isInteger(limit)) throw new Error("offset and limit must be integers");
  return { offset, limit };
}

function depthArg(args: Arguments): StructuralDepth {
  const depth = numberArg(args, "depth", 3, 1, 3);
  if (depth !== 1 && depth !== 2 && depth !== 3) throw new Error("depth must be 1, 2, or 3");
  return depth;
}

function viewUrl(origin: string, entry: WorldManifestEntry, a?: string, b?: string,
  expanded: readonly string[] = [], enabled: readonly string[] = ["imports", "calls"]): string {
  const url = new URL("/", origin);
  url.searchParams.set("snapshot", entry.snapshotDigest);
  url.searchParams.set("mode", "parallelism");
  if (a !== undefined) url.searchParams.set("a", a);
  if (b !== undefined) url.searchParams.set("b", b);
  for (const id of expanded) url.searchParams.append("expand", id);
  if (enabled.join(",") !== "imports,calls") url.searchParams.set("relations", enabled.join(","));
  return url.toString();
}

async function view(origin: string, args: Arguments) {
  const snapshot = stringArg(args, "snapshot_id")!;
  const entry = await publishedEntry(origin, snapshot);
  const world = await publishedWorld(origin, entry);
  const enabledValue = args.enabled_relations;
  if (enabledValue !== undefined && (!Array.isArray(enabledValue) || !enabledValue.every((v) => typeof v === "string"))) {
    throw new Error("enabled_relations must be an array of imports and/or calls");
  }
  const enabled = normalizeWireRelations(enabledValue ?? ["imports", "calls"]);
  const expanded = args.expanded ?? [];
  if (!Array.isArray(expanded) || expanded.length > 64 || !expanded.every((id) => typeof id === "string")) {
    throw new Error("expanded must be an array of at most 64 container IDs");
  }
  let frontier: VisibleFrontier = initialFrontier();
  for (const id of expanded) {
    const point = world.graph.indexById.get(id);
    if (point === undefined || !isVisible(world.tree, frontier, point)) {
      throw new Error(`expanded container is not visible: ${id}`);
    }
    frontier = expand(world.tree, frontier, id);
  }
  const projection = projectFrontier(world.graph, world.tree, frontier, enabled);
  const index = neighborhoodIndex(projection, world.tree);
  return { entry, world, projection, index, frontier, enabled };
}

function visibleOrigin(world: PublishedWorld, index: ReturnType<typeof neighborhoodIndex>, id: string): void {
  if (!index.ordinalById.has(id) || !world.graph.indexById.has(id)) throw new Error(`origin is not visible: ${id}`);
}

function nodeLabel(world: PublishedWorld, id: string): string {
  const point = world.graph.indexById.get(id);
  return point === undefined ? id : world.graph.pointLabels[point] ?? id;
}

function originSummary(world: PublishedWorld, id: string) {
  const point = world.graph.indexById.get(id)!;
  return { id, label: nodeLabel(world, id), path: world.graph.pointPaths[point], name: world.graph.pointNames[point] };
}

async function originPhysical(origin: string, world: PublishedWorld, id: string) {
  const measurement = await publishedPhysical(origin, world);
  if (measurement === null) return { status: "unmeasured" };
  const point = world.graph.indexById.get(id)!;
  if (id.startsWith("location:")) {
    const ordinal = point - world.graph.fileCount - world.graph.symbolCount;
    return regionReuse(structuralLayout(world.graph), measurement).get(ordinal) ?? { status: "unmeasured" };
  }
  const seed = measurement.seeds.find((candidate) => candidate.pointIndex === point);
  return seed === undefined ? { status: "unmeasured" } : {
    measuredSeeds: 1, requests: seed.requests, reuses: seed.reuses, reuseFraction: seed.reuseFraction,
  };
}

export async function callTool(origin: string, name: ToolName, args: Arguments): Promise<Record<string, unknown>> {
  if (name === "list_worlds") {
    const manifest = await publishedManifest(origin);
    const requestedRepository = stringArg(args, "repository", false);
    const matches = manifest.worlds.filter((entry) => requestedRepository === null
      || entry.repository.toLowerCase().includes(requestedRepository.toLowerCase()));
    const { offset, limit } = page(args);
    return { total: matches.length, offset, nextOffset: offset + limit < matches.length ? offset + limit : null,
      worlds: matches.slice(offset, offset + limit).map((entry) => ({
        snapshotId: entry.snapshotId, repository: entry.repository, baseRevision: entry.baseRevision,
        counts: entry.counts, physicalSummary: entry.physicalSummary ?? null,
        signatureSummary: entry.signatureSummary ?? null, familySummary: entry.familySummary ?? null,
        viewUrl: viewUrl(origin, entry),
      })) };
  }
  if (name === "get_world") {
    const entry = await publishedEntry(origin, stringArg(args, "snapshot_id")!);
    return { ...entry, viewUrl: viewUrl(origin, entry),
      assetUrls: Object.fromEntries(Object.entries(entry.assets).flatMap(([key, asset]) =>
        typeof asset === "string" ? [[key, new URL(`/${asset}`, origin).toString()]] : [])),
      familyAssetUrls: entry.assets.families === undefined ? null
        : Object.fromEntries(Object.entries(entry.assets.families).map(([key, asset]) =>
          [key, new URL(`/${asset}`, origin).toString()])),
      definitions: "Depth-7 physical reuse and census signatures are measured evidence. Structural depth 1–3 is computed over the current visible frontier and enabled directed Imports/Calls; it is potential convergence, not observed task contention." };
  }
  const state = await view(origin, args);
  const { entry, world, projection, index, enabled, frontier } = state;
  const common = { snapshotId: entry.snapshotId, repository: entry.repository, enabledRelations: enabled,
    expanded: frontier.expanded, visibleNodes: projection.nodes.length, projectedWires: projection.wires.length,
    internalizedEdges: projection.internalized, viewUrl: viewUrl(origin, entry, undefined, undefined, frontier.expanded, enabled) };
  if (name === "list_origins") {
    const { offset, limit } = page(args);
    const nodes = projection.nodes;
    return { ...common, total: nodes.length, offset, nextOffset: offset + limit < nodes.length ? offset + limit : null,
      origins: nodes.slice(offset, offset + limit).map((node) => ({
        id: node.id, label: node.label, path: node.path, kind: node.kind, depth: node.depth,
        container: node.container, expanded: node.expanded,
      })) };
  }
  if (name === "get_region") {
    const id = stringArg(args, "origin_id")!;
    visibleOrigin(world, index, id);
    const neighborhood = originNeighborhood(index, id);
    const metric = computeProjectionMetrics(world.graph, world.tree, projection).get(id);
    const nearest = index.candidates.filter((candidate) => candidate !== id).map((candidate) => ({
      origin: originSummary(world, candidate), geometry: pairGeometry(index, id, candidate),
    })).toSorted((a, b) => (a.geometry.convergenceDepth ?? 4) - (b.geometry.convergenceDepth ?? 4)
      || b.geometry.depths[2].overlap - a.geometry.depths[2].overlap
      || a.origin.id.localeCompare(b.origin.id)).slice(0, 10);
    return { ...common, origin: originSummary(world, id), metrics: metric ?? null,
      structuralReach: neighborhood.sizes, growth: neighborhood.growth, nearestConvergingRegions: nearest,
      physicalReuse: await originPhysical(origin, world, id),
      viewUrl: viewUrl(origin, entry, id, undefined, frontier.expanded, enabled) };
  }
  if (name === "compare_origins") {
    const a = stringArg(args, "origin_a")!;
    const b = stringArg(args, "origin_b")!;
    visibleOrigin(world, index, a);
    visibleOrigin(world, index, b);
    const depth = depthArg(args);
    const geometry = pairGeometry(index, a, b);
    const shared = sharedNeighborhoodIds(index, a, b, depth);
    return { ...common, a: originSummary(world, a), b: originSummary(world, b),
      convergenceDepth: geometry.convergenceDepth === null ? ">3°" : `${geometry.convergenceDepth}°`,
      censored: geometry.convergenceDepth === null, depths: geometry.depths,
      selectedDepth: depth, sharedCount: shared.length,
      sharedSample: shared.slice(0, 30).map((id) => originSummary(world, id)),
      aReach: originNeighborhood(index, a).sizes, bReach: originNeighborhood(index, b).sizes,
      aOnlyAtDepth: neighborhoodIds(index, a, depth).length - shared.length,
      bOnlyAtDepth: neighborhoodIds(index, b, depth).length - shared.length,
      viewUrl: viewUrl(origin, entry, a, b, frontier.expanded, enabled) };
  }
  if (name === "get_landscape") {
    const depth = depthArg(args);
    const threshold = numberArg(args, "threshold", 0.25, 0, 1);
    const graph = convergenceGraph(index, depth, threshold);
    const separated = greedySeparatedSet(graph);
    const waves = greedyStructuralWaves(graph);
    const edgeSample: { a: string; b: string; overlap: number }[] = [];
    for (const a of graph.origins) {
      for (const b of graph.neighbors.get(a) ?? []) {
        if (a < b && edgeSample.length < 50) {
          const depths = pairGeometry(index, a, b).depths;
          edgeSample.push({ a, b, overlap: depth === 1 ? depths[0].overlap
            : depth === 2 ? depths[1].overlap : depths[2].overlap });
        }
      }
    }
    return { ...common, depth, threshold, candidateRegions: index.candidates.length,
      eligibleRegions: index.eligibleRegions, convergenceEdges: graph.edges, edgeSample,
      separatedCount: separated.length, separatedSample: separated.slice(0, 50).map((id) => originSummary(world, id)),
      waveCount: waves.length, waveSizes: waves.map((wave) => wave.length),
      waveSamples: waves.slice(0, 10).map((wave) => wave.slice(0, 20).map((id) => originSummary(world, id))),
      decay: separationDecay(index, threshold),
      method: "Deterministic greedy separated set and greedy coloring over visible region candidates; not an exact maximum independent set or predicted agent throughput." };
  }
  throw new Error("unknown tool");
}
