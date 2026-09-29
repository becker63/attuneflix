/**
 * Compact details for the inspected entity: a pinned selection while one exists,
 * otherwise the hovered point. It shows the entity's identity (namespaced id,
 * domain, path, symbol name), its incident-link counts per relation labelled with
 * the real relation names, the pinned selection, and the snapshot provenance.
 * Every relation glyph comes from the visual vocabulary, the single owner.
 */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue, useSetAtom } from "jotai";
import { useEffect, useMemo, useRef, useState } from "react";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import {
  inspectedIndexAtom,
  selectedAtom,
  selectedProvenanceAtom,
  selectedWireAtom,
  showWireConstituentsAtom,
  wireConstituentsAtom,
} from "./atoms.ts";
import { familyMembership } from "./families.ts";
import { inspectWire } from "./frontier/inspector.ts";
import { deriveLensProofs, LENS_ORDER, type LensRelation } from "./frontier/proofs.ts";
import { regionReuse } from "./physical.ts";
import type { GraphSession } from "./session.ts";
import { domainStyle, familyColor, relationStyle } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    display: "flex",
    flexDirection: "column",
    gap: 12,
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopStyle: "solid",
    borderTopColor: "rgba(255, 255, 255, 0.18)",
  },
  empty: {
    color: "#c9bac5",
    fontSize: 13,
  },
  title: {
    fontSize: 15,
    fontWeight: 700,
    color: "#fff4fa",
    overflowWrap: "anywhere",
  },
  row: {
    display: "flex",
    justifyContent: "space-between",
    gap: 12,
    fontSize: 13,
    lineHeight: 1.4,
    color: "#f0e7ed",
  },
  label: {
    color: "#c9bac5",
  },
  value: {
    textAlign: "right",
    wordBreak: "break-word",
  },
  chip: {
    display: "inline-flex",
    alignItems: "center",
    gap: 6,
    fontSize: 13,
    color: "#f0e7ed",
  },
  badge: {
    fontSize: 11,
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
  markerBadge: {
    backgroundColor: "#374151",
    color: "#e5e7eb",
    marginLeft: 6,
  },
  swatch: {
    display: "inline-block",
    width: 9,
    height: 9,
    borderRadius: 2,
    marginRight: 6,
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
    fontSize: 13,
    color: "#f0e7ed",
  },
  countName: {
    minWidth: 64,
  },
  countValue: {
    color: "#c9bac5",
  },
  sectionHeading: {
    fontSize: 12,
    fontWeight: 700,
    color: "#e8c5d8",
    marginTop: 4,
  },
  selectionList: {
    display: "flex",
    flexDirection: "column",
    gap: 2,
    fontSize: 13,
    color: "#f0e7ed",
  },
  action: {
    alignSelf: "flex-start",
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "#76576c",
    borderRadius: 6,
    backgroundColor: "#281722",
    color: "#f3e8ef",
    paddingTop: 5,
    paddingBottom: 5,
    paddingLeft: 9,
    paddingRight: 9,
    cursor: "pointer",
    fontSize: 12,
  },
  proof: {
    padding: 8,
    borderLeftWidth: 2,
    borderLeftStyle: "solid",
    borderLeftColor: "#b984a2",
    backgroundColor: "rgba(150, 93, 126, 0.12)",
    borderRadius: 4,
    fontSize: 12,
    lineHeight: 1.45,
    overflowWrap: "anywhere",
  },
  proofSteps: {
    marginTop: 5,
    display: "flex",
    flexDirection: "column",
    gap: 2,
    color: "#cbd5e1",
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

/** The family's tint swatch; the colour is memoized so the style prop is stable. */
function FamilySwatch({ ordinal }: { ordinal: number }) {
  const style = useMemo(() => ({ backgroundColor: familyColor(ordinal) }), [ordinal]);
  return <span {...stylex.props(styles.swatch)} style={style} />;
}

function WireDetails({ session, index }: { session: GraphSession; index: number }) {
  const panelRef = useRef<HTMLElement>(null);
  useEffect(() => {
    if (index >= 0) panelRef.current?.scrollIntoView({ block: "start", inline: "nearest" });
  }, [index]);
  const showConstituents = useAtomValue(wireConstituentsAtom);
  const setShowConstituents = useSetAtom(showWireConstituentsAtom);
  const wire = session.getViewSnapshot().projection.wires[index];
  if (wire === undefined) return null;
  const detail = inspectWire(session.graph, wire);
  return (
    <section
      ref={panelRef}
      aria-label="Connection"
      {...stylex.props(styles.root)}
      data-testid="wire-inspector"
    >
      <span {...stylex.props(styles.title)}>
        {detail.source} → {detail.target}
      </span>
      <Field label="Relation" value={detail.relation} />
      <Field label="Boundary" value="Crosses visible regions" />
      <Field label="Exact edges" value={detail.multiplicity.toLocaleString()} />
      <Field label="Source entities" value={detail.uniqueSources.toLocaleString()} />
      <Field label="Target entities" value={detail.uniqueTargets.toLocaleString()} />
      <button
        type="button"
        {...stylex.props(styles.action)}
        onClick={() => setShowConstituents(!showConstituents)}
      >
        {showConstituents ? "Back to summary" : "Show contributing edges"}
      </button>
      {showConstituents ? (
        <div {...stylex.props(styles.selectionList)} data-testid="wire-contributions">
          {detail.contributions.map((row) => (
            <span key={row.row}>
              {row.source} → {row.target} <span {...stylex.props(styles.label)}>· row {row.row}</span>
            </span>
          ))}
          {detail.remaining > 0 ? <span>+{detail.remaining} more contributing edges</span> : null}
        </div>
      ) : null}
      <span {...stylex.props(styles.sectionHeading)}>Provenance</span>
      <Field label="Source ID" value={detail.sourceId} />
      <Field label="Target ID" value={detail.targetId} />
      <Field label="Snapshot" value={session.graph.provenance.snapshotId} />
    </section>
  );
}

function LensProofs({ session, index }: { session: GraphSession; index: number }) {
  const [active, setActive] = useState<LensRelation | null>(null);
  const proofs = useMemo(() => deriveLensProofs(session.graph, index, 6), [session, index]);
  const visible = active === null ? [] : proofs.filter((proof) => proof.relation === active);
  if (proofs.length === 0) return null;
  return (
    <section aria-label="Derived relation proofs" {...stylex.props(styles.root)} data-testid="lens-proofs">
      <span {...stylex.props(styles.sectionHeading)}>Relation lenses · exact witnesses</span>
      <div {...stylex.props(styles.selectionList)}>
        {LENS_ORDER.map((relation) => {
          const count = proofs.filter((proof) => proof.relation === relation).length;
          return count === 0 ? null : (
            <button
              key={relation}
              type="button"
              aria-pressed={active === relation}
              {...stylex.props(styles.action)}
              onClick={() => setActive(active === relation ? null : relation)}
            >
              {relation} · {count}
              {count === 6 ? "+" : ""}
            </button>
          );
        })}
      </div>
      {visible.map((proof) => (
        <div
          key={`${proof.relation}:${proof.targetId}`}
          {...stylex.props(styles.proof)}
          data-testid="proof-card"
        >
          <strong>
            {proof.source} → {proof.target}
          </strong>
          <div {...stylex.props(styles.proofSteps)}>
            {proof.steps.map((step) => (
              <span key={step.row}>
                {step.source} —{step.relation}→ {step.target} · row {step.row}
              </span>
            ))}
          </div>
        </div>
      ))}
    </section>
  );
}

export function Details({ session }: { session: GraphSession | null }) {
  const inspected = useAtomValue(inspectedIndexAtom);
  const selected = useAtomValue(selectedAtom);
  const records = useAtomValue(selectedProvenanceAtom);
  const selectedWire = useAtomValue(selectedWireAtom);
  if (
    session !== null &&
    selectedWire !== null &&
    selectedWire.viewRevision === session.getViewSnapshot().revision
  ) {
    return <WireDetails session={session} index={selectedWire.index} />;
  }
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
  const metrics = session.metricsFor(inspected);
  const domainInfo = domain === null ? null : domainStyle(domain);
  // The family membership of the inspected point, with the F3 honesty markers:
  // a fallback member joined its defining file's seed family (no recorded
  // frontier held it); a singleton family has exactly one member.
  const family = session.families === null ? null : familyMembership(session.families, inspected);
  const physical = session.physical?.byPointIndex.get(inspected);
  const directoryPhysical =
    domain === "location" && session.physical !== null
      ? regionReuse(session.layout, session.physical).get(
          inspected - session.graph.fileCount - session.graph.symbolCount,
        )
      : undefined;
  const physicalMetric = physical ?? directoryPhysical;
  return (
    <div {...stylex.props(styles.root)}>
      <div {...stylex.props(styles.chip)}>
        <span>{domainInfo?.glyph ?? "?"}</span>
        <span {...stylex.props(styles.title)}>
          {name ?? path ?? session.graph.pointLabels[inspected] ?? id}
        </span>
        <span {...stylex.props(styles.badge, pinned ? null : styles.hoverBadge)}>
          {pinned ? "pinned" : "hover"}
        </span>
      </div>
      <Field label="Domain" value={domainInfo?.label ?? "unknown"} />
      {path === null ? null : <Field label="Path" value={path} />}
      {name === null ? null : <Field label="Symbol" value={name} />}
      {metrics === null ? null : (
        <>
          <span {...stylex.props(styles.sectionHeading)}>Architecture</span>
          {metrics.region === id ? null : (
            <Field
              label="Visible region"
              value={
                session.graph.pointLabels[session.graph.indexById.get(metrics.region) ?? -1] ?? metrics.region
              }
            />
          )}
          <Field label="Internal edges" value={metrics.internal.toLocaleString()} />
          <Field label="Ingress" value={metrics.ingress.toLocaleString()} />
          <Field label="Egress" value={metrics.egress.toLocaleString()} />
          <Field label="Localness" value={`${(metrics.localness * 100).toFixed(1)}%`} />
          <Field label="Reach · 1 / 2 / 3" value={metrics.reach.join(" / ")} />
          <Field
            label="Imports · in / out / internal"
            value={`${metrics.ingressByRelation.imports} / ${metrics.egressByRelation.imports} / ${metrics.internalByRelation.imports}`}
          />
          <Field
            label="Calls · in / out / internal"
            value={`${metrics.ingressByRelation.calls} / ${metrics.egressByRelation.calls} / ${metrics.internalByRelation.calls}`}
          />
        </>
      )}
      {family === null ? null : (
        <>
          <div {...stylex.props(styles.row)}>
            <span {...stylex.props(styles.label)}>Family</span>
            <span {...stylex.props(styles.value)}>
              <FamilySwatch ordinal={family.ordinal} />
              {family.name}
              {family.singleton ? (
                <span {...stylex.props(styles.badge, styles.markerBadge)}>singleton</span>
              ) : null}
              {family.fallback ? (
                <span {...stylex.props(styles.badge, styles.markerBadge)}>fallback</span>
              ) : null}
            </span>
          </div>
          <Field label="Family members" value={String(family.members)} />
        </>
      )}
      {physicalMetric === undefined ? null : (
        <>
          <span {...stylex.props(styles.sectionHeading)}>Physical reuse · depth 7</span>
          <Field label="Reuse fraction" value={`${(physicalMetric.reuseFraction * 100).toFixed(2)}%`} />
          <Field
            label="Reused / requests"
            value={`${physicalMetric.reuses.toLocaleString()} / ${physicalMetric.requests.toLocaleString()}`}
          />
          {directoryPhysical === undefined ? null : (
            <Field label="Measured seeds" value={directoryPhysical.measuredSeeds.toLocaleString()} />
          )}
        </>
      )}
      {pinned ? <LensProofs key={id} session={session} index={inspected} /> : null}
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
      <Field label="Entity ID" value={id} />
      <Field label="Snapshot" value={session.graph.provenance.snapshotId} />
      <Field label="Repository" value={session.graph.provenance.repository} />
      <Field label="Base revision" value={session.graph.provenance.baseRevision} />
    </div>
  );
}
