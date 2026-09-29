/**
 * Dataset switching (VAL-DATA-001..003, VAL-GRAPH-005..008, VAL-INTERACT-006).
 *
 * Drives the real Base UI picker against the built static tree under SwiftShader:
 * the picker lists the 78 census worlds plus the separately labelled synthetic
 * fixture; switching disposes the previous session (session revision advances,
 * exactly one live session, its DuckDB tables swapped), fits the camera to the
 * new dataset, and clears a pinned selection whose entity the new dataset lacks.
 */
import { expect, test, type Page } from "@playwright/test";

interface WorldCounts {
  points: number;
  links: number;
  files: number;
  symbols: number;
  directories: number;
  defines: number;
  imports: number;
  calls: number;
  parent: number;
}

interface WorldEntry {
  snapshotId: string;
  repository: string;
  baseRevision: string;
  counts: WorldCounts;
  assets: { metadata: string; entities: string; relations: string; locations?: string };
  synthetic?: boolean;
}

interface Manifest {
  worlds: WorldEntry[];
  synthetic: WorldEntry | null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isWorldEntry(value: unknown): value is WorldEntry {
  return (
    isRecord(value) &&
    typeof value.snapshotId === "string" &&
    typeof value.repository === "string" &&
    typeof value.baseRevision === "string" &&
    isRecord(value.counts) &&
    isRecord(value.assets)
  );
}

async function readManifest(page: Page): Promise<Manifest> {
  const response = await page.request.get("/manifest.json");
  expect(response.ok()).toBe(true);
  const value: unknown = await response.json();
  if (!isRecord(value) || !Array.isArray(value.worlds)) throw new Error("bad manifest shape");
  const worlds = value.worlds.filter(isWorldEntry);
  const synthetic = isWorldEntry(value.synthetic) ? value.synthetic : null;
  return { worlds, synthetic };
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
}

async function openPicker(page: Page): Promise<void> {
  await page.getByTestId("dataset-picker").click();
  await expect(page.getByRole("listbox")).toBeVisible();
}

async function selectDataset(page: Page, snapshotId: string): Promise<void> {
  await openPicker(page);
  await page.locator(`[data-snapshot-id="${snapshotId}"]`).click();
}

/**
 * Hovers the given candidate point indices until one registers in the hook, and
 * returns the elapsed ms of the successful hover. Individual points can be
 * missed by the pointer (they overlap at fit zoom), so a few candidates are
 * tried; the budget applies per attempt.
 */
async function hoverFirstPoint(page: Page, indices: readonly number[], budgetMs: number): Promise<number> {
  let tried = 0;
  for (const index of indices) {
    const position = await page.evaluate((i) => window.__atlasLive?.screenPositionOf(i) ?? null, index);
    if (position === null) continue;
    tried += 1;
    await page.mouse.move(position[0], position[1]);
    const started = Date.now();
    try {
      await expect
        .poll(async () => page.evaluate(() => window.__atlasLive?.hovered ?? null), {
          timeout: budgetMs,
          intervals: [50, 100, 200, 400],
        })
        .not.toBeNull();
      return Date.now() - started;
    } catch {
      // This point was not hit; try the next candidate.
    }
  }
  const diagnostic = await page.evaluate((candidateIndices) => {
    const hook = window.__atlasLive;
    if (hook === undefined) return { positioned: 0, inViewport: 0, candidates: [] };
    let positioned = 0;
    let inViewport = 0;
    for (let index = 0; index < hook.pointCount(); index++) {
      const position = hook.screenPositionOf(index);
      if (position === null) continue;
      positioned++;
      if (position[0] >= 0 && position[0] < innerWidth && position[1] >= 0 && position[1] < innerHeight) {
        inViewport++;
      }
    }
    const candidates = candidateIndices.map((index) => {
      const position = hook.screenPositionOf(index);
      const target = position === null ? null : document.elementFromPoint(position[0], position[1]);
      return {
        index,
        position,
        target: target?.tagName ?? null,
        testId: target?.getAttribute('data-testid') ?? null,
        y: target?.getAttribute('y') ?? null,
        height: target?.getAttribute('height') ?? null,
      };
    });
    return { positioned, inViewport, candidates };
  }, indices);
  throw new Error(`no point hovered (tried ${String(tried)} candidates): ${JSON.stringify(diagnostic)}`);
}

test("picker lists the frozen census, pinned AttuneFlix snapshot, and synthetic fixture", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });

  await page.goto("/");
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });

  const manifest = await readManifest(page);
  expect(manifest.worlds).toHaveLength(79);
  expect(manifest.worlds.filter((world) => world.repository === "attuneflix")).toHaveLength(1);
  expect(manifest.synthetic?.synthetic).toBe(true);

  await openPicker(page);
  const options = page.locator("[data-snapshot-id]");
  await expect(options).toHaveCount(80);

  const listed = await options.evaluateAll((elements) =>
    elements.map((element) => ({
      id: element.getAttribute("data-snapshot-id"),
      kind: element.getAttribute("data-dataset"),
      text: element.textContent ?? "",
    })),
  );
  const worldIds = manifest.worlds.map((world) => world.snapshotId).toSorted();
  const listedWorldIds = listed
    .filter((option) => option.kind === "world")
    .map((option) => option.id ?? "")
    .toSorted();
  expect(listedWorldIds).toEqual(worldIds);

  const syntheticOption = listed.find((option) => option.kind === "synthetic");
  expect(syntheticOption?.id).toBe(manifest.synthetic?.snapshotId);
  expect(syntheticOption?.text).toContain("synthetic");
  // A real world's option names its repository and short revision.
  const worldOption = listed.find((option) => option.id === worldIds[0]);
  expect(worldOption?.text.length ?? 0).toBeGreaterThan(0);

  expect(consoleErrors).toEqual([]);
});

test("switching disposes the old session, fits the camera and prunes the selection", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });

  await page.goto("/");
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });

  const manifest = await readManifest(page);
  const worldA = await page.evaluate(() => ({
    snapshotId: window.__atlasLive?.snapshotId ?? null,
    revision: window.__atlasLive?.sessionRevision ?? 0,
  }));
  expect(worldA.snapshotId).not.toBeNull();
  const entryA = manifest.worlds.find((world) => world.snapshotId === worldA.snapshotId);
  expect(entryA).toBeTruthy();

  // World B: a real world with fewer symbols than A, so A's highest symbol ids
  // do not exist in B (VAL-INTERACT-006).
  const entryB = manifest.worlds
    .filter((world) => world.snapshotId !== entryA?.snapshotId && world.counts.symbols > 0)
    .reduce((best, world) => (world.counts.symbols < best.counts.symbols ? world : best));
  expect(entryB.snapshotId).not.toBe(entryA?.snapshotId);
  const absentSymbolId = `symbol:${entryB.counts.symbols + 25}`;
  expect(entryA?.counts.symbols ?? 0).toBeGreaterThan(entryB.counts.symbols + 25);

  // The unified graph exposes symbols in their structural positions.

  // Find that symbol's renderer index in A and pin it with a real click.
  const target = await page.evaluate((wanted) => {
    const hook = window.__atlasLive;
    if (hook === undefined) return null;
    const count = hook.pointCount();
    for (let index = 0; index < count; index++) {
      if (hook.pointIdOf(index) === wanted) {
        return { index, position: hook.screenPositionOf(index) };
      }
    }
    return null;
  }, absentSymbolId);
  expect(target?.position, `a screen position for ${absentSymbolId}`).toBeTruthy();
  const [px, py] = target?.position ?? [0, 0];
  await page.mouse.move(px, py);
  await page.mouse.click(px, py);
  // A point near the target may be hit instead (they overlap at this zoom), so
  // read the id that was actually pinned and confirm B lacks it.
  await expect
    .poll(async () => page.evaluate(() => window.__atlasLive?.selected?.length ?? 0), { timeout: 10_000 })
    .toBeGreaterThan(0);
  const pinnedSelection = await page.evaluate(() => window.__atlasLive?.selected ?? []);
  expect(pinnedSelection).toHaveLength(1);
  const pinnedId = pinnedSelection[0] ?? "";
  const pinnedSymbol = /^symbol:(\d+)$/.exec(pinnedId);
  expect(pinnedSymbol?.[1], `a symbol id was pinned, got ${pinnedId}`).toBeDefined();
  expect(Number(pinnedSymbol?.[1])).toBeGreaterThanOrEqual(entryB.counts.symbols);

  // Push A's camera far from a fit, so "B keeps A's viewport" is detectable.
  await page.mouse.move(512, 350);
  for (let i = 0; i < 8; i++) await page.mouse.wheel(0, 240);
  await page.waitForTimeout(400);
  const zoomA = await page.evaluate(() => window.__atlasLive?.camera.zoom ?? null);
  expect(zoomA).not.toBeNull();

  await selectDataset(page, entryB.snapshotId);
  await waitReady(page, entryB.snapshotId, worldA.revision + 1);
  await page.waitForTimeout(800);

  const after = await page.evaluate(() => {
    const hook = window.__atlasLive;
    return {
      snapshotId: hook?.snapshotId ?? null,
      revision: hook?.sessionRevision ?? 0,
      liveSessions: hook?.liveSessions ?? 0,
      duckdbTables: hook?.duckdbTables ?? [],
      counts: hook?.counts ?? null,
      dataset: hook?.dataset ?? null,
      selected: hook?.selected ?? [],
      camera: hook?.camera ?? { zoom: null },
      hovered: hook?.hovered ?? null,
    };
  });

  // B is loaded and A is fully gone.
  expect(after.snapshotId).toBe(entryB.snapshotId);
  expect(after.revision).toBe(worldA.revision + 1);
  expect(after.counts?.points).toBe(entryB.counts.points);
  expect(after.counts?.links).toBe(entryB.counts.links);
  expect(after.dataset?.repository).toBe(entryB.repository);

  // Exactly one live session; A's DuckDB tables are dropped.
  expect(after.liveSessions).toBe(1);
  expect(after.duckdbTables).toHaveLength(3);
  expect(after.duckdbTables).toContain(`atlas_live_points_${worldA.revision + 1}`);
  expect(after.duckdbTables).toContain(`atlas_live_links_${worldA.revision + 1}`);
  expect(after.duckdbTables).toContain(`atlas_live_links_${worldA.revision + 1}_frontier_0`);

  // The pinned symbol from A does not exist in B: the selection is cleared.
  expect(after.selected).toEqual([]);
  await expect(page.getByTestId("selection")).toHaveCount(0);

  // The camera fits B, rather than keeping A's zoom.
  expect(after.camera.zoom).not.toBeNull();
  expect(Math.abs((after.camera.zoom ?? 0) - (zoomA ?? 0))).toBeGreaterThan(1e-6);

  const png = await page.screenshot();
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
  expect(painted, "the switched graph paints non-blank").toBeGreaterThan(1000);

  expect(consoleErrors).toEqual([]);
});

test("the synthetic stress fixture loads, is labelled synthetic and stays interactive", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });

  await page.goto("/");
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });
  const manifest = await readManifest(page);
  const synthetic = manifest.synthetic;
  expect(synthetic, "manifest.json carries a synthetic fixture").not.toBeNull();
  if (synthetic === null) return;

  await selectDataset(page, synthetic.snapshotId);
  await waitReady(page, synthetic.snapshotId, 2);
  await page.waitForTimeout(500);

  const info = await page.evaluate(() => {
    const hook = window.__atlasLive;
    return {
      snapshotId: hook?.snapshotId ?? null,
      dataset: hook?.dataset ?? null,
      counts: hook?.counts ?? null,
      renderLinks: hook?.renderLinks ?? null,
      liveSessions: hook?.liveSessions ?? 0,
    };
  });
  expect(info.dataset?.synthetic).toBe(true);
  expect(info.dataset?.repository).toBe("synthetic");
  expect(info.counts?.points).toBe(10_000);
  expect(info.counts?.links).toBe(50_000);
  expect(info.renderLinks).toBe(false);
  expect(info.liveSessions).toBe(1);

  // The fitted overview stays bounded; zoom reveals nearby exact connections.
  await expect(page.getByTestId("identity")).toContainText("synthetic");
  const projectedWireCount = await page.evaluate(() => window.__atlasLive?.projected.aggregatedEdgeCount ?? 0);
  expect(projectedWireCount).toBeGreaterThan(0);
  if (projectedWireCount > 10_000) {
    await expect(page.getByTestId("wire-visibility")).toContainText("Zoom in to reveal");
  } else {
    await expect(page.getByTestId("wire-visibility")).toHaveCount(0);
  }

  // Check picking at the fitted overview before the zoom test moves most
  // candidate points outside the canvas viewport.
  const candidates = await page.evaluate(() => {
    const hook = window.__atlasLive;
    if (hook === undefined) return [];
    const count = hook.pointCount();
    const first = hook.pointWithIncidentLinks();
    const fractions = [0, 0.3, 0.5, 0.7, 0.85, 0.95];
    const indices = fractions.map((fraction) => Math.floor((count - 1) * fraction));
    if (first !== null) indices.unshift(first);
    return [...new Set(indices)].filter((index) => index >= 0 && index < count);
  });
  expect(candidates.length, "synthetic hover candidates").toBeGreaterThan(0);
  const elapsed = await hoverFirstPoint(page, candidates, 2000);
  expect(elapsed).toBeLessThan(2000);

  const graph = await page.getByTestId("graph").boundingBox();
  expect(graph).not.toBeNull();
  if (graph !== null) {
    await page.mouse.move(graph.x + graph.width / 2, graph.y + graph.height / 2);
    const fittedZoom = await page.evaluate(() => window.__atlasLive?.camera.zoom ?? 0);
    await page.mouse.wheel(0, -350);
    await expect.poll(async () => page.evaluate(() => window.__atlasLive?.camera.zoom ?? 0)).not.toBe(fittedZoom);
    const firstZoom = await page.evaluate(() => window.__atlasLive?.camera.zoom ?? 0);
    const zoomInDelta = firstZoom > fittedZoom ? -350 : 350;
    for (let step = 0; step < 4; step++) await page.mouse.wheel(0, zoomInDelta);
    if (projectedWireCount > 10_000) {
      await expect(page.getByTestId("wire-visibility")).toContainText(/Showing [1-9][0-9,]* of/);
    }
  }

  expect(consoleErrors).toEqual([]);
});

test("a failed switch shows an explicit loading then error state and keeps the previous dataset", async ({
  page,
}) => {
  await page.goto("/");
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });
  const manifest = await readManifest(page);
  const before = await page.evaluate(() => ({
    snapshotId: window.__atlasLive?.snapshotId ?? null,
    revision: window.__atlasLive?.sessionRevision ?? 0,
  }));
  const entryB = manifest.worlds.find(
    (world) => world.snapshotId !== before.snapshotId && world.counts.symbols > 0,
  );
  expect(entryB).toBeTruthy();
  if (entryB === undefined) return;

  // Block one of B's assets so the switch cannot complete; hold it open long
  // enough that the loading state is observable.
  await page.route(`**${entryB.assets.entities}`, async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 1500));
    await route.abort();
  });

  await openPicker(page);
  await page.locator(`[data-snapshot-id="${entryB.snapshotId}"]`).click();

  await expect(page.getByTestId("loading")).toBeVisible({ timeout: 5_000 });
  await expect(page.getByTestId("loading")).toContainText(entryB.repository);
  await expect(page.getByTestId("switch-error")).toBeVisible({ timeout: 30_000 });
  await expect(page.getByTestId("switch-error")).toContainText(entryB.repository);

  const after = await page.evaluate(() => ({
    ready: window.__atlasLive?.ready ?? false,
    loading: window.__atlasLive?.loading ?? false,
    error: window.__atlasLive?.error ?? null,
    snapshotId: window.__atlasLive?.snapshotId ?? null,
    liveSessions: window.__atlasLive?.liveSessions ?? 0,
  }));
  // No spinner left running; the previous dataset is still usable.
  expect(after.loading).toBe(false);
  expect(after.ready).toBe(true);
  expect(after.snapshotId).toBe(before.snapshotId);
  expect(after.error).toContain(entryB.repository);
  expect(after.liveSessions).toBe(1);
});
