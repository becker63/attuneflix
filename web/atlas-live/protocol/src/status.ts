import { unreachable } from "./unreachable.ts";

/** Client-side stream status. It describes the connection, never a producer claim. */
export type StreamStatus =
  | "connecting"
  | "streaming"
  | "paused"
  | "gapped"
  | "disconnected"
  | "reconnecting"
  | "completed"
  | "failed";

export function isTerminalStatus(status: StreamStatus): boolean {
  switch (status) {
    case "completed":
    case "failed":
      return true;
    case "connecting":
    case "streaming":
    case "paused":
    case "gapped":
    case "disconnected":
    case "reconnecting":
      return false;
    default:
      return unreachable(status);
  }
}
