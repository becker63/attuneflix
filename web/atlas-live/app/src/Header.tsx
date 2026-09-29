/**
 * The header: the snapshot picker, the dataset identity (repository, short base
 * revision, and a synthetic/real-world marker), and the active overlay name. All
 * values come from the loaded world's manifest entry; none are invented. Large
 * projected connection sets show a zoom cue instead of silently disappearing.
 */
import * as stylex from "@stylexjs/stylex";
import type { SessionSnapshot } from "./controller.ts";
import { DatasetPicker } from "./DatasetPicker.tsx";
import { LINK_RENDER_BUDGET, shortRevision } from "./datasets.ts";

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
    borderRadius: 10,
    backgroundColor: "rgba(0, 0, 0, 0.75)",
    boxShadow: "#00000f 0 0 10px",
  },
  brand: {
    fontFamily: "PixelDown, system-ui, sans-serif",
    fontSize: 22,
    fontWeight: 600,
    letterSpacing: 0.6,
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
    backgroundColor: "rgba(255, 255, 255, 0.08)",
    color: "#a7f3d0",
  },
  syntheticBadge: {
    backgroundColor: "#422006",
    color: "#fcd34d",
    fontWeight: 600,
  },
  noteBadge: {
    backgroundColor: "rgba(255, 255, 255, 0.08)",
    color: "#9ca3af",
  },
  spacer: {
    flexGrow: 1,
  },
  stat: {
    fontSize: 12,
    color: "#9ca3af",
  },
});

export function Header({ state, onSelect }: { state: SessionSnapshot; onSelect: (value: string) => void }) {
  const { session } = state;
  const pickerDisabled = state.status === "loading" || state.status === "booting";
  return (
    <header {...stylex.props(styles.root)}>
      <span {...stylex.props(styles.brand)}>Atlas Live</span>
      <DatasetPicker
        options={state.options}
        value={state.selectedValue}
        disabled={pickerDisabled}
        onSelect={onSelect}
      />
      {session === null ? (
        <span {...stylex.props(styles.stat)}>
          {state.status === "error" ? "no dataset loaded" : "loading…"}
        </span>
      ) : (
        <span {...stylex.props(styles.identity)} data-testid="identity">
          <span {...stylex.props(styles.repo)}>{session.entry.repository}</span>
          <span {...stylex.props(styles.revision)}>{shortRevision(session.entry.baseRevision)}</span>
          <span {...stylex.props(styles.badge, session.entry.synthetic ? styles.syntheticBadge : null)}>
            {session.entry.synthetic ? "synthetic" : "real world"}
          </span>
          {session.getViewSnapshot().projection.wires.length <= LINK_RENDER_BUDGET ? null : (
            <span
              {...stylex.props(styles.badge, styles.noteBadge)}
              data-testid="zoom-connections"
              title={`The fitted view exceeds the ${LINK_RENDER_BUDGET}-connection draw budget. Zooming reveals the exact connections near the camera.`}
            >
              zoom for connections
            </span>
          )}
        </span>
      )}
      <span {...stylex.props(styles.spacer)} />
      {session === null ? null : (
        <span {...stylex.props(styles.stat)} data-testid="counts">
          {session.pointCount} points · {session.linkCount} links
        </span>
      )}
      <span {...stylex.props(styles.stat)} data-testid="overlay">
        {session?.families === null ? "Structure" : "Structure + families"}
      </span>
    </header>
  );
}
