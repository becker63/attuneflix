/**
 * The header: the dataset identity (repository, short base revision, and a
 * real-world marker) and the active overlay name. All values come from the
 * loaded world's manifest entry; none are invented.
 */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue } from "jotai";

import { overlayAtom } from "./atoms.ts";
import type { GraphSession } from "./session.ts";
import { OVERLAY_LABELS } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    display: "flex",
    alignItems: "center",
    flexWrap: "wrap",
    gap: 16,
    paddingTop: 10,
    paddingBottom: 10,
    paddingLeft: 16,
    paddingRight: 16,
    borderBottomWidth: 1,
    borderBottomStyle: "solid",
    borderBottomColor: "#1f2937",
    backgroundColor: "#0f1117",
  },
  brand: {
    fontSize: 15,
    fontWeight: 700,
    letterSpacing: 0.3,
    color: "#f9fafb",
  },
  identity: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    fontSize: 13,
    color: "#d1d5db",
  },
  repo: {
    fontWeight: 600,
    color: "#f9fafb",
  },
  revision: {
    fontFamily: "ui-monospace, monospace",
    color: "#9ca3af",
  },
  badge: {
    fontSize: 11,
    paddingTop: 2,
    paddingBottom: 2,
    paddingLeft: 6,
    paddingRight: 6,
    borderRadius: 4,
    backgroundColor: "#1f2937",
    color: "#a7f3d0",
  },
  spacer: {
    flexGrow: 1,
  },
  stat: {
    fontSize: 12,
    color: "#9ca3af",
  },
});

export function Header({ session }: { session: GraphSession | null }) {
  const overlay = useAtomValue(overlayAtom);
  return (
    <header {...stylex.props(styles.root)}>
      <span {...stylex.props(styles.brand)}>Atlas Live</span>
      {session === null ? (
        <span {...stylex.props(styles.stat)}>loading…</span>
      ) : (
        <span {...stylex.props(styles.identity)}>
          <span {...stylex.props(styles.repo)}>{session.entry.repository}</span>
          <span {...stylex.props(styles.revision)}>{session.entry.baseRevision.slice(0, 8)}</span>
          <span {...stylex.props(styles.badge)}>real world</span>
        </span>
      )}
      <span {...stylex.props(styles.spacer)} />
      {session === null ? null : (
        <span {...stylex.props(styles.stat)} data-testid="counts">
          {session.pointCount} points · {session.linkCount} links
        </span>
      )}
      <span {...stylex.props(styles.stat)} data-testid="overlay">
        Overlay: {OVERLAY_LABELS[overlay]}
      </span>
    </header>
  );
}
