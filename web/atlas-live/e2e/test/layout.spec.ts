/**
 * The structural layout in the browser (VAL-LAYOUT-001, VAL-LAYOUT-003).
 *
 * Geometry is a pure function of the exact world: reloading the same world
 * yields the same `layoutIdentity` and the same screen positions at the same
 * (fitted) camera, and toggling relation filters moves nothing while
 * `filterRevision` advances.
 */
import { expect, test, type Page } from "@playwright/test";

interface LayoutRead {
  snapshotId: string | null;
  layoutIdentity: string | null;
  layoutRevision: number;
  layoutMs: number | null;
  filterRevision: number;
  positions: ([number, number] | null)[];
}

async function waitReady(page: Page): Promise<void> {
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });
  await page.waitForTimeout(500);
}

async function readLayout(page: Page): Promise<LayoutRead> {
  return page.evaluate(() => {
    const live = window.__atlasLive;
    if (live === undefined) throw new Error("no diagnostics hook");
    const count = live.pointCount();
    const samples = [0, 1, Math.floor(count / 3), Math.floor(count / 2), count - 1];
    return {
      snapshotId: live.snapshotId,
      layoutIdentity: live.layoutIdentity,
      layoutRevision: live.layoutRevision,
      layoutMs: live.perf.layoutMs ?? null,
      filterRevision: live.filterRevision,
      positions: samples.map((index) => live.screenPositionOf(index)),
    };
  });
}

test("reloading the same world reproduces the layout identity and screen positions", async ({ page }) => {
  await page.goto("/");
  await waitReady(page);
  const first = await readLayout(page);
  expect(first.layoutIdentity).toMatch(/^structure-v1:[0-9a-f]+$/);
  expect(first.layoutRevision).toBeGreaterThanOrEqual(1);
  expect(first.layoutMs).not.toBeNull();
  expect(first.layoutMs ?? -1).toBeGreaterThanOrEqual(0);
  for (const position of first.positions) expect(position).not.toBeNull();

  await page.reload();
  await waitReady(page);
  const second = await readLayout(page);
  expect(second.snapshotId).toBe(first.snapshotId);
  expect(second.layoutIdentity).toBe(first.layoutIdentity);
  expect(second.positions).toEqual(first.positions);
});

test("relation filters leave the layout and screen positions unchanged", async ({ page }) => {
  await page.goto("/");
  await waitReady(page);
  const before = await readLayout(page);

  for (const relation of ["imports", "calls", "parent", "defines"]) {
    await page.getByRole("button", { name: `${relation} edges` }).click();
  }
  await page.waitForTimeout(500);
  const hidden = await readLayout(page);
  expect(hidden.filterRevision).toBeGreaterThan(before.filterRevision);
  expect(hidden.layoutIdentity).toBe(before.layoutIdentity);
  expect(hidden.layoutRevision).toBe(before.layoutRevision);
  expect(hidden.positions).toEqual(before.positions);

  for (const relation of ["imports", "calls", "parent", "defines"]) {
    await page.getByRole("button", { name: `${relation} edges` }).click();
  }
  await page.waitForTimeout(500);
  const restored = await readLayout(page);
  expect(restored.filterRevision).toBeGreaterThan(hidden.filterRevision);
  expect(restored.layoutIdentity).toBe(before.layoutIdentity);
  expect(restored.positions).toEqual(before.positions);
});
