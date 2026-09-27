/**
 * The header: the snapshot picker, the dataset identity (repository, short base
 * revision, and a synthetic/real-world marker), and the active overlay name. All
 * values come from the loaded world's manifest entry; none are invented. When
 * the dataset's links exceed the render budget the header says so, so a
 * link-free view is never mistaken for an empty one.
 */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue } from "jotai";

import { overlayAtom } from "./atoms.ts";
import type { SessionSnapshot } from "./controller.ts";
import { DatasetPicker } from "./DatasetPicker.tsx";
import { LINK_RENDER_BUDGET, shortRevision } from "./datasets.ts";
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
  syntheticBadge: {
    backgroundColor: "#422006",
    color: "#fcd34d",
    fontWeight: 600,
  },
  noteBadge: {
    backgroundColor: "#1f2937",
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
  const overlay = useAtomValue(overlayAtom);
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
          {session.renderLinks ? null : (
            <span
              {...stylex.props(styles.badge, styles.noteBadge)}
              data-testid="links-hidden"
              title={`More than the ${LINK_RENDER_BUDGET}-link render budget: links stay in the graph but are not drawn, so the view stays interactive under software WebGL.`}
            >
              links hidden
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
        Overlay: {OVERLAY_LABELS[overlay]}
      </span>
    </header>
  );
}
