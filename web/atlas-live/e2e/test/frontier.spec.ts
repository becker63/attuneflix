/** The unified topology view keeps the full evidence population spatially present. */
import fs from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("the default graph places every entity inside structural regions", async ({ page }) => {
  await page.goto("/");
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });
  await expect.poll(async () => page.getByTestId("topology-region").count()).toBeGreaterThan(0);
  const view = await page.evaluate(() => {
    const hook = window.__atlasLive;
    if (hook === undefined) throw new Error("no diagnostics hook");
    const regions = [...document.querySelectorAll('[data-testid="topology-region"]')].map((rect) => ({
      x: Number(rect.getAttribute("x")),
      y: Number(rect.getAttribute("y")),
      width: Number(rect.getAttribute("width")),
      height: Number(rect.getAttribute("height")),
    }));
    return {
      pointCount: hook.pointCount(),
      visibleCount: hook.visibleNodeIds().length,
      symbolPosition: hook.screenPositionOf(500),
      layoutIdentity: hook.layoutIdentity,
      regions,
    };
  });

  expect(view.visibleCount).toBe(view.pointCount);
  expect(view.symbolPosition).not.toBeNull();
  expect(view.layoutIdentity).toMatch(/^topology-v1:[0-9a-f]+$/);
  expect(
    view.regions.filter(
      (region) =>
        region.width > 5 &&
        region.height > 5 &&
        region.x + region.width > 0 &&
        region.x < 744 &&
        region.y + region.height > 0 &&
        region.y < 650,
    ).length,
  ).toBeGreaterThanOrEqual(3);
  await expect(page.getByTestId("overlay")).toHaveText("Structure + families");
  const reuse = page.getByTestId("reuse-shading");
  await expect(reuse).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByText("1833 measured files and symbols · depth 7")).toBeVisible();
  await page.getByRole("button", { name: "Family + structure" }).click();
  await expect(reuse).toHaveAttribute("aria-pressed", "false");
  expect(await page.evaluate(() => window.__atlasLive?.layoutIdentity)).toBe(view.layoutIdentity);
  await reuse.click();
  await expect(reuse).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByRole("button", { name: "Families overlay" })).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Expand" })).toHaveCount(0);
  const outputs = process.env.TEST_UNDECLARED_OUTPUTS_DIR;
  if (outputs !== undefined) {
    fs.writeFileSync(path.join(outputs, "unified-graph.png"), await page.screenshot());
    fs.writeFileSync(path.join(outputs, "unified-regions.json"), JSON.stringify(view.regions, null, 2));
  }

  // The comparison ranks repository signature medians rather than snapshots, and a
  // second world's exact physical table survives an actual dataset switch.
  const comparison = page.getByRole("region", { name: "Repository signature comparison" });
  await expect(comparison.getByTestId("reuse-comparison-current")).toContainText("/12 in recurrence");
  const rows = comparison.getByTestId("reuse-comparison-list").getByRole("button");
  await expect(rows).toHaveCount(12);
  await expect(rows.filter({ hasText: "preactjs/preact" })).toHaveCount(1);
  const values = (await rows.locator("span:nth-child(3)").allTextContents()).map((value) =>
    Number.parseFloat(value.replaceAll(",", "")),
  );
  expect(
    values.every((value, index) => {
      const previous = values[index - 1];
      return Number.isFinite(value) && (previous === undefined || value <= previous);
    }),
  ).toBe(true);
  await rows.filter({ hasText: "axios/axios" }).first().click();
  await page.waitForFunction(
    () => window.__atlasLive?.ready === true && window.__atlasLive?.dataset?.repository === "axios/axios",
    null,
    { timeout: 90_000 },
  );
  await expect(page.getByTestId("reuse-shading")).toHaveAttribute("aria-pressed", "true");
  await expect(comparison.getByTestId("reuse-comparison-current")).toContainText("/12 in recurrence");
});

test("structural separation compares two origins on the same relation-filtered graph", async ({ page }) => {
  await page.goto("/");
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });
  const identity = await page.evaluate(() => window.__atlasLive?.layoutIdentity);
  await page.getByTestId("parallelism-mode").click();
  const panel = page.getByTestId("parallelism-panel");
  await expect(panel.getByText("Structural separation decay")).toBeVisible();
  await expect(panel.getByText("Separated region IDs")).toBeVisible();
  await expect(panel.getByText("Greedy wave groups")).toBeVisible();
  const labels = page.getByTestId("topology-region-label");
  await labels.nth(0).click();
  await expect(panel.getByText(/Origin A/)).toBeVisible();
  await expect(panel.getByText(/Reach 1° \/ 2° \/ 3°/)).toBeVisible();
  await labels.nth(1).click({ modifiers: ["Shift"] });
  await expect(panel.getByText(/Origin B/)).toBeVisible();
  await expect(panel.getByText("Shared structural neighborhood")).toBeVisible();
  await expect(panel.getByText("Convergence depth")).toBeVisible();
  await expect(panel.locator("tbody tr")).toHaveCount(3);
  const outputs = process.env.TEST_UNDECLARED_OUTPUTS_DIR;
  if (outputs !== undefined) {
    fs.writeFileSync(path.join(outputs, "structural-separation.png"), await page.screenshot());
    fs.writeFileSync(path.join(outputs, "structural-separation-panel.png"), await panel.screenshot());
    await panel.locator("tbody").scrollIntoViewIfNeeded();
    fs.writeFileSync(path.join(outputs, "structural-pair-inspector.png"), await page.screenshot());
  }
  await panel.getByRole("button", { name: "1°" }).click();
  await expect(panel.getByRole("button", { name: "1°" })).toHaveAttribute("aria-pressed", "true");
  expect(await page.evaluate(() => window.__atlasLive?.layoutIdentity)).toBe(identity);
  await page.getByRole("button", { name: "Imports edges" }).click();
  await page.getByRole("button", { name: "Calls edges" }).click();
  await expect.poll(async () => page.evaluate(() => window.__atlasLive?.projected.aggregatedEdgeCount ?? -1)).toBe(0);
  await expect(panel.locator("tbody tr").first().locator("td")).toHaveText(["1°", "0", "0", "0", "0", "0.000"]);
  await expect(page.locator('[data-converging="true"]')).toHaveCount(0);
  await panel.getByRole("button", { name: "Clear B" }).click();
  await expect(panel.getByText(/Origin B/)).toHaveCount(0);
});

test("a region label selects its directory while graph points remain hoverable", async ({ page }) => {
  await page.goto("/");
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });

  const label = page.getByTestId("topology-region-label").filter({ hasText: "src" }).first();
  await expect(label).toBeVisible();
  await label.click();
  await expect.poll(async () => page.evaluate(() => window.__atlasLive?.selectedRegion?.region ?? null))
    .not.toBeNull();

  const position = await page.evaluate(() => window.__atlasLive?.screenPositionOf(500) ?? null);
  expect(position).not.toBeNull();
  if (position !== null) await page.mouse.move(position[0], position[1]);
  await expect.poll(async () => page.evaluate(() => window.__atlasLive?.hovered ?? null)).not.toBeNull();
});

test("one graph keeps its geometry while shading, proves derived relations, and inspects a wire", async ({
  page,
}) => {
  await page.goto("/");
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });
  const identity = await page.evaluate(() => window.__atlasLive?.layoutIdentity);
  await page.getByRole("button", { name: "Locality", exact: true }).click();
  await expect.poll(async () => page.evaluate(() => window.__atlasLive?.shading.name)).toBe("locality");
  await page.getByRole("region", { name: "Graph shading" }).getByRole("button", { name: "Reach", exact: true }).click();
  await expect.poll(async () => page.evaluate(() => window.__atlasLive?.shading.name)).toBe("reach");
  expect(await page.evaluate(() => window.__atlasLive?.layoutIdentity)).toBe(identity);

  const point = await page.evaluate(() => window.__atlasLive?.screenPositionOf(500) ?? null);
  expect(point).not.toBeNull();
  if (point !== null) await page.mouse.click(point[0], point[1]);
  await expect(page.getByTestId("lens-proofs")).toBeVisible();
  await page.getByTestId("lens-proofs").getByRole("button").first().click();
  await expect(page.getByTestId("proof-card").first()).toContainText("defines");

  await page.keyboard.press("Escape");
  const candidates = await page.evaluate(() => {
    const hook = window.__atlasLive;
    const rows = [];
    for (let index = 0; index < (hook?.projected.aggregatedEdgeCount ?? 0); index++) {
      const endpoints = hook?.projectedWireScreenEndpoints(index);
      if (endpoints === undefined || endpoints === null) continue;
      const length = Math.hypot(
        endpoints.target[0] - endpoints.source[0],
        endpoints.target[1] - endpoints.source[1],
      );
      const x = (endpoints.target[0] + endpoints.source[0]) / 2;
      const y = (endpoints.target[1] + endpoints.source[1]) / 2;
      if (length > 80 && x > 20 && x < 700 && y > 90 && y < 650) {
        rows.push({ ...endpoints, length });
      }
    }
    return rows.toSorted((a, b) => b.length - a.length).slice(0, 20);
  });
  let selected = await page.evaluate(() => window.__atlasLive?.selectedEdge ?? null);
  for (const candidate of candidates) {
    if (selected !== null) break;
    for (const fraction of [0.5, 0.35, 0.65]) {
      await page.mouse.click(
        candidate.source[0] + fraction * (candidate.target[0] - candidate.source[0]),
        candidate.source[1] + fraction * (candidate.target[1] - candidate.source[1]),
      );
      selected = await page.evaluate(() => window.__atlasLive?.selectedEdge ?? null);
      if (selected !== null) break;
    }
  }
  expect(selected).not.toBeNull();
  expect(selected?.multiplicity).toBe(selected?.provenanceCount);
  await expect(page.getByTestId("wire-inspector")).toBeVisible();
});
