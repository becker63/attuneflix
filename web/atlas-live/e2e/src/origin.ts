import type { Request } from "@playwright/test";

/** The local static preview of the Bazel-built bundle. */
export const PREVIEW_ORIGIN = "http://127.0.0.1:4173";

export function isExternalRequest(request: Request): boolean {
  return new URL(request.url()).origin !== PREVIEW_ORIGIN;
}
