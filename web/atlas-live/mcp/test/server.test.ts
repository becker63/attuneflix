import { afterEach, expect, it, vi } from "vitest";
import { handleMcp } from "../src/server.ts";

const ROOT = "https://atlas-live-five.vercel.app/mcp";
function request(method: string, params?: Record<string, unknown>, headers: Record<string, string> = {}) {
  const modern = headers["MCP-Protocol-Version"] === "2026-07-28";
  return new Request(ROOT, { method: "POST", headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method,
      params: modern ? { ...params, _meta: { "io.modelcontextprotocol/protocolVersion": "2026-07-28",
        "io.modelcontextprotocol/clientInfo": { name: "atlas-live-test", version: "1" },
        "io.modelcontextprotocol/clientCapabilities": {} } } : params }) });
}
async function result(response: Response) {
  expect(response.status).toBe(200);
  const value: unknown = await response.json();
  return value;
}
afterEach(() => vi.restoreAllMocks());

it("advertises only read-only tools for both MCP handshakes", async () => {
  const legacy = await result(await handleMcp(request("initialize", { protocolVersion: "2025-11-25" })));
  expect(legacy).toMatchObject({ result: { protocolVersion: "2025-11-25" } });
  const early = await result(await handleMcp(request("initialize", { protocolVersion: "2025-06-18" }, { "MCP-Protocol-Version": "2025-06-18" })));
  expect(early).toMatchObject({ result: { protocolVersion: "2025-06-18" } });
  const earlyWithoutHeader = await result(await handleMcp(request("initialize", { protocolVersion: "2025-06-18" })));
  expect(earlyWithoutHeader).toMatchObject({ result: { protocolVersion: "2025-06-18" } });
  const modern = await result(await handleMcp(request("server/discover", undefined, { "MCP-Protocol-Version": "2026-07-28", "Mcp-Method": "server/discover" })));
  expect(modern).toMatchObject({ result: { supportedVersions: ["2026-07-28", "2025-11-25", "2025-06-18"] } });
  const listed = await result(await handleMcp(request("tools/list")));
  expect(listed).toMatchObject({ result: { tools: [
    { name: "list_worlds", annotations: { readOnlyHint: true } },
    { name: "get_world", annotations: { readOnlyHint: true } },
    { name: "list_origins", annotations: { readOnlyHint: true } },
    { name: "get_region", annotations: { readOnlyHint: true } },
    { name: "compare_origins", annotations: { readOnlyHint: true } },
    { name: "get_landscape", annotations: { readOnlyHint: true } },
  ] } });
});

it("uses the published manifest and returns a website link for each world", async () => {
  vi.stubGlobal("fetch", vi.fn(async () => new Response(JSON.stringify({ version: 1, worlds: [
    { snapshotId: "repository-snapshot-v1:abc", snapshotDigest: "abc", repository: "example", counts: { points: 5 }, assets: {} },
  ] }), { status: 200 })));
  const reply = await result(await handleMcp(request("tools/call", { name: "list_worlds", arguments: {} })));
  expect(reply).toMatchObject({ result: { structuredContent: { worlds: [
    { viewUrl: "https://atlas-live-five.vercel.app/?snapshot=abc&mode=parallelism" },
  ] } } });
  const current = await result(await handleMcp(request("tools/call", { name: "list_worlds", arguments: {} }, {
    "MCP-Protocol-Version": "2026-07-28", "Mcp-Method": "tools/call", "Mcp-Name": "list_worlds",
  })));
  expect(current).toMatchObject({ result: { resultType: "complete", structuredContent: { total: 1 } } });
});

it("rejects malformed requests, mismatched headers, and foreign insecure origins", async () => {
  expect((await handleMcp(new Request(ROOT, { method: "POST", headers: { Origin: "http://evil.example", "Content-Type": "application/json" }, body: "{}" }))).status).toBe(403);
  const mismatch = await handleMcp(request("tools/list", undefined, { "Mcp-Method": "tools/call" }));
  expect(mismatch.status).toBe(400);
  const bad = await handleMcp(request("tools/call", { name: "unknown", arguments: {} }));
  expect(await result(bad)).toMatchObject({ error: { code: -32602 } });
});
