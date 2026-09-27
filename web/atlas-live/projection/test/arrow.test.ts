import { describe, expect, it } from "vitest";

import { buildViewerArrow } from "../src/arrow.ts";
import { projectTables } from "../src/graph.ts";
import { FIXTURE_HASHES, fixtureTables } from "./fixture.ts";

describe("Arrow table builder", () => {
  const graph = projectTables(fixtureTables(false), FIXTURE_HASHES);
  const { points, links } = buildViewerArrow(graph);

  it("emits one point row per point with an index column equal to position", () => {
    expect(points.numRows).toBe(graph.pointCount);
    const index = points.getChild("index");
    const id = points.getChild("id");
    const domain = points.getChild("domain");
    const entityId = points.getChild("entityId");
    const label = points.getChild("label");
    for (let i = 0; i < graph.pointCount; i++) {
      expect(index?.get(i)).toBe(i);
      expect(id?.get(i)).toBe(graph.pointIds[i]);
      expect(entityId?.get(i)).toBe(graph.pointEntityIds[i]);
      expect(label?.get(i)).toBe(graph.pointLabels[i]);
    }
    expect(domain?.get(0)).toBe("file");
    expect(domain?.get(3)).toBe("symbol");
    expect(domain?.get(7)).toBe("location");
    expect(id?.get(7)).toBe("location:3");
  });

  it("keeps nullable point columns null for directories", () => {
    const path = points.getChild("path");
    const name = points.getChild("name");
    const startByte = points.getChild("startByte");
    expect(path?.get(7)).toBeNull();
    expect(name?.get(7)).toBeNull();
    expect(startByte?.get(7)).toBeNull();
    expect(path?.get(0)).toBe("index.ts");
    expect(name?.get(3)).toBe("main");
    expect(startByte?.get(3)).toBe(0);
  });

  it("emits one link row per link with resolved index columns", () => {
    expect(links.numRows).toBe(graph.linkCount);
    const index = links.getChild("index");
    const relation = links.getChild("relation");
    const sourceIndex = links.getChild("sourceIndex");
    const targetIndex = links.getChild("targetIndex");
    for (let i = 0; i < graph.linkCount; i++) {
      expect(index?.get(i)).toBe(i);
      expect(sourceIndex?.get(i)).toBe(graph.linkSourceIndices[i]);
      expect(targetIndex?.get(i)).toBe(graph.linkTargetIndices[i]);
    }
    expect(relation?.get(0)).toBe("defines");
    expect(relation?.get(4)).toBe("imports");
    expect(relation?.get(6)).toBe("calls");
    expect(relation?.get(9)).toBe("parent");
    // typed endpoints survive as (domain, id) columns
    expect(links.getChild("sourceDomain")?.get(9)).toBe("location");
    expect(links.getChild("sourceId")?.get(9)).toBe(0);
    expect(links.getChild("targetDomain")?.get(9)).toBe("location");
    expect(links.getChild("targetId")?.get(9)).toBe(3);
    expect(links.getChild("sourceDomain")?.get(6)).toBe("symbol");
    expect(links.getChild("sourceId")?.get(6)).toBe(1);
  });
});
