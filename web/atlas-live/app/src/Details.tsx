/**
 * Compact details for the inspected entity: a pinned selection while one exists,
 * otherwise the hovered point. It shows the entity's identity (namespaced id,
 * domain, path, symbol name), its incident-link counts per relation labelled with
 * the real relation names, the pinned selection, and the snapshot provenance.
 * Every relation glyph comes from the visual vocabulary, the single owner.
 */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue } from "jotai";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import { inspectedIndexAtom, selectedAtom, selectedProvenanceAtom } from "./atoms.ts";
import type { GraphSession } from "./session.ts";
import { domainStyle, relationStyle } from "./vocabulary.ts";

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
  badge: {
    fontSize: 10,
    textTransform: "uppercase",
    letterSpacing: 0.5,
    paddingTop: 1,
    paddingBottom: 1,
    paddingLeft: 5,
    paddingRight: 5,
    borderRadius: 4,
    backgroundColor: "#1e3a8a",
    color: "#dbeafe",
  },
  hoverBadge: {
    backgroundColor: "#374151",
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
  sectionHeading: {
    fontSize: 11,
    fontWeight: 600,
    textTransform: "uppercase",
    letterSpacing: 0.5,
    color: "#9ca3af",
    marginTop: 4,
  },
  selectionList: {
    display: "flex",
    flexDirection: "column",
    gap: 2,
    fontSize: 12,
    color: "#d1d5db",
  },
});

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div {...stylex.props(styles.row)}>
      <span {...stylex.props(styles.label)}>{label}</span>
      <span {...stylex.props(styles.value)}>{value}</span>
    </div>
  );
}

export function Details({ session }: { session: GraphSession | null }) {
  const inspected = useAtomValue(inspectedIndexAtom);
  const selected = useAtomValue(selectedAtom);
  const records = useAtomValue(selectedProvenanceAtom);
  if (session === null || inspected === null) {
    return (
      <div {...stylex.props(styles.root)}>
        <p {...stylex.props(styles.empty)}>Hover a node to inspect it, or click to pin it.</p>
      </div>
    );
  }
  const pinned = selected.size > 0;
  const id = session.pointId(inspected) ?? "";
  const domain = session.domainOf(inspected);
  const path = session.graph.pointPaths[inspected] ?? null;
  const name = session.graph.pointNames[inspected] ?? null;
  const counts = session.counts(inspected);
  const domainInfo = domain === null ? null : domainStyle(domain);
  return (
    <div {...stylex.props(styles.root)}>
      <div {...stylex.props(styles.chip)}>
        <span>{domainInfo?.glyph ?? "?"}</span>
        <span {...stylex.props(styles.title)}>{id}</span>
        <span {...stylex.props(styles.badge, pinned ? null : styles.hoverBadge)}>
          {pinned ? "pinned" : "hover"}
        </span>
      </div>
      <Field label="Domain" value={domainInfo?.label ?? "unknown"} />
      {path === null ? null : <Field label="Path" value={path} />}
      {name === null ? null : <Field label="Symbol" value={name} />}
      <div {...stylex.props(styles.counts)}>
        {RELATION_ORDER.map((relation) => {
          const count = counts[relation];
          const style = relationStyle(relation);
          return (
            <div key={relation} {...stylex.props(styles.countRow)}>
              <span {...stylex.props(styles.countName)}>
                {style.glyph} {style.label}
              </span>
              <span {...stylex.props(styles.countValue)}>
                in {count.in} · out {count.out}
              </span>
            </div>
          );
        })}
      </div>
      {pinned ? (
        <>
          <span {...stylex.props(styles.sectionHeading)}>Selection ({selected.size})</span>
          <div {...stylex.props(styles.selectionList)} data-testid="selection">
            {records.map((record) => (
              <span key={record.id}>
                {record.path === null ? record.id : `${record.id} · ${record.path}`}
              </span>
            ))}
          </div>
        </>
      ) : null}
      <span {...stylex.props(styles.sectionHeading)}>Provenance</span>
      <Field label="Snapshot" value={session.graph.provenance.snapshotId} />
      <Field label="Repository" value={session.graph.provenance.repository} />
      <Field label="Base revision" value={session.graph.provenance.baseRevision} />
    </div>
  );
}
