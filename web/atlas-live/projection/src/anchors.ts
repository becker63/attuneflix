/** Read-only projection of Flix's depth-seven anchor experiment. */
import type { ViewerGraph } from "./graph.ts";
import { cell, integer, readTable, text } from "./tables.ts";

export const ANCHOR_COLUMNS = [
  "snapshot_id",
  "seed_domain",
  "anchor_path",
  "rank",
  "contained_files",
  "crossing_edges",
  "unique_containing_states",
  "unique_live_states",
  "unique_anchor_mass",
  "weighted_containing_observations",
  "live_observations",
  "weighted_anchor_mass",
] as const;
export const SCENARIO_COLUMNS = [
  "snapshot_id",
  "intervention",
  "masked_anchor",
  "seed_domain",
  "masked_imports",
  "masked_calls",
  "crossing_edges",
  "observations",
  "extinct_observations",
  "live_observations",
  "unique_states",
  "unique_live_states",
  "extinct_fraction",
  "total_recurrence",
  "live_recurrence",
  "reach_p90",
  "physical_compression",
  "physical_reuse_fraction",
] as const;

export interface AnchorMass {
  readonly path: string;
  readonly domain: "file" | "symbol";
  readonly rank: number;
  readonly containedFiles: number;
  readonly crossingEdges: number;
  readonly uniqueContaining: number;
  readonly uniqueLiveStates: number;
  readonly uniqueFraction: number;
  readonly weightedContaining: number;
  readonly liveObservations: number;
  readonly weightedFraction: number;
}

export interface AnchorScenario {
  readonly intervention: "baseline" | "masked";
  readonly path: string;
  readonly domain: "file" | "symbol";
  readonly maskedImports: number;
  readonly maskedCalls: number;
  readonly observations: number;
  readonly extinctObservations: number;
  readonly liveObservations: number;
  readonly uniqueStates: number;
  readonly uniqueLiveStates: number;
  readonly extinctFraction: number;
  readonly totalRecurrence: number;
  readonly liveRecurrence: number;
  readonly reachP90: number;
  readonly physicalCompression: number;
  readonly physicalReuseFraction: number;
}

export interface WorldAnchors {
  readonly masses: readonly AnchorMass[];
  readonly scenarios: readonly AnchorScenario[];
  readonly byPath: ReadonlyMap<string, readonly AnchorMass[]>;
}

function number(row: Record<string, unknown>, table: string, column: string): number {
  const value = cell(row, table, column);
  if (typeof value !== "number" || !Number.isFinite(value))
    throw new Error(`${table}.${column} is not finite`);
  return value;
}

function domain(row: Record<string, unknown>, table: string): "file" | "symbol" {
  const value = text(row, table, "seed_domain");
  if (value !== "file" && value !== "symbol") throw new Error(`${table}: unknown seed domain ${value}`);
  return value;
}

function fraction(numerator: number, denominator: number, actual: number, label: string): void {
  const expected = denominator === 0 ? 0 : numerator / denominator;
  if (Math.abs(expected - actual) > 1e-12) throw new Error(`${label}: ratio does not match exact counts`);
}

export async function projectAnchors(
  anchorsFile: ArrayBuffer,
  scenariosFile: ArrayBuffer,
  graph: ViewerGraph,
): Promise<WorldAnchors> {
  const [anchorRows, scenarioRows] = await Promise.all([
    readTable(anchorsFile, "anchors", ANCHOR_COLUMNS),
    readTable(scenariosFile, "anchor-scenarios", SCENARIO_COLUMNS),
  ]);
  const directoryPaths = new Set(graph.pointPaths.slice(graph.fileCount + graph.symbolCount));
  const masses = anchorRows.map((row): AnchorMass => {
    if (text(row, "anchors", "snapshot_id") !== graph.provenance.snapshotId)
      throw new Error("foreign anchor snapshot");
    const path = text(row, "anchors", "anchor_path");
    if (!directoryPaths.has(path) || path === "")
      throw new Error(`anchor is not an admitted directory: ${path}`);
    const uniqueContaining = integer(row, "anchors", "unique_containing_states");
    const uniqueLiveStates = integer(row, "anchors", "unique_live_states");
    const weightedContaining = integer(row, "anchors", "weighted_containing_observations");
    const liveObservations = integer(row, "anchors", "live_observations");
    const uniqueFraction = number(row, "anchors", "unique_anchor_mass");
    const weightedFraction = number(row, "anchors", "weighted_anchor_mass");
    fraction(uniqueContaining, uniqueLiveStates, uniqueFraction, `${path} unique mass`);
    fraction(weightedContaining, liveObservations, weightedFraction, `${path} weighted mass`);
    return {
      path,
      domain: domain(row, "anchors"),
      rank: integer(row, "anchors", "rank"),
      containedFiles: integer(row, "anchors", "contained_files"),
      crossingEdges: integer(row, "anchors", "crossing_edges"),
      uniqueContaining,
      uniqueLiveStates,
      uniqueFraction,
      weightedContaining,
      liveObservations,
      weightedFraction,
    };
  });
  const scenarios = scenarioRows.map((row): AnchorScenario => {
    if (text(row, "anchor-scenarios", "snapshot_id") !== graph.provenance.snapshotId)
      throw new Error("foreign counterfactual snapshot");
    const intervention = text(row, "anchor-scenarios", "intervention");
    if (intervention !== "baseline" && intervention !== "masked")
      throw new Error(`unknown intervention ${intervention}`);
    const observations = integer(row, "anchor-scenarios", "observations");
    const extinctObservations = integer(row, "anchor-scenarios", "extinct_observations");
    const liveObservations = integer(row, "anchor-scenarios", "live_observations");
    const extinctFraction = number(row, "anchor-scenarios", "extinct_fraction");
    if (observations !== extinctObservations + liveObservations)
      throw new Error("counterfactual observations do not reconcile");
    fraction(extinctObservations, observations, extinctFraction, "counterfactual extinction");
    const uniqueStates = integer(row, "anchor-scenarios", "unique_states");
    const uniqueLiveStates = integer(row, "anchor-scenarios", "unique_live_states");
    const totalRecurrence = number(row, "anchor-scenarios", "total_recurrence");
    const liveRecurrence = number(row, "anchor-scenarios", "live_recurrence");
    fraction(observations, uniqueStates, totalRecurrence, "total recurrence");
    fraction(liveObservations, uniqueLiveStates, liveRecurrence, "live recurrence");
    return {
      intervention,
      path: text(row, "anchor-scenarios", "masked_anchor"),
      domain: domain(row, "anchor-scenarios"),
      maskedImports: integer(row, "anchor-scenarios", "masked_imports"),
      maskedCalls: integer(row, "anchor-scenarios", "masked_calls"),
      observations,
      extinctObservations,
      liveObservations,
      uniqueStates,
      uniqueLiveStates,
      extinctFraction,
      totalRecurrence,
      liveRecurrence,
      reachP90: number(row, "anchor-scenarios", "reach_p90"),
      physicalCompression: number(row, "anchor-scenarios", "physical_compression"),
      physicalReuseFraction: number(row, "anchor-scenarios", "physical_reuse_fraction"),
    };
  });
  if (scenarios.filter((row) => row.intervention === "baseline").length !== 2)
    throw new Error("missing File/Symbol baseline rows");
  const byPath = new Map<string, AnchorMass[]>();
  for (const mass of masses) byPath.set(mass.path, [...(byPath.get(mass.path) ?? []), mass]);
  return { masses, scenarios, byPath };
}
