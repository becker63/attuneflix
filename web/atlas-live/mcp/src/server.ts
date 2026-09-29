/** Stateless, read-only MCP over the exact artifacts published beside Atlas Live. */
import { callTool, type ToolName } from "./tools.ts";

const MODERN = "2026-07-28";
const LEGACY = "2025-11-25";
const EARLY = "2025-06-18";
const SERVER = { name: "atlas-live", version: "1.0.0" };
const METHODS = ["list_worlds", "get_world", "list_origins", "get_region", "compare_origins", "get_landscape"] as const;
const SNAPSHOT = { type: "string", description: "Snapshot ID or digest from list_worlds." };
const VIEW = {
  snapshot_id: SNAPSHOT,
  enabled_relations: { type: "array", items: { type: "string", enum: ["imports", "calls"] }, description: "Visible directed wire relations; defaults to both." },
  expanded: { type: "array", items: { type: "string" }, maxItems: 64, description: "Visible container IDs to expand in order." },
};
const PAGE = { offset: { type: "integer", minimum: 0 }, limit: { type: "integer", minimum: 1, maximum: 50 } };
const DEPTH = { depth: { type: "integer", enum: [1, 2, 3] } };
const DEFINITIONS: Record<ToolName, { description: string; inputSchema: Record<string, unknown> }> = {
  list_worlds: {
    description: "List the public snapshot population and its measured physical/signature summaries. No acquisition or mutation.",
    inputSchema: { type: "object", properties: { repository: { type: "string" }, ...PAGE }, additionalProperties: false },
  },
  get_world: {
    description: "Inspect a published snapshot, provenance, typed asset URLs, and measured summary values.",
    inputSchema: { type: "object", properties: { snapshot_id: SNAPSHOT }, required: ["snapshot_id"], additionalProperties: false },
  },
  list_origins: {
    description: "List visible structural origins in one snapshot and frontier. Returns stable IDs for region/pair tools.",
    inputSchema: { type: "object", properties: { ...VIEW, ...PAGE }, required: ["snapshot_id"], additionalProperties: false },
  },
  get_region: {
    description: "Compute one visible origin's depth-1/2/3 structural reach, growth, frontier metrics, nearby convergence, and separately measured physical reuse.",
    inputSchema: { type: "object", properties: { ...VIEW, origin_id: { type: "string" } }, required: ["snapshot_id", "origin_id"], additionalProperties: false },
  },
  compare_origins: {
    description: "Compute exact directed projected-wire neighborhood overlap and censored convergence depth for two visible origins. Structural potential, not observed agent conflict.",
    inputSchema: { type: "object", properties: { ...VIEW, origin_a: { type: "string" }, origin_b: { type: "string" }, ...DEPTH }, required: ["snapshot_id", "origin_a", "origin_b"], additionalProperties: false },
  },
  get_landscape: {
    description: "Compute the visible structural convergence graph, deterministic greedy separated set and waves, and depth-1/2/3 separation decay. Not a throughput prediction.",
    inputSchema: { type: "object", properties: { ...VIEW, ...DEPTH, threshold: { type: "number", minimum: 0, maximum: 1 } }, required: ["snapshot_id"], additionalProperties: false },
  },
};

export const TOOLS = METHODS.map((name) => ({ name, ...DEFINITIONS[name], annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false } }));

type RpcRequest = { jsonrpc: "2.0"; id?: string | number; method: string; params?: Record<string, unknown> };
function record(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
function isRpcRequest(value: unknown): value is RpcRequest {
  return record(value) && value.jsonrpc === "2.0" && typeof value.method === "string"
    && (value.id === undefined || typeof value.id === "string" || typeof value.id === "number");
}
function isToolName(value: unknown): value is ToolName {
  return typeof value === "string" && Object.hasOwn(DEFINITIONS, value);
}
function json(value: unknown, status = 200, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...extra } });
}
function rpc(id: string | number | null, result: unknown): Response {
  return json({ jsonrpc: "2.0", id, result });
}
function rpcError(id: string | number | null, code: number, message: string, status = 200): Response {
  return json({ jsonrpc: "2.0", id, error: { code, message } }, status);
}
function originAllowed(request: Request): boolean {
  const header = request.headers.get("Origin");
  if (header === null) return true;
  try {
    const origin = new URL(header);
    return origin.origin === header && (origin.protocol === "https:" || (origin.protocol === "http:" && ["localhost", "127.0.0.1"].includes(origin.hostname)));
  } catch { return false; }
}
function protocolOf(request: Request): string {
  return request.headers.get("MCP-Protocol-Version") ?? LEGACY;
}
function modern(request: Request): boolean {
  return protocolOf(request) === MODERN;
}
function complete(request: Request, value: Record<string, unknown>): Record<string, unknown> {
  return modern(request) ? { ...value, resultType: "complete", _meta: { "io.modelcontextprotocol/serverInfo": SERVER } } : value;
}
function decodedName(value: string): string | null {
  if (!value.startsWith("=?base64?")) return value;
  if (!value.endsWith("?=")) return null;
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(atob(value.slice(9, -2)), (character) => character.charCodeAt(0)));
  } catch { return null; }
}
function notification(request: RpcRequest): boolean {
  return request.id === undefined;
}

/** A single streamable HTTP endpoint; all operations are public reads over shipped artifacts. */
export async function handleMcp(request: Request): Promise<Response> {
  if (!originAllowed(request)) return json({ error: "invalid Origin" }, 403);
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: { Allow: "POST, GET, OPTIONS" } });
  if (request.method === "GET") return json({ error: "MCP is served over POST" }, 405, { Allow: "POST" });
  if (request.method !== "POST") return json({ error: "method not allowed" }, 405, { Allow: "POST, GET, OPTIONS" });
  if (!request.headers.get("Content-Type")?.startsWith("application/json")) return json({ error: "application/json required" }, 415);
  const size = Number(request.headers.get("Content-Length") ?? 0);
  if (size > 32768) return json({ error: "request too large" }, 413);
  let body: unknown;
  try {
    const raw = await request.text();
    if (raw.length > 32768) return json({ error: "request too large" }, 413);
    body = JSON.parse(raw) as unknown;
  } catch { return rpcError(null, -32700, "invalid JSON", 400); }
  if (!isRpcRequest(body)) {
    return rpcError(null, -32600, "invalid JSON-RPC request", 400);
  }
  const message = body;
  if (notification(message)) return new Response(null, { status: 202 });
  const id = message.id ?? null;
  const methodHeader = request.headers.get("Mcp-Method");
  if (modern(request)) {
    const meta = record(message.params) && record(message.params["_meta"]) ? message.params["_meta"] : null;
    if (meta?.["io.modelcontextprotocol/protocolVersion"] !== MODERN
      || methodHeader !== message.method) return rpcError(id, -32020, "MCP request headers and metadata must match", 400);
  } else if (methodHeader !== null && methodHeader !== message.method) {
    return rpcError(id, -32020, "Mcp-Method does not match request method", 400);
  }
  const params = record(message.params) ? message.params : {};
  const requestedVersion = params.protocolVersion;
  const version = message.method === "initialize" && !request.headers.has("MCP-Protocol-Version")
    && typeof requestedVersion === "string" ? requestedVersion : protocolOf(request);
  if (version !== MODERN && version !== LEGACY && version !== EARLY) {
    return rpcError(id, -32600, `unsupported protocol version ${version}`, 400);
  }
  const requestOrigin = new URL(request.url).origin;
  try {
    if (message.method === "server/discover") return rpc(id, complete(request, { supportedVersions: [MODERN, LEGACY, EARLY], capabilities: { tools: { listChanged: false }, resources: { listChanged: false } }, instructions: "Public read-only Atlas Live snapshots and structural computations. Physical reuse is measured depth-7 evidence; depth-1/2/3 structural convergence is static potential, not observed agent contention." }));
    if (message.method === "initialize") return rpc(id, { protocolVersion: version, capabilities: { tools: { listChanged: false }, resources: { listChanged: false } }, serverInfo: SERVER });
    if (message.method === "ping") return rpc(id, {});
    if (message.method === "tools/list") return rpc(id, complete(request, { tools: TOOLS }));
    if (message.method === "tools/call") {
      const name = params.name;
      if (!isToolName(name)) return rpcError(id, -32602, "unknown tool name");
      const nameHeader = request.headers.get("Mcp-Name");
      if ((modern(request) && nameHeader === null) || (nameHeader !== null && decodedName(nameHeader) !== name)) {
        return rpcError(id, -32020, "Mcp-Name does not match tool name", 400);
      }
      if (params.arguments !== undefined && !record(params.arguments)) return rpcError(id, -32602, "tool arguments must be an object");
      const data = await callTool(requestOrigin, name, record(params.arguments) ? params.arguments : {});
      return rpc(id, complete(request, { content: [{ type: "text", text: JSON.stringify(data) }], structuredContent: data, isError: false }));
    }
    if (message.method === "resources/list") return rpc(id, complete(request, { resources: [{ uri: `${requestOrigin}/manifest.json`, name: "Atlas Live snapshots", mimeType: "application/json", description: "The published snapshot manifest used by the website and this MCP." }] }));
    if (message.method === "resources/read") {
      if (params.uri !== `${requestOrigin}/manifest.json`) return rpcError(id, -32602, "unknown resource");
      const nameHeader = request.headers.get("Mcp-Name");
      if ((modern(request) && nameHeader === null) || (nameHeader !== null && decodedName(nameHeader) !== params.uri)) {
        return rpcError(id, -32020, "Mcp-Name does not match resource URI", 400);
      }
      const response = await fetch(`${requestOrigin}/manifest.json`);
      if (!response.ok) throw new Error(`manifest returned ${response.status}`);
      return rpc(id, complete(request, { contents: [{ uri: params.uri, mimeType: "application/json", text: await response.text() }] }));
    }
    return rpcError(id, -32601, `method not found: ${message.method}`, modern(request) ? 404 : 200);
  } catch (cause) {
    const detail = cause instanceof Error ? cause.message : "tool failed";
    if (message.method === "tools/call") {
      return rpc(id, complete(request, { content: [{ type: "text", text: detail }], isError: true }));
    }
    return rpcError(id, -32603, "server error");
  }
}
