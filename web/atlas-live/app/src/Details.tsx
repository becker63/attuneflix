/**
 * Compact details for the hovered entity: its identity (namespaced id, domain,
 * path and symbol name) and its incident-link counts per relation, labelled with
 * the real relation names. Nothing here is Atlas terminology or an invented
 * label.
 */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue } from "jotai";

import { RELATION_ORDER, type Relation } from "../../projection/src/relation.ts";
import { hoveredIndexAtom } from "./atoms.ts";
import type { GraphSession } from "./session.ts";
import { domainStyle } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    display: "flex",
    flexDirection: "column",
    gap: 10,
  },
  empty: {
    color: "#9ca3af",
    fontSize: 13,
  },
  title: {
    fontSize: 13,
    fontWeight: 600,
    color: "#e5e7eb",
  },
  row: {
    display: "flex",
    justifyContent: "space-between",
    gap: 12,
    fontSize: 12,
    color: "#d1d5db",
  },
  label: {
    color: "#9ca3af",
  },
  value: {
    textAlign: "right",
    wordBreak: "break-word",
  },
  chip: {
    display: "inline-flex",
    alignItems: "center",
    gap: 6,
    fontSize: 12,
    color: "#e5e7eb",
  },
  counts: {
    display: "flex",
    flexDirection: "column",
    gap: 4,
    marginTop: 4,
  },
  countRow: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    fontSize: 12,
    color: "#e5e7eb",
  },
  countName: {
    minWidth: 64,
  },
  countValue: {
    color: "#9ca3af",
  },
});

const RELATION_GLYPH: Record<Relation, string> = {
  defines: "▸",
  imports: "⇢",
  calls: "↻",
  parent: "⤴",
};

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div {...stylex.props(styles.row)}>
      <span {...stylex.props(styles.label)}>{label}</span>
      <span {...stylex.props(styles.value)}>{value}</span>
    </div>
  );
}

export function Details({ session }: { session: GraphSession | null }) {
  const hovered = useAtomValue(hoveredIndexAtom);
  if (session === null || hovered === null) {
    return (
      <div {...stylex.props(styles.root)}>
        <p {...stylex.props(styles.empty)}>Hover a node to inspect it.</p>
      </div>
    );
  }
  const id = session.pointId(hovered) ?? "";
  const domain = session.domainOf(hovered);
  const path = session.graph.pointPaths[hovered] ?? null;
  const name = session.graph.pointNames[hovered] ?? null;
  const counts = session.counts(hovered);
  const domainInfo = domain === null ? null : domainStyle(domain);
  return (
    <div {...stylex.props(styles.root)}>
      <div {...stylex.props(styles.chip)}>
        <span>{domainInfo?.glyph ?? "?"}</span>
        <span {...stylex.props(styles.title)}>{id}</span>
      </div>
      <Field label="Domain" value={domainInfo?.label ?? "unknown"} />
      {path === null ? null : <Field label="Path" value={path} />}
      {name === null ? null : <Field label="Symbol" value={name} />}
      <div {...stylex.props(styles.counts)}>
        {RELATION_ORDER.map((relation) => {
          const count = counts[relation];
          return (
            <div key={relation} {...stylex.props(styles.countRow)}>
              <span {...stylex.props(styles.countName)}>
                {RELATION_GLYPH[relation]} {relation}
              </span>
              <span {...stylex.props(styles.countValue)}>
                in {count.in} · out {count.out}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
