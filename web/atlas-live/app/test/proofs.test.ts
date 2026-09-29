import { describe, expect, it } from "vitest";

import { linkRelation } from "../../projection/src/graph.ts";
import { deriveLensProofs } from "../src/frontier/proofs.ts";
import { fixtureGraph } from "./graphFixture.ts";

describe("derived relation witnesses", () => {
  it("follows the exact Flix rule bodies and resolves every step to a basis row", () => {
    const graph = fixtureGraph();
    const alpha = deriveLensProofs(graph, 2);
    const sameFile = alpha.find((proof) => proof.relation === "SameFile");
    const imported = alpha.find((proof) => proof.relation === "ImportNeighbor");
    const importer = deriveLensProofs(graph, 3).find((proof) => proof.relation === "ImporterNeighbor");
    const adjacency = deriveLensProofs(graph, 0).find((proof) => proof.relation === "RepositoryAdjacent");

    expect(sameFile?.steps.map((step) => step.relation)).toEqual(["defines", "defines"]);
    expect(imported?.target).toBe("beta");
    expect(imported?.steps.map((step) => [step.relation, step.source, step.target])).toEqual([
      ["defines", "a.ts", "alpha"],
      ["imports", "a.ts", "b.ts"],
      ["defines", "b.ts", "beta"],
    ]);
    expect(importer?.target).toBe("alpha");
    expect(importer?.steps.map((step) => step.relation)).toEqual(["defines", "imports", "defines"]);
    expect(adjacency?.steps.map((step) => step.relation)).toEqual(["parent"]);
    for (const proof of [...alpha, ...deriveLensProofs(graph, 3), ...deriveLensProofs(graph, 0)]) {
      for (const step of proof.steps) {
        const link = graph.linkRows.indexOf(step.row);
        expect(link).toBeGreaterThanOrEqual(0);
        expect(linkRelation(graph, link)).toBe(step.relation);
        expect(graph.pointIds[graph.linkSourceIndices[link] ?? -1]).toBe(step.sourceId);
        expect(graph.pointIds[graph.linkTargetIndices[link] ?? -1]).toBe(step.targetId);
      }
    }
    expect(deriveLensProofs(graph, 2)).toEqual(alpha);
  });

  it("bounds each lens without losing the exact proof of returned results", () => {
    const graph = fixtureGraph();
    const proofs = deriveLensProofs(graph, 2, 1);
    expect(proofs.filter((proof) => proof.relation === "SameFile")).toHaveLength(1);
    expect(proofs.filter((proof) => proof.relation === "ImportNeighbor")).toHaveLength(1);
    expect(deriveLensProofs(graph, -1)).toEqual([]);
  });
});
