import fs from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

import { isSameOrigin } from "../src/origin.ts";

interface WorldEntry {
  snapshotId: string;
  repository: string;
  counts: { points: number; links: number };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isWorldsResponse(value: unknown): value is { worlds: WorldEntry[] } {
  return isRecord(value) && Array.isArray(value.worlds);
}

const BACKGROUND = { r: 11, g: 13, b: 18 };

test("default world renders non-blank, responds to hover, stays same-origin", async ({ page, browser }) => {
  const consoleErrors: string[] = [];
  const pageErrors: string[] = [];
  const requests: string[] = [];
  const stylesheetResponses: { url: string; status: number; contentType: string }[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => pageErrors.push(String(error)));
  page.on("request", (request) => requests.push(request.url()));
  page.on("response", (response) => {
    const url = response.url();
    if (!url.endsWith(".css")) return;
    stylesheetResponses.push({
      url,
      status: response.status(),
      contentType: response.headers()["content-type"] ?? "",
    });
  });

  await page.goto("/");
  await page.waitForFunction(() => window.__atlasLive?.ready === true, null, { timeout: 90_000 });
  await page.waitForTimeout(1000);

  const hook = await page.evaluate(() => {
    const live = window.__atlasLive;
    return {
      snapshotId: live?.snapshotId ?? null,
      counts: live?.counts ?? null,
      buildRevision: live?.buildRevision ?? null,
    };
  });
  expect(hook.snapshotId).not.toBeNull();

  // The built page must load and apply its stylesheet. A StyleX build with no
  // linked stylesheet renders every class inert (the milestone-A defect); the
  // computed styles below are ones only the stylesheet can supply.
  const styles = await page.evaluate(() => {
    const links: { href: string | null; resolved: string; rules: number }[] = [];
    for (const element of document.querySelectorAll('link[rel="stylesheet"]')) {
      if (!(element instanceof HTMLLinkElement)) continue;
      let rules = -1;
      try {
        rules = element.sheet === null ? -1 : element.sheet.cssRules.length;
      } catch {
        rules = -1;
      }
      links.push({ href: element.getAttribute("href"), resolved: element.href, rules });
    }
    const header = document.querySelector("header");
    const main = document.querySelector("main");
    const graph = document.querySelector('[data-testid="graph"]');
    const aside = document.querySelector("aside");
    return {
      links,
      sameOrigin: links.filter((link) => link.resolved.startsWith(location.origin)).length,
      headerDisplay: header === null ? null : getComputedStyle(header).getPropertyValue("display"),
      headerPaddingTop: header === null ? null : getComputedStyle(header).getPropertyValue("padding-top"),
      mainDisplay: main === null ? null : getComputedStyle(main).getPropertyValue("display"),
      graphPosition: graph === null ? null : getComputedStyle(graph).getPropertyValue("position"),
      asideWidth: aside === null ? null : getComputedStyle(aside).getPropertyValue("width"),
    };
  });
  expect(styles.links.length, "the page links at least one stylesheet").toBeGreaterThanOrEqual(1);
  expect(styles.sameOrigin, "at least one linked stylesheet is same-origin").toBeGreaterThanOrEqual(1);
  expect(styles.sameOrigin, "every linked stylesheet is same-origin").toBe(styles.links.length);
  expect(
    Math.max(...styles.links.map((link) => link.rules)),
    "a linked stylesheet exposes parsed rules",
  ).toBeGreaterThan(0);
  // Unstyled defaults are `display: block` and `padding-top: 0px`; these come
  // from the stylesheet's StyleX classes.
  expect(styles.headerDisplay, "the header is flex, not the unstyled block").toBe("flex");
  expect(styles.headerPaddingTop, "the header padding comes from the stylesheet").toBe("10px");
  expect(styles.mainDisplay, "main is the flex column the stylesheet sets").toBe("flex");
  expect(styles.graphPosition, "the graph region is positioned by the stylesheet").toBe("relative");
  expect(styles.asideWidth, "the sidebar has the stylesheet width").toBe("280px");
  expect(stylesheetResponses, "at least one stylesheet request was made").not.toEqual([]);
  for (const response of stylesheetResponses) {
    expect(response.status, `stylesheet ${response.url} responds 200`).toBe(200);
    expect(response.contentType, `stylesheet ${response.url} is text/css`).toContain("text/css");
  }

  const manifestResponse = await page.request.get("/manifest.json");
  expect(manifestResponse.ok()).toBe(true);
  const manifestValue: unknown = await manifestResponse.json();
  if (!isWorldsResponse(manifestValue)) throw new Error("manifest.json has an unexpected shape");
  const manifest = manifestValue;
  const entry = manifest.worlds.find((world) => world.snapshotId === hook.snapshotId);
  expect(entry, `manifest entry for ${hook.snapshotId}`).toBeTruthy();
  expect(hook.counts?.points).toBe(entry?.counts.points);
  expect(hook.counts?.links).toBe(entry?.counts.links);

  const gl = await page.evaluate(() => {
    for (const canvas of document.querySelectorAll("canvas")) {
      const context = canvas.getContext("webgl2");
      if (context === null) continue;
      const info = context.getExtension("WEBGL_debug_renderer_info");
      const rect = canvas.getBoundingClientRect();
      return {
        canvases: document.querySelectorAll("canvas").length,
        renderer: info === null ? null : String(context.getParameter(info.UNMASKED_RENDERER_WEBGL)),
        rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
      };
    }
    return { canvases: document.querySelectorAll("canvas").length, renderer: null, rect: null };
  });
  expect(gl.rect, "a WebGL2 canvas is present").not.toBeNull();
  const rect = gl.rect;

  const outputs = process.env.TEST_UNDECLARED_OUTPUTS_DIR;
  const png = await page.screenshot({ clip: rect ?? undefined });
  if (outputs !== undefined) fs.writeFileSync(path.join(outputs, "load.png"), png);

  const pixels = await page.evaluate(
    async ({ base64, background }) => {
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
      const colours = new Set<string>();
      let painted = 0;
      for (let i = 0; i < data.length; i += 4) {
        const r = data[i] ?? 0;
        const g = data[i + 1] ?? 0;
        const b = data[i + 2] ?? 0;
        colours.add(`${r},${g},${b}`);
        const delta = Math.abs(r - background.r) + Math.abs(g - background.g) + Math.abs(b - background.b);
        if (delta > 24) painted++;
      }
      return { painted, total: data.length / 4, colours: colours.size };
    },
    { base64: png.toString("base64"), background: BACKGROUND },
  );

  expect(pixels.painted / pixels.total, "more than 1% of pixels painted").toBeGreaterThan(0.01);
  expect(pixels.colours, "more than 50 distinct colours").toBeGreaterThan(50);

  const target = await page.evaluate(() => {
    const live = window.__atlasLive;
    const index = live?.pointWithIncidentLinks() ?? null;
    if (index === null || live === undefined) return null;
    return { index, position: live.screenPositionOf(index) };
  });
  expect(target?.position, "a point's screen position").toBeTruthy();
  const position = target?.position;
  await page.mouse.move(position?.[0] ?? 0, position?.[1] ?? 0);
  await expect
    .poll(async () => page.evaluate(() => window.__atlasLive?.hovered ?? null), { timeout: 10_000 })
    .not.toBeNull();

  const highlighted = await page.evaluate(() => window.__atlasLive?.highlighted ?? null);
  expect(highlighted?.points.length ?? 0).toBeGreaterThan(1);
  expect(highlighted?.links.length ?? 0).toBeGreaterThan(0);

  const hoverPng = await page.screenshot();
  if (outputs !== undefined) fs.writeFileSync(path.join(outputs, "hover.png"), hoverPng);

  // Move off the graph (into the header) to clear the hover.
  await page.mouse.move(4, 4);
  await expect
    .poll(async () => page.evaluate(() => window.__atlasLive?.hovered ?? null), { timeout: 10_000 })
    .toBeNull();

  const external = requests.filter((url) => !isSameOrigin(url));
  expect(external, "every request is same-origin").toEqual([]);
  expect(consoleErrors, "no console errors").toEqual([]);
  expect(pageErrors, "no page errors").toEqual([]);
  expect(browser.version()).not.toBe("");
});
