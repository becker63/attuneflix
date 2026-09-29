/**
 * The families layer in the browser (VAL-WEB-001..004).
 *
 * Drives the built static tree against the default world (preactjs/preact):
 * the unified graph tints members by
 * family within structural regions, while exact connection inspection happens
 * on the graph rather than through a separate family-edge list,
 * the inspector shows the family fields with the F3 honesty markers, and the
 * separate synthetic fixture remains usable without families data after all
 * 78 real snapshots receive it.
 */
import { expect, test, type Page } from "@playwright/test";

import type { AtlasFamilyMembership } from "../src/hook.ts";

/** The default world: preactjs/preact (the families export target). */
const PREACT_SNAPSHOT_PREFIX = "repository-snapshot-v1:6e2bef41";

/** The F3 export numbers (commit 33e8c22e): the preact families are frozen evidence. */
const PREACT_FAMILIES = {
  familyCount: 159,
  singletonFamilies: 29,
  fallbackMembers: 166,
  unattributedEdges: 36,
};

interface ManifestWorld {
  snapshotId: string;
  counts: { symbols: number };
  assets: Record<string, unknown>;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isManifestWorld(value: unknown): value is ManifestWorld {
  return (
    isRecord(value) &&
    typeof value["snapshotId"] === "string" &&
    isRecord(value["counts"]) &&
    typeof value["counts"]["symbols"] === "number" &&
    isRecord(value["assets"])
  );
}

async function waitReady(page: Page, snapshotId: string, revision: number): Promise<void> {
  await page.waitForFunction(
    ({ id, rev }) => {
      const hook = window.__atlasLive;
      return hook?.ready === true && hook.snapshotId === id && hook.sessionRevision >= rev;
    },
    { id: snapshotId, rev: revision },
    { timeout: 90_000 },
  );
  await page.waitForTimeout(500);
}

/** The default world is preact; returns its snapshot id once ready. */
async function readyPreact(page: Page): Promise<string> {
  await page.goto("/");
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });
  const snapshotId = await page.evaluate(() => window.__atlasLive?.snapshotId ?? null);
  expect(snapshotId, "the default world loads").not.toBeNull();
  expect(snapshotId, "the default world is preact").toContain(PREACT_SNAPSHOT_PREFIX);
  await page.waitForTimeout(500);
  return snapshotId ?? "";
}

async function openPicker(page: Page): Promise<void> {
  await page.getByTestId("dataset-picker").click();
  await expect(page.getByRole("listbox")).toBeVisible();
}

async function selectDataset(page: Page, snapshotId: string): Promise<void> {
  await openPicker(page);
  const option = page.locator(`[data-snapshot-id="${snapshotId}"]`);
  await expect(option).toBeVisible();
  await option.click();
}

async function canvasRect(page: Page): Promise<{ x: number; y: number; width: number; height: number }> {
  const rect = await page.evaluate(() => {
    for (const canvas of document.querySelectorAll("canvas")) {
      const context = canvas.getContext("webgl2");
      if (context === null) continue;
      const box = canvas.getBoundingClientRect();
      return { x: box.x, y: box.y, width: box.width, height: box.height };
    }
    return null;
  });
  expect(rect, "a WebGL2 canvas is present").not.toBeNull();
  return rect ?? { x: 0, y: 0, width: 1, height: 1 };
}

test("structure and families are visible in the same graph", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  await readyPreact(page);

  const summary = await page.evaluate(() => window.__atlasLive?.families ?? null);
  expect(summary).not.toBeNull();
  expect(summary?.familyCount).toBe(PREACT_FAMILIES.familyCount);
  expect(summary?.singletonFamilies).toBe(PREACT_FAMILIES.singletonFamilies);
  expect(summary?.fallbackMembers).toBe(PREACT_FAMILIES.fallbackMembers);
  expect(summary?.unattributedEdges).toBe(PREACT_FAMILIES.unattributedEdges);
  expect(summary?.renderedEdges ?? 0).toBeGreaterThan(0);
  expect(summary?.edges ?? 0).toBeGreaterThanOrEqual(summary?.renderedEdges ?? 0);

  const graph = await page.evaluate(() => {
    const hook = window.__atlasLive;
    if (hook === undefined) throw new Error("no diagnostics hook");
    const families = new Set<number>();
    for (let index = 0; index < hook.pointCount(); index++) {
      const member = hook.familyOfPoint(index);
      if (member !== null) families.add(member.ordinal);
    }
    return {
      layout: hook.layoutIdentity,
      points: hook.pointCount(),
      visible: hook.visibleNodeIds().length,
      familyCount: families.size,
      symbolPosition: hook.screenPositionOf(500),
    };
  });
  expect(graph.layout).toMatch(/^topology-v1:[0-9a-f]+$/);
  expect(graph.visible).toBe(graph.points);
  expect(graph.familyCount).toBe(PREACT_FAMILIES.familyCount);
  expect(graph.symbolPosition).not.toBeNull();
  await expect(page.getByTestId("overlay")).toHaveText("Structure + families");
  await expect(page.getByText("Family tint")).toBeVisible();
  await expect(page.getByText("No family")).toBeVisible();
  await expect(page.getByRole("button", { name: "Families overlay" })).toHaveCount(0);
  expect(consoleErrors).toEqual([]);
});

test("the inspector shows the family fields with the honesty markers", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  await readyPreact(page);

  // Fallback and singleton members (F3: both exist on preact). At the fitted
  // zoom points overlap, so hovering zooms into the candidate's neighbourhood
  // until the points separate (what a user would do).
  const candidates = await page.evaluate(() => {
    const hook = window.__atlasLive;
    if (hook === undefined) throw new Error("no diagnostics hook");
    const count = hook.pointCount();
    const fallback: number[] = [];
    const singleton: number[] = [];
    for (let index = 0; index < count; index++) {
      const membership = hook.familyOfPoint(index);
      if (membership === null) continue;
      if (membership.fallback && fallback.length < 8) fallback.push(index);
      if (membership.singleton && singleton.length < 8) singleton.push(index);
    }
    return { fallback, singleton };
  });
  expect(candidates.fallback.length, "fallback members exist (166 recorded)").toBeGreaterThan(0);
  expect(candidates.singleton.length, "singleton members exist (29 recorded)").toBeGreaterThan(0);

  /** The wheel delta that zooms in, detected once from the camera. */
  const zoomDirection = async (): Promise<number> => {
    const before = await page.evaluate(() => window.__atlasLive?.camera.zoom ?? 0);
    await page.mouse.move(400, 300);
    await page.mouse.wheel(0, -240);
    await page.waitForTimeout(300);
    const after = await page.evaluate(() => window.__atlasLive?.camera.zoom ?? 0);
    return (after ?? 0) > (before ?? 0) ? -240 : 240;
  };

  /**
   * Hovers one candidate: zooms toward it (first attempt only), re-reads its
   * screen position at the new camera, and returns the membership of the point
   * that actually registered the hover, or null when nothing registered.
   */
  const hoverMembership = async (
    index: number,
    zoomDelta: number,
    zoomed: boolean,
  ): Promise<{ hovered: number; membership: AtlasFamilyMembership } | null> => {
    const before = await page.evaluate((i) => window.__atlasLive?.screenPositionOf(i) ?? null, index);
    if (before === null) return null;
    if (!zoomed) {
      await page.mouse.move(before[0], before[1]);
      for (let step = 0; step < 6; step++) await page.mouse.wheel(0, zoomDelta);
      await page.waitForTimeout(800);
    }
    const position = await page.evaluate((i) => window.__atlasLive?.screenPositionOf(i) ?? null, index);
    if (position === null) return null;
    await page.mouse.move(position[0] + 1, position[1] + 1);
    await page.mouse.move(position[0], position[1]);
    let hovered: number | null = null;
    try {
      await expect
        .poll(async () => page.evaluate(() => window.__atlasLive?.hoveredIndex ?? null), {
          timeout: 5000,
          intervals: [50, 100, 200, 400],
        })
        .not.toBeNull();
      hovered = await page.evaluate(() => window.__atlasLive?.hoveredIndex ?? null);
    } catch {
      return null;
    }
    if (hovered === null) return null;
    const membership = await page.evaluate((i) => window.__atlasLive?.familyOfPoint(i) ?? null, hovered);
    if (membership === null) return null;
    return { hovered, membership };
  };

  const panel = page.locator("aside");
  const zoomDelta = await zoomDirection();

  // A fallback member: the inspector shows its family fields and the marker.
  let fallbackSeen = false;
  let zoomed = false;
  for (const index of candidates.fallback) {
    const hit = await hoverMembership(index, zoomDelta, zoomed);
    zoomed = true;
    if (hit === null || !hit.membership.fallback) continue;
    await expect(panel.getByText("Family", { exact: true })).toBeVisible();
    // The value cell also holds the marker badges, so match the name as a substring.
    await expect(panel).toContainText(hit.membership.name);
    // The row's text is label + value ("Family members" + the count).
    await expect(
      panel
        .locator("div")
        .filter({ hasText: new RegExp(`^Family members${String(hit.membership.members)}$`) }),
    ).toBeVisible();
    // The fallback marker: this member joined its defining file's seed family.
    await expect(panel.getByText("fallback", { exact: true })).toBeVisible();
    fallbackSeen = true;
    break;
  }
  expect(fallbackSeen, "a fallback member was inspected").toBe(true);

  // A singleton member: fresh page (the camera resets), then the same drive.
  await readyPreact(page);
  zoomed = false;
  let singletonSeen = false;
  for (const index of candidates.singleton) {
    const hit = await hoverMembership(index, zoomDelta, zoomed);
    zoomed = true;
    if (hit === null || !hit.membership.singleton) continue;
    // The singleton marker: this family has exactly one member.
    await expect(panel.getByText("singleton", { exact: true })).toBeVisible();
    await expect(panel.locator("div").filter({ hasText: /^Family members1$/ })).toBeVisible();
    singletonSeen = true;
    break;
  }
  expect(singletonSeen, "a singleton member was inspected").toBe(true);

  expect(consoleErrors, "no console errors").toEqual([]);
});

test("family edge evidence remains in the one graph without a separate sidebar list", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });

  await readyPreact(page);

  // The typed family-edge evidence remains available, but graph wires own the
  // connection interaction instead of a competing sidebar ranking.
  const rendered = await page.evaluate(() => window.__atlasLive?.families?.renderedEdges ?? 0);
  expect(rendered).toBeGreaterThan(0);
  await expect(page.getByTestId("family-edges")).toHaveCount(0);
  await expect(page.getByTestId("reuse-comparison-current")).toContainText("159 families");
  expect(await page.evaluate(() => window.__atlasLive?.drilledFamilyEdge ?? null)).toBeNull();

  expect(consoleErrors, "no console errors").toEqual([]);
});

test("the synthetic fixture renders without families data", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });

  await readyPreact(page);

  // The synthetic stress fixture remains outside the 78-world acquisition.
  const response = await page.request.get("/manifest.json");
  expect(response.ok()).toBe(true);
  const manifest: unknown = await response.json();
  if (!isRecord(manifest)) throw new Error("bad manifest shape");
  const synthetic = isManifestWorld(manifest["synthetic"]) ? manifest["synthetic"] : null;
  expect(synthetic, "the synthetic fixture exists").not.toBeNull();
  expect(synthetic?.assets["families"], "the synthetic fixture has no families export").toBeUndefined();
  const target = synthetic?.snapshotId ?? "";

  await selectDataset(page, target);
  await waitReady(page, target, 2);

  const after = await page.evaluate(() => {
    const hook = window.__atlasLive;
    return {
      families: hook?.families ?? null,
      overlay: hook?.overlay ?? null,
      drilled: hook?.drilledFamilyEdge ?? null,
      layoutIdentity: hook?.layoutIdentity ?? null,
      membership: hook?.familyOfPoint(0) ?? null,
    };
  });
  expect(after.families).toBeNull();
  expect(after.overlay?.name).toBe("structure");
  expect(after.drilled).toBeNull();
  expect(after.membership).toBeNull();
  expect(after.layoutIdentity).toMatch(/^structure-v1:[0-9a-f]+$/);

  // No families affordances: the toggle is absent, the section is gone, and
  // the legend is the structure legend.
  await expect(page.getByRole("button", { name: "Families overlay" })).toHaveCount(0);
  await expect(page.getByTestId("overlay")).toHaveText("Structure");
  await expect(page.getByTestId("family-edges")).toHaveCount(0);
  await expect(page.getByText("File", { exact: true })).toBeVisible();
  await expect(page.getByText("Symbol", { exact: true })).toBeVisible();

  // The canvas still paints.
  const rect = await canvasRect(page);
  const png = await page.screenshot({ clip: rect });
  const painted = await page.evaluate(async (base64) => {
    const image = new Image();
    image.src = `data:image/png;base64,${base64}`;
    await image.decode();
    const canvas = document.createElement("canvas");
    canvas.width = image.width;
    canvas.height = image.height;
    const context = canvas.getContext("2d");
    if (context === null) throw new Error("no 2d context");
    context.drawImage(image, 0, 0);
    const data = context.getImageData(0, 0, canvas.width, canvas.height).data;
    let count = 0;
    for (let i = 0; i < data.length; i += 4) {
      const delta =
        Math.abs((data[i] ?? 0) - 11) + Math.abs((data[i + 1] ?? 0) - 13) + Math.abs((data[i + 2] ?? 0) - 18);
      if (delta > 24) count++;
    }
    return count;
  }, png.toString("base64"));
  expect(painted, "the families-less synthetic world paints non-blank").toBeGreaterThan(1000);

  expect(consoleErrors, "no console errors").toEqual([]);
});
