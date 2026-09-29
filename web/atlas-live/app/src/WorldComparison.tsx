/** Frozen signature medians beside the current all-seed physical measurement. */
import * as stylex from "@stylexjs/stylex";
import { useEffect, useRef, useState } from "react";

import type { RepositorySignature } from "../../projection/src/manifest.ts";
import type { SessionSnapshot } from "./controller.ts";

type RankMode = "recurrence" | "compression" | "survival" | "reach";
const MODES: readonly { mode: RankMode; label: string }[] = [
  { mode: "recurrence", label: "Recurrence" },
  { mode: "compression", label: "Compression" },
  { mode: "survival", label: "Survival" },
  { mode: "reach", label: "Reach" },
];

function rankValue(signature: RepositorySignature, mode: RankMode): number {
  switch (mode) {
    case "recurrence": return signature.fileRecurrence;
    case "compression": return signature.physicalCompression;
    case "survival": return 1 - signature.fileExtinction;
    case "reach": return signature.fileReachP90;
  }
  throw new Error("unknown rank mode");
}

function formatted(value: number, mode: RankMode): string {
  if (mode === "survival" || mode === "reach") return `${(value * 100).toFixed(2)}%`;
  return `${value.toLocaleString(undefined, { maximumFractionDigits: 2 })}×`;
}

function median(values: number[]): number {
  const sorted = values.toSorted((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1
    ? (sorted[middle] ?? 0)
    : ((sorted[middle - 1] ?? 0) + (sorted[middle] ?? 0)) / 2;
}

const styles = stylex.create({
  root: { display: "flex", flexDirection: "column", gap: 14, paddingTop: 18,
    borderTopWidth: 1, borderTopStyle: "solid", borderTopColor: "rgba(255,255,255,.2)" },
  heading: { margin: 0, textAlign: "center", fontSize: 17, fontWeight: 700, color: "#fff4fa" },
  source: { textAlign: "center", color: "#cbbbc7", fontSize: 12, lineHeight: 1.45 },
  metricGrid: { display: "grid", gridTemplateColumns: "repeat(2,minmax(0,1fr))", gap: 8 },
  metric: { display: "flex", flexDirection: "column", gap: 3, minWidth: 0, padding: 10,
    borderWidth: 1, borderStyle: "solid", borderColor: "rgba(255,255,255,.16)",
    borderRadius: 6, backgroundColor: "rgba(255,255,255,.045)" },
  metricLabel: { color: "#ddc7d4", fontSize: 12 },
  metricValue: { color: "#ffe4f0", fontSize: 18, fontWeight: 700, fontVariantNumeric: "tabular-nums" },
  interpretation: { margin: 0, color: "#f3d6e5", fontSize: 13, lineHeight: 1.5,
    padding: 10, borderLeftWidth: 3, borderLeftStyle: "solid", borderLeftColor: "#eaa4c5",
    backgroundColor: "rgba(234,164,197,.08)" },
  current: { textAlign: "center", fontSize: 12, lineHeight: 1.45, color: "#cbbbc7",
    fontVariantNumeric: "tabular-nums" },
  switches: { display: "grid", gridTemplateColumns: "repeat(2,minmax(0,1fr))", gap: 6,
    minWidth: 0, margin: 0, padding: 0, borderWidth: 0 },
  switchLegend: { color: "#ddc7d4", fontSize: 12, paddingBottom: 7 },
  switchButton: { minHeight: 36, padding: 7, fontFamily: "inherit", fontSize: 12,
    fontWeight: 650, color: "#e8dce4", backgroundColor: "rgba(255,255,255,.05)",
    borderWidth: 1, borderStyle: "solid", borderColor: "rgba(255,255,255,.2)",
    borderRadius: 5, cursor: "pointer" },
  switchSelected: { color: "#fff4fa", backgroundColor: "#5b3048", borderColor: "#f0a4c8" },
  order: { textAlign: "center", fontSize: 12, color: "#c9bac5" },
  list: { position: "relative", display: "flex", flexDirection: "column", gap: 4,
    maxHeight: 350, overflowY: "auto", paddingRight: 3 },
  row: { display: "grid", gridTemplateColumns: "26px minmax(0,1fr) auto", alignItems: "center",
    gap: 8, width: "100%", minHeight: 47, borderWidth: 1, borderStyle: "solid",
    borderColor: "rgba(255,255,255,.1)", borderRadius: 5, padding: 8,
    textAlign: "left", fontFamily: "inherit", fontSize: 13, color: "#f0e7ed",
    backgroundColor: { default: "rgba(255,255,255,.03)", ":hover": "rgba(255,255,255,.11)" },
    cursor: "pointer" },
  selected: { borderColor: "#e89bbb", color: "#fff4fa", backgroundColor: "rgba(226,138,181,.22)" },
  rank: { color: "#c9bac5", fontVariantNumeric: "tabular-nums", fontSize: 12 },
  name: { minWidth: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", fontWeight: 650 },
  detail: { gridColumnStart: 2, gridColumnEnd: 4, color: "#c9bac5", fontSize: 11 },
  value: { fontVariantNumeric: "tabular-nums", fontWeight: 700, color: "#ffd0e5" },
});

export function WorldComparison({ state, onSelect }: {
  state: SessionSnapshot;
  onSelect: (snapshotId: string) => void;
}) {
  const [mode, setMode] = useState<RankMode>("recurrence");
  const listRef = useRef<HTMLDivElement>(null);
  const selectedRef = useRef<HTMLButtonElement>(null);
  const repositories = new Map<string, (typeof state.options)[number]>();
  for (const option of state.options) {
    if (option.synthetic || option.entry.signatureSummary === undefined) continue;
    const previous = repositories.get(option.repository);
    if (previous === undefined || option.entry.counts.points < previous.entry.counts.points ||
      (option.entry.counts.points === previous.entry.counts.points && option.value < previous.value))
      repositories.set(option.repository, option);
  }
  const cohort = [...repositories.values()];
  const ranked = cohort.toSorted((a, b) =>
    rankValue(b.entry.signatureSummary!, mode) - rankValue(a.entry.signatureSummary!, mode) ||
    a.repository.localeCompare(b.repository));
  const currentEntry = state.session?.entry;
  const currentSignature = currentEntry?.signatureSummary;
  const currentPhysical = currentEntry?.physicalSummary;
  const currentFamilies = currentEntry?.familySummary;
  const rank = ranked.findIndex((option) => option.repository === currentEntry?.repository);
  const survivalMedian = median(cohort.map((option) => 1 - option.entry.signatureSummary!.fileExtinction));
  const reachMedian = median(cohort.map((option) => option.entry.signatureSummary!.fileReachP90));
  useEffect(() => {
    const list = listRef.current;
    const row = selectedRef.current;
    if (list === null || row === null) return;
    list.scrollTop = row.offsetTop - (list.clientHeight - row.clientHeight) / 2;
  });
  return (
    <section aria-label="Repository signature comparison" {...stylex.props(styles.root)}>
      <h2 {...stylex.props(styles.heading)}>Repository signatures</h2>
      <div {...stylex.props(styles.source)}>Depth-7, 16-seed Atlas panel · repository medians · {cohort.length} repositories</div>
      {currentSignature === undefined ? null : (
        <>
          <div {...stylex.props(styles.metricGrid)} data-testid="signature-metrics">
            <div {...stylex.props(styles.metric)}><span {...stylex.props(styles.metricLabel)}>File survival</span>
              <strong {...stylex.props(styles.metricValue)}>{formatted(1 - currentSignature.fileExtinction, "survival")}</strong></div>
            <div {...stylex.props(styles.metric)}><span {...stylex.props(styles.metricLabel)}>File p90 reach</span>
              <strong {...stylex.props(styles.metricValue)}>{formatted(currentSignature.fileReachP90, "reach")}</strong></div>
            <div {...stylex.props(styles.metric)}><span {...stylex.props(styles.metricLabel)}>File recurrence</span>
              <strong {...stylex.props(styles.metricValue)}>{formatted(currentSignature.fileRecurrence, "recurrence")}</strong></div>
            <div {...stylex.props(styles.metric)}><span {...stylex.props(styles.metricLabel)}>Physical compression</span>
              <strong {...stylex.props(styles.metricValue)}>{formatted(currentSignature.physicalCompression, "compression")}</strong></div>
          </div>
          <p {...stylex.props(styles.interpretation)} data-testid="signature-reading">
            Cohort median: file survival {(survivalMedian * 100).toFixed(2)}% · file p90 reach {(reachMedian * 100).toFixed(2)}%.
            Measurements describe the depth-7 signature; the interactive structural landscape uses depth 1–3.
          </p>
          <div {...stylex.props(styles.current)} data-testid="reuse-comparison-current">
            {currentEntry?.repository} · rank {rank + 1}/{ranked.length} in {MODES.find((item) => item.mode === mode)?.label.toLowerCase()}
            <br />
            {currentSignature.snapshots} represented snapshot{currentSignature.snapshots === 1 ? "" : "s"} · all-seed physical reuse {currentPhysical === undefined ? "unmeasured" : `${(currentPhysical.reuseFraction * 100).toFixed(2)}%`}
            <br />
            {currentFamilies === undefined ? "Physical only · no Families record" : `${currentFamilies.count} families in this snapshot`}
          </div>
        </>
      )}
      <fieldset {...stylex.props(styles.switches)}>
        <legend {...stylex.props(styles.switchLegend)}>Rank repositories by</legend>
        {MODES.map((item) => <button key={item.mode} type="button" aria-pressed={mode === item.mode}
          {...stylex.props(styles.switchButton, mode === item.mode && styles.switchSelected)}
          onClick={() => setMode(item.mode)}>{item.label}</button>)}
      </fieldset>
      <span {...stylex.props(styles.order)}>High to low · select a repository</span>
      <div ref={listRef} {...stylex.props(styles.list)} data-testid="reuse-comparison-list">
        {ranked.map((option, index) => <button key={option.repository} type="button"
          ref={option.repository === currentEntry?.repository ? selectedRef : null}
          aria-current={option.repository === currentEntry?.repository ? "true" : undefined}
          {...stylex.props(styles.row, option.repository === currentEntry?.repository && styles.selected)}
          onClick={() => onSelect(option.value)}>
            <span {...stylex.props(styles.rank)}>{String(index + 1).padStart(2, "0")}</span>
            <span {...stylex.props(styles.name)} title={option.repository}>{option.repository}</span>
            <span {...stylex.props(styles.value)}>{formatted(rankValue(option.entry.signatureSummary!, mode), mode)}</span>
            <span {...stylex.props(styles.detail)}>{option.entry.signatureSummary!.snapshots} snapshot{option.entry.signatureSummary!.snapshots === 1 ? "" : "s"} · {option.entry.familySummary === undefined ? "physical only in this revision" : `${option.entry.familySummary.count} families in this revision`}</span>
          </button>)}
      </div>
    </section>
  );
}
