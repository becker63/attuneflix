/**
 * The families layer in the browser (VAL-WEB-001..004).
 *
 * Drives the built static tree against the default world (preactjs/preact, the
 * one world with a families export): the Families overlay tints every point by
 * its family (same family, same tint; never a domain colour), the sidebar lists
 * the cross-family edges and drills one down to its contributing exact edges,
 * the inspector shows the family fields with the F3 honesty markers, and a
 * world without families data renders exactly as before (no toggle, no family
 * fields, same layout identity format).
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

const BACKGROUND = { r: 11, g: 13, b: 18 };
const DOMAIN_COLOURS = [
  { r: 0x4e, g: 0x79, b: 0xa7 }, // file
  { r: 0xf2, g: 0x8e, b: 0x2b }, // symbol
  { r: 0x59, g: 0xa1, b: 0x4f }, // directory
];

interface Rgb {
  r: number;
  g: number;
  b: number;
}

function near(a: Rgb, b: Rgb, tolerance = 12): boolean {
  return Math.abs(a.r - b.r) + Math.abs(a.g - b.g) + Math.abs(a.b - b.b) <= tolerance;
}

function isDomainColour(pixel: Rgb): boolean {
  return DOMAIN_COLOURS.some((colour) => near(pixel, colour));
}

/** The most common colour among the samples (exact rgb, no tolerance). */
function modalColour(pixels: readonly Rgb[]): Rgb {
  const counts = new Map<string, { colour: Rgb; count: number }>();
  for (const pixel of pixels) {
    const key = `${String(pixel.r)},${String(pixel.g)},${String(pixel.b)}`;
    const entry = counts.get(key) ?? { colour: pixel, count: 0 };
    entry.count += 1;
    counts.set(key, entry);
  }
  return [...counts.values()].toSorted((a, b) => b.count - a.count)[0]?.colour ?? BACKGROUND;
}

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

/** Decodes a screenshot of the canvas and reads the pixels at the given viewport positions. */
async function samplePixels(
  page: Page,
  positions: readonly (readonly [number, number])[],
): Promise<(Rgb | null)[]> {
  const rect = await canvasRect(page);
  const png = await page.screenshot({ clip: rect });
  return page.evaluate(
    async ({ base64, points, origin }) => {
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
      return points.map(([sx, sy]) => {
        const x = Math.round(sx - origin.x);
        const y = Math.round(sy - origin.y);
        if (x < 0 || y < 0 || x >= canvas.width || y >= canvas.height) return null;
        const offset = (y * canvas.width + x) * 4;
        return { r: data[offset] ?? 0, g: data[offset + 1] ?? 0, b: data[offset + 2] ?? 0 };
      });
    },
    { base64: png.toString("base64"), points: positions, origin: rect },
  );
}

/** Counts pixels that differ (channel-sum delta over 24) between two canvas screenshots. */
async function diffCanvas(page: Page, before: Buffer, after: Buffer): Promise<number> {
  return page.evaluate(
    async ({ a, b }) => {
      // oxlint-disable-next-line unicorn/consistent-function-scoping -- page.evaluate serializes this function's source into the browser realm; a module-scope helper would not cross.
      const decode = async (base64: string): Promise<ImageData> => {
        const image = new Image();
        image.src = `data:image/png;base64,${base64}`;
        await image.decode();
        const canvas = document.createElement("canvas");
        canvas.width = image.width;
        canvas.height = image.height;
        const context = canvas.getContext("2d");
        if (context === null) throw new Error("no 2d context");
        context.drawImage(image, 0, 0);
        return context.getImageData(0, 0, canvas.width, canvas.height);
      };
      const first = await decode(a);
      const second = await decode(b);
      if (first.width !== second.width || first.height !== second.height) return Number.MAX_SAFE_INTEGER;
      let count = 0;
      for (let i = 0; i < first.data.length; i += 4) {
        const delta =
          Math.abs((first.data[i] ?? 0) - (second.data[i] ?? 0)) +
          Math.abs((first.data[i + 1] ?? 0) - (second.data[i + 1] ?? 0)) +
          Math.abs((first.data[i + 2] ?? 0) - (second.data[i + 2] ?? 0));
        if (delta > 24) count++;
      }
      return count;
    },
    { a: before.toString("base64"), b: after.toString("base64") },
  );
}

/** A screenshot of just the graph canvas. */
async function canvasShot(page: Page): Promise<Buffer> {
  return page.screenshot({ clip: await canvasRect(page) });
}

test("the families overlay tints points by family on the unchanged layout", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });

  await readyPreact(page);

  // The projected families summary is the frozen F3 evidence.
  const summary = await page.evaluate(() => window.__atlasLive?.families ?? null);
  expect(summary).not.toBeNull();
  expect(summary?.familyCount).toBe(PREACT_FAMILIES.familyCount);
  expect(summary?.singletonFamilies).toBe(PREACT_FAMILIES.singletonFamilies);
  expect(summary?.fallbackMembers).toBe(PREACT_FAMILIES.fallbackMembers);
  expect(summary?.unattributedEdges).toBe(PREACT_FAMILIES.unattributedEdges);
  expect(summary?.renderedEdges ?? 0).toBeGreaterThan(0);
  expect(summary?.edges ?? 0).toBeGreaterThanOrEqual(summary?.renderedEdges ?? 0);

  // Sample members of the two largest families: symbols with no point of
  // ANOTHER family within a few screen pixels (at the fitted zoom points
  // overlap, and an occluding symbol of another family would paint its own
  // tint over the sampled centre).
  const familiesSample = await page.evaluate(() => {
    const hook = window.__atlasLive;
    if (hook === undefined) throw new Error("no diagnostics hook");
    const count = hook.pointCount();
    const points: { index: number; family: number; position: [number, number] }[] = [];
    for (let index = 0; index < count; index++) {
      const membership = hook.familyOfPoint(index);
      const position = hook.screenPositionOf(index);
      if (position === null) continue;
      points.push({ index, family: membership?.ordinal ?? -1, position });
    }
    const isolated = (family: number): { index: number; position: [number, number] }[] =>
      points
        .filter(
          (point) =>
            point.family === family &&
            points.every(
              (other) =>
                other.index === point.index ||
                other.family === family ||
                Math.hypot(other.position[0] - point.position[0], other.position[1] - point.position[1]) >= 5,
            ),
        )
        .slice(0, 12);
    const sizes = new Map<number, number>();
    for (const point of points) {
      if (point.family >= 0) sizes.set(point.family, (sizes.get(point.family) ?? 0) + 1);
    }
    const largest = [...sizes.entries()].toSorted((a, b) => b[1] - a[1]).slice(0, 2);
    return largest.map(([family]) => isolated(family));
  });
  expect(familiesSample.length).toBe(2);
  const firstFamily = familiesSample[0] ?? [];
  const secondFamily = familiesSample[1] ?? [];
  expect(firstFamily.length, "isolated members of the largest family").toBeGreaterThanOrEqual(3);
  expect(secondFamily.length, "isolated members of the second family").toBeGreaterThanOrEqual(2);

  const layoutBefore = await page.evaluate(() => {
    const hook = window.__atlasLive;
    const count = hook?.pointCount() ?? 0;
    const samples = [0, 1, Math.floor(count / 3), Math.floor(count / 2), count - 1];
    return {
      identity: hook?.layoutIdentity ?? null,
      filterRevision: hook?.filterRevision ?? -1,
      positions: samples.map((index) => hook?.screenPositionOf(index) ?? null),
    };
  });
  const structureShot = await canvasShot(page);
  const firstPositions = firstFamily
    .map((member) => member.position)
    .filter((position): position is [number, number] => position !== null);
  const secondPositions = secondFamily
    .map((member) => member.position)
    .filter((position): position is [number, number] => position !== null);
  const structureFirst = await samplePixels(page, firstPositions);
  const structureSecond = await samplePixels(page, secondPositions);
  const symbolColour = DOMAIN_COLOURS[1] ?? { r: 0, g: 0, b: 0 };
  const cleanFirst = firstPositions.filter((_, i) => {
    const pixel = structureFirst[i];
    return pixel != null && near(pixel, symbolColour);
  });
  const cleanSecond = secondPositions.filter((_, i) => {
    const pixel = structureSecond[i];
    return pixel != null && near(pixel, symbolColour);
  });
  expect(cleanFirst.length, "unoccluded symbol centres in the largest family").toBeGreaterThanOrEqual(3);
  expect(cleanSecond.length, "unoccluded symbol centres in the second family").toBeGreaterThanOrEqual(2);

  // Switch to the Families overlay.
  await page.getByRole("button", { name: "Families overlay" }).click();
  await page.waitForFunction(() => window.__atlasLive?.overlay.name === "families", null, {
    timeout: 10_000,
  });
  await page.waitForTimeout(500);

  // The overlay is a view change only: the layout and the filter never move.
  const layoutAfter = await page.evaluate(() => {
    const hook = window.__atlasLive;
    const count = hook?.pointCount() ?? 0;
    const samples = [0, 1, Math.floor(count / 3), Math.floor(count / 2), count - 1];
    return {
      identity: hook?.layoutIdentity ?? null,
      filterRevision: hook?.filterRevision ?? -1,
      revision: hook?.overlay.revision ?? -1,
      positions: samples.map((index) => hook?.screenPositionOf(index) ?? null),
    };
  });
  expect(layoutAfter.identity).toBe(layoutBefore.identity);
  expect(layoutAfter.positions).toEqual(layoutBefore.positions);
  expect(layoutAfter.filterRevision).toBe(layoutBefore.filterRevision);
  expect(layoutAfter.revision).toBeGreaterThanOrEqual(1);

  // The legend reads the same vocabulary: the two tint classes appear.
  await expect(page.getByText("Family tint")).toBeVisible();
  await expect(page.getByText("No family")).toBeVisible();

  // The canvas actually repaints.
  const familiesShot = await canvasShot(page);
  const diff = await diffCanvas(page, structureShot, familiesShot);
  const rect = await canvasRect(page);
  expect(diff / (rect.width * rect.height), "the overlay repaints over 1% of the canvas").toBeGreaterThan(
    0.01,
  );

  // Same family, one modal tint; never a domain colour; a different family
  // differs. In dense spots a point of another family can still paint over a
  // sampled centre (points overlap at the fitted zoom), so each family is
  // judged by its modal colour with a strict majority, not by unanimity.
  const tintedFirst = await samplePixels(page, cleanFirst);
  const tintedSecond = await samplePixels(page, cleanSecond);
  const firstTint = tintedFirst.filter((pixel): pixel is Rgb => pixel !== null && !near(pixel, BACKGROUND));
  const secondTint = tintedSecond.filter((pixel): pixel is Rgb => pixel !== null && !near(pixel, BACKGROUND));
  expect(firstTint.length).toBeGreaterThanOrEqual(3);
  expect(secondTint.length).toBeGreaterThanOrEqual(2);
  const firstModal = modalColour(firstTint);
  const secondModal = modalColour(secondTint);
  expect(
    firstTint.filter((pixel) => near(pixel, firstModal)).length / firstTint.length,
    "the largest family's modal tint covers a strict majority",
  ).toBeGreaterThan(0.5);
  expect(
    secondTint.filter((pixel) => near(pixel, secondModal)).length / secondTint.length,
    "the second family's modal tint covers a strict majority",
  ).toBeGreaterThan(0.5);
  expect(isDomainColour(firstModal), "a family tint is never a domain colour").toBe(false);
  expect(isDomainColour(secondModal), "a family tint is never a domain colour").toBe(false);
  expect(near(firstModal, secondModal), "two families, two tints").toBe(false);

  expect(consoleErrors, "no console errors").toEqual([]);
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

test("a family edge drills down to its contributing exact edges", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });

  await readyPreact(page);

  // The families overlay lists the cross-family edges, strongest first.
  await page.getByRole("button", { name: "Families overlay" }).click();
  await page.waitForFunction(() => window.__atlasLive?.overlay.name === "families", null, {
    timeout: 10_000,
  });
  await page.waitForTimeout(500);
  const rendered = await page.evaluate(() => window.__atlasLive?.families?.renderedEdges ?? 0);
  expect(rendered).toBeGreaterThan(0);
  const section = page.getByTestId("family-edges");
  await expect(section).toBeVisible();
  await expect(section).toContainText(`Family edges (${String(rendered)})`);
  // The F3 honesty counts read in the summary line.
  await expect(section).toContainText(`${String(PREACT_FAMILIES.singletonFamilies)} singletons`);

  const before = await canvasShot(page);

  // Drill into the strongest edge.
  const firstEdge = section.locator("[data-testid^='family-edge-']").first();
  const label = (await firstEdge.textContent()) ?? "";
  const multiplicity = Number(/×(\d+)/.exec(label)?.[1] ?? "0");
  expect(multiplicity, "the edge button carries its multiplicity").toBeGreaterThan(0);
  await firstEdge.click();

  const drilled = await page.evaluate(() => window.__atlasLive?.drilledFamilyEdge ?? null);
  expect(drilled).not.toBeNull();

  // The drill-down lists the contributing exact edges, bounded and counted.
  const drill = page.getByTestId("family-drill");
  await expect(drill).toBeVisible();
  const shown = Math.min(multiplicity, 25);
  await expect(drill.locator("[data-testid^='contribution-']")).toHaveCount(shown);
  if (multiplicity > 25) {
    await expect(drill).toContainText(`+${String(multiplicity - 25)} more contributing edges`);
  }

  // The canvas repaints: the drilled edge's exact links reappear.
  await page.waitForTimeout(500);
  const after = await canvasShot(page);
  expect(await diffCanvas(page, before, after), "the drill-down repaints the canvas").toBeGreaterThan(50);

  // Clearing the drill-down restores the aggregate view.
  await page.getByRole("button", { name: "Clear drill-down" }).click();
  await expect
    .poll(async () => page.evaluate(() => window.__atlasLive?.drilledFamilyEdge ?? null), { timeout: 5000 })
    .toBeNull();

  expect(consoleErrors, "no console errors").toEqual([]);
});

test("a world without families data renders exactly as before", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });

  await readyPreact(page);

  // The smallest census world (axios) ships no families data.
  const response = await page.request.get("/manifest.json");
  expect(response.ok()).toBe(true);
  const manifest: unknown = await response.json();
  if (!isRecord(manifest) || !Array.isArray(manifest["worlds"])) throw new Error("bad manifest shape");
  const withoutFamilies = manifest["worlds"]
    .filter(isManifestWorld)
    .filter((world) => world.assets["families"] === undefined)
    .toSorted((a, b) => a.counts.symbols - b.counts.symbols);
  const target = withoutFamilies[0]?.snapshotId ?? null;
  expect(target, "a world without families data exists").not.toBeNull();

  await selectDataset(page, target ?? "");
  await waitReady(page, target ?? "", 2);

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

  // No families affordances: the toggle is disabled, the section is gone, and
  // the legend is the structure legend.
  await expect(page.getByRole("button", { name: "Families overlay" })).toBeDisabled();
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
  expect(painted, "a families-less world paints non-blank").toBeGreaterThan(1000);

  expect(consoleErrors, "no console errors").toEqual([]);
});
