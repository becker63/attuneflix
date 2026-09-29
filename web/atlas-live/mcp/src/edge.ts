import { handleMcp } from "./server.ts";

/** Vercel Edge entry point for the public /mcp function. */
export default function mcp(request: Request): Promise<Response> {
  return handleMcp(request);
}
