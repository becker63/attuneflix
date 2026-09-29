/**
 * The families sidebar section: the strongest cross-family edges of the loaded
 * world, and the drill-down of the edge under inspection. Clicking an edge
 * switches to the Families overlay and reveals the contributing exact edges on
 * the canvas; the same list shows them as labelled lines (bounded, with the
 * remainder counted, never silently truncated).
 *
 * The heading carries the F3 honesty counts (singleton families, fallback
 * members) so the list never reads as more complete than the evidence is.
 */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue, useSetAtom } from "jotai";

import type { FamilyEdge } from "../../projection/src/families.ts";
import { drillFamilyEdgeAtom, drilledFamilyEdgeAtom } from "./atoms.ts";
import {
  CONTRIBUTION_LINE_LIMIT,
  TOP_FAMILY_EDGE_LIMIT,
  contributionLines,
  drillFamilyEdge,
  topFamilyEdges,
} from "./families.ts";
import type { GraphSession } from "./session.ts";
import { relationStyle } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    display: "flex",
    flexDirection: "column",
    gap: 6,
  },
  heading: {
    fontSize: 11,
    fontWeight: 600,
    textTransform: "uppercase",
    letterSpacing: 0.5,
    color: "#9ca3af",
  },
  summary: {
    fontSize: 11,
    color: "#6b7280",
  },
  list: {
    display: "flex",
    flexDirection: "column",
    gap: 2,
  },
  edge: {
    display: "block",
    width: "100%",
    textAlign: "left",
    fontSize: 12,
    paddingTop: 4,
    paddingBottom: 4,
    paddingLeft: 8,
    paddingRight: 8,
    borderRadius: 6,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "transparent",
    backgroundColor: "transparent",
    color: "#d1d5db",
    cursor: "pointer",
  },
  edgeActive: {
    borderColor: "#60a5fa",
    backgroundColor: "#1e3a8a",
    color: "#f9fafb",
  },
  multiplicity: {
    color: "#9ca3af",
  },
  line: {
    fontSize: 11,
    color: "#9ca3af",
    wordBreak: "break-word",
  },
  clear: {
    alignSelf: "flex-start",
    fontSize: 11,
    paddingTop: 2,
    paddingBottom: 2,
    paddingLeft: 8,
    paddingRight: 8,
    borderRadius: 6,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "#4b5563",
    backgroundColor: "#111827",
    color: "#e5e7eb",
    cursor: "pointer",
  },
});

function edgeLabel(session: GraphSession, edge: FamilyEdge): string {
  const families = session.families;
  if (families === null) return "";
  const source = families.families[edge.sourceFamily];
  const target = families.families[edge.targetFamily];
  return `${source?.name ?? "?"} → ${target?.name ?? "?"}`;
}

export function FamilyEdges({ session }: { session: GraphSession | null }) {
  const drill = useAtomValue(drilledFamilyEdgeAtom);
  const setDrill = useSetAtom(drillFamilyEdgeAtom);
  const families = session?.families ?? null;
  if (session === null || families === null) return null;

  const drilled = drill === null ? null : drillFamilyEdge(families, drill);
  return (
    <section {...stylex.props(styles.root)} data-testid="family-edges">
      <span {...stylex.props(styles.heading)}>Family edges ({families.renderedEdges.length})</span>
      <span {...stylex.props(styles.summary)}>
        {families.familyCount} families · {families.singletonCount} singletons · {families.fallbackCount}{" "}
        fallback members
      </span>
      {drilled === null ? (
        <div {...stylex.props(styles.list)}>
          {topFamilyEdges(families, TOP_FAMILY_EDGE_LIMIT).map((edge) => (
            <button
              key={edge.edge}
              type="button"
              data-testid={`family-edge-${edge.edge}`}
              onClick={() => {
                setDrill(edge.edge);
              }}
              {...stylex.props(styles.edge)}
            >
              {edgeLabel(session, edge)}{" "}
              <span {...stylex.props(styles.multiplicity)}>
                {relationStyle(edge.relation).glyph} ×{edge.multiplicity}
              </span>
            </button>
          ))}
        </div>
      ) : (
        <div {...stylex.props(styles.list)} data-testid="family-drill">
          <button
            type="button"
            data-testid={`family-edge-${drilled.edge.edge}`}
            onClick={() => setDrill(null)}
            {...stylex.props(styles.edge, styles.edgeActive)}
          >
            {edgeLabel(session, drilled.edge)}{" "}
            <span {...stylex.props(styles.multiplicity)}>
              {relationStyle(drilled.edge.relation).glyph} ×{drilled.edge.multiplicity}
            </span>
          </button>
          {(() => {
            const { lines, remaining } = contributionLines(
              session.graph,
              drilled.links,
              CONTRIBUTION_LINE_LIMIT,
            );
            return (
              <>
                {lines.map((line) => (
                  <span
                    key={line.link}
                    {...stylex.props(styles.line)}
                    data-testid={`contribution-${line.link}`}
                  >
                    {line.source} {relationStyle(line.relation).glyph} {line.target}
                  </span>
                ))}
                {remaining > 0 ? (
                  <span {...stylex.props(styles.line)}>+{remaining} more contributing edges</span>
                ) : null}
              </>
            );
          })()}
          <button type="button" onClick={() => setDrill(null)} {...stylex.props(styles.clear)}>
            Clear drill-down
          </button>
        </div>
      )}
    </section>
  );
}
