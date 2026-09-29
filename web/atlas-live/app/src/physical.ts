/** Oklab lightness shading of measured Atlas physical-transition reuse. */
import { DOMAIN_ORDER } from "../../projection/src/domain.ts";
import type { WorldFamilies } from "../../projection/src/families.ts";
import type { ViewerGraph } from "../../projection/src/graph.ts";
import type { WorldPhysical } from "../../projection/src/physical.ts";
import { familyTint } from "./families.ts";
import type { StructuralLayout } from "./structure.ts";
import { pointColorMap } from "./vocabulary.ts";

interface Oklab {
  readonly l: number;
  readonly a: number;
  readonly b: number;
}

const BASE_COLORS = pointColorMap();

function linear(channel: number): number {
  const value = channel / 255;
  return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
}

function oklab(hex: string): Oklab {
  const red = linear(Number.parseInt(hex.slice(1, 3), 16));
  const green = linear(Number.parseInt(hex.slice(3, 5), 16));
  const blue = linear(Number.parseInt(hex.slice(5, 7), 16));
  const l = Math.cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue);
  const m = Math.cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue);
  const s = Math.cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue);
  return {
    l: 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    a: 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    b: 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  };
}

function encoded(linearValue: number): string {
  const bounded = Math.max(0, Math.min(1, linearValue));
  const value = bounded <= 0.0031308 ? 12.92 * bounded : 1.055 * bounded ** (1 / 2.4) - 0.055;
  return Math.round(value * 255)
    .toString(16)
    .padStart(2, "0");
}

function hexFromOklab(color: Oklab): string {
  const l = (color.l + 0.3963377774 * color.a + 0.2158037573 * color.b) ** 3;
  const m = (color.l - 0.1055613458 * color.a - 0.0638541728 * color.b) ** 3;
  const s = (color.l - 0.0894841775 * color.a - 1.291485548 * color.b) ** 3;
  return `#${encoded(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s)}${encoded(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s)}${encoded(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s)}`;
}

/** Family hue survives; low reuse becomes dark and muted, high reuse bright. */
export function shadeOklab(baseHex: string, unit: number): string {
  const base = oklab(baseHex);
  const t = Math.max(0, Math.min(1, unit));
  const chroma = 0.2 + 0.8 * t;
  return hexFromOklab({ l: 0.28 + 0.6 * t, a: base.a * chroma, b: base.b * chroma });
}

const REUSE_RANGES = new WeakMap<WorldPhysical, { low: number; high: number }>();

/** Robust within-world display range. Exact fractions remain in the inspector. */
export function reuseShadeRange(physical: WorldPhysical): { low: number; high: number } {
  const cached = REUSE_RANGES.get(physical);
  if (cached !== undefined) return cached;
  const sorted = physical.seeds.map((seed) => seed.reuseFraction).toSorted((a, b) => a - b);
  const low = sorted[Math.floor((sorted.length - 1) * 0.05)] ?? physical.minFraction;
  const high = sorted[Math.ceil((sorted.length - 1) * 0.95)] ?? physical.maxFraction;
  const range = high > low ? { low, high } : { low: physical.minFraction, high: physical.maxFraction };
  REUSE_RANGES.set(physical, range);
  return range;
}

/** Normalized within the measured world's 5th–95th percentile range. */
export function reuseShadePosition(physical: WorldPhysical, reuseFraction: number): number {
  const { low, high } = reuseShadeRange(physical);
  const span = high - low;
  return span <= 0 ? 0.5 : Math.max(0, Math.min(1, (reuseFraction - low) / span));
}

export function basePointColor(graph: ViewerGraph, families: WorldFamilies | null, index: number): string {
  if (families !== null) return familyTint(families, index);
  const domain = DOMAIN_ORDER[graph.pointDomains[index] ?? -1];
  return domain === undefined ? "#3f4756" : BASE_COLORS[domain];
}

/** Stable renderer accessor: measured files and symbols change lightness. */
export function physicalPointColor(
  graph: ViewerGraph,
  families: WorldFamilies | null,
  physical: WorldPhysical,
): (value: unknown, index?: number) => string {
  const shaded = new Map<number, string>();
  for (const seed of physical.seeds) {
    shaded.set(
      seed.pointIndex,
      shadeOklab(
        basePointColor(graph, families, seed.pointIndex),
        reuseShadePosition(physical, seed.reuseFraction),
      ),
    );
  }
  return (_value: unknown, index = -1): string => shaded.get(index) ?? basePointColor(graph, families, index);
}

export interface RegionReuse {
  readonly measuredSeeds: number;
  readonly requests: number;
  readonly reuses: number;
  readonly reuseFraction: number;
}

const REGION_REUSE = new WeakMap<
  WorldPhysical,
  WeakMap<StructuralLayout, ReadonlyMap<number, RegionReuse>>
>();

/** Exact transition reuse fraction over seeds in a directory and its descendants. */
export function regionReuse(
  layout: StructuralLayout,
  physical: WorldPhysical,
): ReadonlyMap<number, RegionReuse> {
  const cached = REGION_REUSE.get(physical)?.get(layout);
  if (cached !== undefined) return cached;
  const { fileDirectory, symbolFile, directoryParent } = layout.structure;
  const totals = new Map<number, { count: number; requests: number; reuses: number }>();
  for (const seed of physical.seeds) {
    const file =
      seed.pointIndex < fileDirectory.length
        ? seed.pointIndex
        : (symbolFile[seed.pointIndex - fileDirectory.length] ?? -1);
    if (file < 0) continue;
    let directory = fileDirectory[file] ?? -1;
    while (directory >= 0) {
      const prior = totals.get(directory) ?? { count: 0, requests: 0, reuses: 0 };
      totals.set(directory, {
        count: prior.count + 1,
        requests: prior.requests + seed.requests,
        reuses: prior.reuses + seed.reuses,
      });
      directory = directoryParent[directory] ?? -1;
    }
  }
  const regions = new Map(
    Array.from(totals, ([ordinal, value]) => [
      ordinal,
      {
        measuredSeeds: value.count,
        requests: value.requests,
        reuses: value.reuses,
        reuseFraction: value.reuses / value.requests,
      },
    ]),
  );
  const byLayout = REGION_REUSE.get(physical) ?? new WeakMap();
  byLayout.set(layout, regions);
  REGION_REUSE.set(physical, byLayout);
  return regions;
}
