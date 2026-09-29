/** Static structural separation controls and exact measurements on the one graph. */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue, useSetAtom } from "jotai";
import { useMemo, useSyncExternalStore } from "react";

import {
  landscapeDepthAtom,
  landscapeOriginsAtom,
  landscapeThresholdAtom,
} from "./atoms.ts";
import {
  convergenceGraph,
  greedySeparatedSet,
  greedyStructuralWaves,
  neighborhoodIndex,
  originNeighborhood,
  pairGeometry,
  separationDecay,
  sharedNeighborhoodIds,
} from "./frontier/parallelism.ts";
import { regionReuse } from "./physical.ts";
import type { GraphSession } from "./session.ts";

const styles = stylex.create({
  root: { display: "flex", flexDirection: "column", gap: 12, paddingTop: 16,
    borderTopWidth: 1, borderTopStyle: "solid", borderTopColor: "rgba(255,255,255,.2)",
    color: "#eee3ea", fontSize: 13, lineHeight: 1.45 },
  title: { margin: 0, fontSize: 17, color: "#fff4fa" },
  note: { color: "#cbbbc7", margin: 0 },
  choices: { display: "flex", gap: 6, flexWrap: "wrap" },
  button: { borderWidth: 1, borderStyle: "solid", borderColor: "rgba(255,255,255,.24)",
    borderRadius: 5, paddingTop: 7, paddingBottom: 7, paddingLeft: 10, paddingRight: 10,
    minHeight: 34, backgroundColor: "rgba(255,255,255,.05)",
    color: "#f5e8ef", fontFamily: "inherit", fontSize: 12, cursor: "pointer" },
  clearButton: { borderWidth: 0, padding: 0, backgroundColor: "transparent",
    color: "#d5c4ce", fontFamily: "inherit", fontSize: 11, textDecoration: "underline",
    cursor: "pointer" },
  active: { borderColor: "#f3b4d3", backgroundColor: "#5b3048" },
  originHeading: { display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: 8 },
  details: { borderTopWidth: 1, borderTopStyle: "solid", borderTopColor: "rgba(255,255,255,.2)",
    paddingTop: 8 },
  summary: { cursor: "pointer", color: "#eee3ea", fontWeight: 600 },
  stat: { display: "flex", justifyContent: "space-between", gap: 12,
    fontVariantNumeric: "tabular-nums" },
  strong: { color: "#ffe1ee", fontWeight: 700, textAlign: "right" },
  subheading: { margin: 0, color: "#ffd8e9", fontWeight: 700, fontSize: 13 },
  table: { width: "100%", borderCollapse: "collapse", fontVariantNumeric: "tabular-nums" },
  cell: { paddingTop: 4, paddingBottom: 4, paddingLeft: 2, paddingRight: 2,
    borderBottomWidth: 1, borderBottomStyle: "solid",
    borderBottomColor: "rgba(255,255,255,.12)", textAlign: "right" },
  firstCell: { textAlign: "left" },
  shared: { color: "#ffe0ae" },
  a: { color: "#a8d7fa" },
  b: { color: "#ebb0e2" },
  decay: { display: "grid", gridTemplateColumns: "32px 1fr auto", gap: 7, alignItems: "center",
    fontVariantNumeric: "tabular-nums" },
  bar: { height: 12, width: "100%", accentColor: "#7db6d6" },
  small: { color: "#cbbbc7", fontSize: 11 },
  path: { overflowWrap: "anywhere" },
});

function label(session: GraphSession, id: string): string {
  const index = session.graph.indexById.get(id);
  return index === undefined ? id : session.graph.pointPaths[index] ??
    session.graph.pointNames[index] ?? session.graph.pointLabels[index] ?? id;
}

function physicalReuse(session: GraphSession, id: string): string {
  if (session.physical === null) return "unmeasured";
  const index = session.graph.indexById.get(id);
  if (index === undefined) return "unmeasured";
  const directoryStart = session.graph.fileCount + session.graph.symbolCount;
  if (index >= directoryStart) {
    const measured = regionReuse(session.layout, session.physical).get(index - directoryStart);
    return measured === undefined ? "unmeasured" : `${(measured.reuseFraction * 100).toFixed(2)}% · ${measured.measuredSeeds} seeds`;
  }
  const measured = session.physical.seeds.find((seed) => seed.pointIndex === index);
  return measured === undefined ? "unmeasured" : `${(measured.reuseFraction * 100).toFixed(2)}%`;
}

export function ParallelismPanel({ session }: { session: GraphSession }) {
  const view = useSyncExternalStore(session.subscribeView, session.getViewSnapshot, session.getViewSnapshot);
  const depth = useAtomValue(landscapeDepthAtom);
  const setDepth = useSetAtom(landscapeDepthAtom);
  const threshold = useAtomValue(landscapeThresholdAtom);
  const setThreshold = useSetAtom(landscapeThresholdAtom);
  const origins = useAtomValue(landscapeOriginsAtom);
  const setOrigins = useSetAtom(landscapeOriginsAtom);
  const index = useMemo(
    () => neighborhoodIndex(view.projection, session.containment),
    [view.projection, session.containment],
  );
  const a = origins.a !== null && index.ordinalById.has(origins.a) ? origins.a : null;
  const b = origins.b !== null && index.ordinalById.has(origins.b) ? origins.b : null;
  const graph = useMemo(() => convergenceGraph(index, depth, threshold), [index, depth, threshold]);
  const separated = useMemo(() => greedySeparatedSet(graph), [graph]);
  const waves = useMemo(() => greedyStructuralWaves(graph), [graph]);
  const decay = useMemo(() => separationDecay(index, threshold), [index, threshold]);
  const pair = a !== null && b !== null ? pairGeometry(index, a, b) : null;
  const aNeighborhood = a === null ? null : originNeighborhood(index, a);
  const nearest = a === null ? [] : index.candidates
    .filter((candidate) => candidate !== a)
    .map((candidate) => ({ id: candidate, pair: pairGeometry(index, a, candidate) }))
    .toSorted((left, right) =>
      (left.pair.convergenceDepth ?? 4) - (right.pair.convergenceDepth ?? 4) ||
      (right.pair.depths[depth - 1]?.overlap ?? 0) - (left.pair.depths[depth - 1]?.overlap ?? 0) ||
      left.id.localeCompare(right.id),
    ).slice(0, 5);
  const shared = pair === null ? [] : sharedNeighborhoodIds(index, pair.a, pair.b, depth);
  const maxDecay = Math.max(1, ...decay);
  const decayRows = [{ depth: 1, count: decay[0] }, { depth: 2, count: decay[1] }, { depth: 3, count: decay[2] }];
  const pairRows = pair === null ? [] : [
    { depth: 1, metrics: pair.depths[0] },
    { depth: 2, metrics: pair.depths[1] },
    { depth: 3, metrics: pair.depths[2] },
  ];

  return <section aria-label="Static structural separation" data-testid="parallelism-panel" {...stylex.props(styles.root)}>
    <h2 {...stylex.props(styles.title)}>Structural separation</h2>
    <p {...stylex.props(styles.note)}>Click a region, then Shift-click another to compare structural reach.</p>
    <div {...stylex.props(styles.choices)} aria-label="Structural depth">
      {([1, 2, 3] as const).map((value) => <button key={value} type="button"
        aria-pressed={depth === value} onClick={() => setDepth(value)}
        {...stylex.props(styles.button, depth === value && styles.active)}>{value}°</button>)}
    </div>
    <div {...stylex.props(styles.choices)} aria-label="Overlap display threshold">
      <span>Overlap threshold τ</span>
      {[0.1, 0.25, 0.5].map((value) => <button key={value} type="button"
        aria-pressed={threshold === value} onClick={() => setThreshold(value)}
        {...stylex.props(styles.button, threshold === value && styles.active)}>{value.toFixed(2)}</button>)}
    </div>
    <span {...stylex.props(styles.small)}>Depth 1–3 follows visible Imports/Calls. Physical color remains a separate depth-7 measurement.</span>
    {a === null ? <p {...stylex.props(styles.note)}>Select a visible region or file on the graph to inspect reach 1°–3°.</p> : <>
      <div {...stylex.props(styles.originHeading)}>
        <h3 {...stylex.props(styles.subheading, styles.a)}>Origin A · <span {...stylex.props(styles.path)}>{label(session, a)}</span></h3>
        <button type="button" {...stylex.props(styles.clearButton)} onClick={() => setOrigins({ a: b, b: null })}>Clear A</button>
      </div>
      {b !== null ? <>
        <div {...stylex.props(styles.originHeading)}>
          <h3 {...stylex.props(styles.subheading, styles.b)}>Origin B · <span {...stylex.props(styles.path)}>{label(session, b)}</span></h3>
          <button type="button" {...stylex.props(styles.clearButton)} onClick={() => setOrigins({ a, b: null })}>Clear B</button>
        </div>
        <div {...stylex.props(styles.stat)}><span>Convergence depth</span>
          <strong {...stylex.props(styles.strong)}>{pair?.convergenceDepth === null ? ">3° · censored" : `${pair?.convergenceDepth}°`}</strong></div>
        <h3 {...stylex.props(styles.subheading, styles.shared)}>Shared structural neighborhood</h3>
        <table {...stylex.props(styles.table)}><thead><tr><th {...stylex.props(styles.cell, styles.firstCell)}>Depth</th>
          <th {...stylex.props(styles.cell)}>A</th><th {...stylex.props(styles.cell)}>B</th>
          <th {...stylex.props(styles.cell)}>Shared</th><th {...stylex.props(styles.cell)}>Union</th>
          <th {...stylex.props(styles.cell)}>Jaccard</th></tr></thead>
          <tbody>{pairRows.map((row) => <tr key={row.depth}>
            <td {...stylex.props(styles.cell, styles.firstCell)}>{row.depth}°</td>
            <td {...stylex.props(styles.cell)}>{row.metrics.a}</td><td {...stylex.props(styles.cell)}>{row.metrics.b}</td>
            <td {...stylex.props(styles.cell, styles.shared)}>{row.metrics.intersection}</td>
            <td {...stylex.props(styles.cell)}>{row.metrics.union}</td>
            <td {...stylex.props(styles.cell)}>{row.metrics.overlap.toFixed(3)}</td>
          </tr>)}</tbody></table>
        <span {...stylex.props(styles.small)}>{shared.length} shared at {depth}° · {shared.slice(0, 5).map((id) => label(session, id)).join(", ") || "none"}{shared.length > 5 ? ` +${shared.length - 5} more` : ""}</span>
      </> : <>
        <div {...stylex.props(styles.stat)}><span>Reach 1° / 2° / 3°</span><strong {...stylex.props(styles.strong)}>{aNeighborhood?.sizes.join(" / ")}</strong></div>
        <div {...stylex.props(styles.stat)}><span>Frontier growth Δ2 / Δ3</span><strong {...stylex.props(styles.strong)}>{aNeighborhood?.growth.join(" / ")}</strong></div>
        <div {...stylex.props(styles.stat)}><span>Convergence degree</span><strong {...stylex.props(styles.strong)}>{graph.neighbors.get(a)?.size ?? "outside aggregate"}</strong></div>
        <div {...stylex.props(styles.stat)}><span>Separated-set member</span><strong {...stylex.props(styles.strong)}>{index.candidates.includes(a) ? (separated.includes(a) ? "yes" : "no") : "outside aggregate"}</strong></div>
        <details>
          <summary {...stylex.props(styles.summary)}>Nearest converging regions</summary>
          {nearest.map(({ id, pair: comparison }) => <div key={id} {...stylex.props(styles.stat)}>
            <span {...stylex.props(styles.path)}>{label(session, id)}</span>
            <strong {...stylex.props(styles.strong)}>{comparison.convergenceDepth === null ? ">3°" : `${comparison.convergenceDepth}°`}</strong>
          </div>)}
        </details>
      </>}
      <div {...stylex.props(styles.stat)}><span>Depth-7 physical reuse · A</span><strong {...stylex.props(styles.strong)}>{physicalReuse(session, a)}</strong></div>
      {b === null ? null : <div {...stylex.props(styles.stat)}><span>Depth-7 physical reuse · B</span><strong {...stylex.props(styles.strong)}>{physicalReuse(session, b)}</strong></div>}
    </>}
    <details data-testid="landscape-aggregate" {...stylex.props(styles.details)}>
      <summary {...stylex.props(styles.summary)}>Aggregate landscape · {separated.length} separated · {waves.length} waves</summary>
      <h3 {...stylex.props(styles.subheading)}>Structural convergence graph</h3>
      <div {...stylex.props(styles.stat)}><span>Visible region candidates</span><strong {...stylex.props(styles.strong)}>{index.candidates.length} / {index.eligibleRegions}</strong></div>
      <div {...stylex.props(styles.stat)}><span>Pairs at ≥ τ</span><strong {...stylex.props(styles.strong)}>{graph.edges.toLocaleString()}</strong></div>
      <h3 {...stylex.props(styles.subheading)}>Structural separation decay</h3>
      {decayRows.map((row) => <div key={row.depth} {...stylex.props(styles.decay)}>
        <span>{row.depth}°</span><meter {...stylex.props(styles.bar)} min={0} max={maxDecay} value={row.count ?? 0} />
        <strong>{row.count}</strong>
      </div>)}
      <details {...stylex.props(styles.small)}>
        <summary>Separated region IDs</summary>
        <ol>{separated.map((id) => <li key={id} {...stylex.props(styles.path)}>{label(session, id)} · <code>{id}</code></li>)}</ol>
      </details>
      <details {...stylex.props(styles.small)}>
        <summary>Greedy wave groups</summary>
        <ol>{waves.map((members, wave) => <li key={members.join("|")}>
          Wave {wave + 1} · {members.length} regions
          <ul>{members.map((id) => <li key={id} {...stylex.props(styles.path)}>{label(session, id)} · <code>{id}</code></li>)}</ul>
        </li>)}</ol>
      </details>
      {index.candidates.length < index.eligibleRegions && <span {...stylex.props(styles.small)}>
        Aggregate uses the first {index.candidates.length} visible regions by containment depth and stable ID; selected files and remaining regions are measured individually.
      </span>}
      <span {...stylex.props(styles.small)}>Dashed region outlines meet the selected origin's overlap threshold. Index {index.constructionMs.toFixed(1)} ms · pair matrices {index.pairMetricsMs.toFixed(1)} ms · {index.nodeIds.length.toLocaleString()} visible nodes. Greedy counts are static heuristics, not measured scheduling.</span>
    </details>
  </section>;
}
