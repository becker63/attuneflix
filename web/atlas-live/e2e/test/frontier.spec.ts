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
  expect(view.regions.filter((region) =>
    region.width > 5 && region.height > 5 &&
    region.x + region.width > 0 && region.x < 744 &&
    region.y + region.height > 0 && region.y < 650,
  ).length).toBeGreaterThanOrEqual(3);
  await expect(page.getByTestId("overlay")).toHaveText("Structure + families");
  const reuse = page.getByTestId("reuse-shading");
  await expect(reuse).toHaveAttribute("aria-checked", "true");
  await expect(page.getByText("1833 measured files and symbols · depth 7")).toBeVisible();
  await reuse.click();
  await expect(reuse).toHaveAttribute("aria-checked", "false");
  expect(await page.evaluate(() => window.__atlasLive?.layoutIdentity)).toBe(view.layoutIdentity);
  await reuse.click();
  await expect(reuse).toHaveAttribute("aria-checked", "true");
  await expect(page.getByRole("button", { name: "Families overlay" })).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Expand" })).toHaveCount(0);
  const outputs = process.env.TEST_UNDECLARED_OUTPUTS_DIR;
  if (outputs !== undefined) {
    fs.writeFileSync(path.join(outputs, "unified-graph.png"), await page.screenshot());
    fs.writeFileSync(path.join(outputs, "unified-regions.json"), JSON.stringify(view.regions, null, 2));
  }
});
