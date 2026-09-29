/** Exact region aggregation of measured physical transition reuse. */
import type { WorldPhysical } from "../../projection/src/physical.ts";
import type { StructuralLayout } from "./structure.ts";

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
