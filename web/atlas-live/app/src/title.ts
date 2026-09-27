import { isTerminalStatus, type StreamStatus } from "../../protocol/src/status.ts";

export function documentTitle(snapshot: string | undefined): string {
  return snapshot === undefined ? "Atlas Live" : `${snapshot} · Atlas Live`;
}

/** A settled stream will not change again, so its status badge stops animating. */
export function isSettled(status: StreamStatus): boolean {
  return isTerminalStatus(status);
}
