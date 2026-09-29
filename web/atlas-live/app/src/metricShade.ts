/** Scalar views tint the existing structural/family graph without changing its topology. */
import type { MeasurementMode } from "./atoms.ts";
import type { ProjectionMetrics, RegionMetrics } from "./frontier/metrics.ts";

export interface ScalarRange {
  readonly low: number;
  readonly high: number;
}

export function metricValue(metrics: RegionMetrics, mode: "locality" | "reach"): number {
  return mode === "locality" ? metrics.localness : metrics.reach[2];
}

/** Robust per-world display range; the inspector retains exact metric values. */
export function metricShadeRange(metrics: ProjectionMetrics, mode: MeasurementMode): ScalarRange | null {
  if (mode !== "locality" && mode !== "reach") return null;
  const values = [...metrics.values()].map((region) => metricValue(region, mode)).toSorted((a, b) => a - b);
  if (values.length === 0) return null;
  const low = values[Math.floor((values.length - 1) * 0.05)] ?? 0;
  const high = values[Math.ceil((values.length - 1) * 0.95)] ?? low;
  return high > low ? { low, high } : { low: Math.min(0, low), high: Math.max(1, high) };
}

export function scalarPosition(value: number, range: ScalarRange): number {
  return Math.max(0, Math.min(1, (value - range.low) / (range.high - range.low)));
}
