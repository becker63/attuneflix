import { describe, expect, it } from "vitest";

import {
  LINK_RENDER_BUDGET,
  datasetLabel,
  datasetOptions,
  shortRevision,
  shouldRenderLinks,
} from "../src/datasets.ts";
import { EMPTY_SELECTION, pruneSelection, selectionIndices } from "../src/selection.ts";
import { fixtureGraph } from "./graphFixture.ts";
import type { WorldManifest, WorldManifestEntry } from "../src/world.ts";

function entry(
  digest: string,
  repository: string,
  points: number,
  links: number,
  synthetic = false,
): WorldManifestEntry {
  const snapshotId = `repository-snapshot-v1:${digest}`;
  return {
    snapshotId,
    snapshotDigest: digest,
    repository,
    baseRevision: `${digest.slice(0, 8)}ffff`,
    sourceTreeIdentity: `source-tree:${digest.slice(0, 8)}`,
    factIdentity: `facts:${digest.slice(0, 8)}`,
    counts: {
      files: 1,
      symbols: points - 2,
      directories: 1,
      points,
      links,
      defines: 1,
      imports: 1,
      calls: 1,
      parent: 1,
    },
    assets: {
      metadata: `data/${digest}/metadata.parquet`,
      entities: `data/${digest}/entities.parquet`,
      relations: `data/${digest}/relations.parquet`,
    },
    sha256: {
      metadata: "0".repeat(64),
      entities: "1".repeat(64),
      relations: "2".repeat(64),
    },
    synthetic,
  };
}

function manifest(
  worlds: readonly WorldManifestEntry[],
  synthetic: WorldManifestEntry | null,
): WorldManifest {
  return { version: 1, worlds, synthetic };
}

describe("dataset picker model", () => {
  it("lists the worlds, then the synthetic fixture last, never counted among them", () => {
    const worlds = [entry("a".repeat(64), "acme/one", 100, 200), entry("b".repeat(64), "acme/two", 300, 400)];
    const synthetic = entry("c".repeat(64), "synthetic", 10000, 50000, true);
    const options = datasetOptions(manifest(worlds, synthetic));
    expect(options).toHaveLength(3);
    expect(options.slice(0, 2).every((option) => !option.synthetic)).toBe(true);
    expect(options[2]?.synthetic).toBe(true);
    expect(options[2]?.entry.counts.points).toBe(10000);
    expect(options[2]?.label).toBe("synthetic stress fixture");
  });

  it("lists no fixture when the manifest has none", () => {
    const options = datasetOptions(manifest([entry("d".repeat(64), "acme/one", 1, 1)], null));
    expect(options).toHaveLength(1);
  });

  it("labels a real world with its repository and short revision, and shows its counts", () => {
    const options = datasetOptions(manifest([entry("abcdef0123456789", "acme/one", 100, 200)], null));
    const option = options[0];
    expect(option?.label).toBe("acme/one @ abcdef01");
    expect(option?.detail).toBe("100 points · 200 links");
    expect(option?.revision).toBe("abcdef01");
    expect(datasetLabel(option!)).toBe("acme/one@abcdef01");
  });

  it("truncates a revision to eight characters", () => {
    expect(shortRevision("0123456789abcdef")).toBe("01234567");
    expect(shortRevision("abc")).toBe("abc");
  });

  it("hides links only above the render budget", () => {
    expect(shouldRenderLinks({ links: LINK_RENDER_BUDGET })).toBe(true);
    expect(shouldRenderLinks({ links: LINK_RENDER_BUDGET + 1 })).toBe(false);
    expect(shouldRenderLinks({ links: 50000 })).toBe(false);
  });
});

describe("selection pruning across datasets", () => {
  it("keeps an id that exists in the new graph and drops the rest", () => {
    const graph = fixtureGraph();
    // The fixture has file:0, file:1, symbol:0, symbol:1, location:0, location:1.
    const pruned = pruneSelection(new Set(["file:0", "symbol:99", "near-miss"]), graph);
    expect([...pruned].toSorted()).toEqual(["file:0"]);
    expect(selectionIndices(graph, pruned)).toEqual([0]);
  });

  it("returns the empty selection untouched when nothing is pinned", () => {
    const graph = fixtureGraph();
    expect(pruneSelection(EMPTY_SELECTION, graph)).toBe(EMPTY_SELECTION);
  });
});
