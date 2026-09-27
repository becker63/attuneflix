/**
 * The one persistent Cosmograph instance. It is fed by the session's Arrow tables
 * through our own DuckDB connection (table names, precomputed index columns), so
 * the renderer never resolves ids itself and never re-ingests data for an
 * overlay. Hover uses the selection channel (greyout); selection-on-click is
 * disabled and driven by the app once selection ships.
 */
import { Cosmograph } from "@cosmograph/react";
import * as stylex from "@stylexjs/stylex";
import { useSetAtom } from "jotai";
import { useEffect } from "react";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import { highlightedAtom, hoveredIndexAtom, readyAtom } from "./atoms.ts";
import { publish, setDiagnosticsSource } from "./diagnostics.ts";
import {
  clearMountedCosmograph,
  mountedCosmograph,
  onGraphMount,
  onGraphRebuilt,
  onPointMouseOut,
  onPointMouseOver,
  onZoom,
  setGraphHandlers,
  type MountedCosmograph,
} from "./graphHandlers.ts";
import { EMPTY_HIGHLIGHT, highlightIds } from "./neighbourhood.ts";
import type { GraphSession } from "./session.ts";
import { pointColorMap, relationColor } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    width: "100%",
    height: "100%",
  },
});

const POINT_COLORS = pointColorMap();
const BACKGROUND = "#0b0d12";

function screenPositionOf(instance: MountedCosmograph | undefined, index: number): [number, number] | null {
  if (instance === undefined) return null;
  const space = instance.getPointPositionByIndex(index);
  if (space === undefined) return null;
  const screen = instance.spaceToScreenPosition(space);
  if (screen === undefined) return null;
  const canvas = instance.getCanvas();
  if (canvas === null) return null;
  const rect = canvas.getBoundingClientRect();
  return [rect.left + screen[0], rect.top + screen[1]];
}

export function GraphView({ session }: { session: GraphSession }) {
  const setHoveredIndex = useSetAtom(hoveredIndexAtom);
  const setHighlighted = useSetAtom(highlightedAtom);
  const setReady = useSetAtom(readyAtom);

  useEffect(() => {
    const enter = (index: number): void => {
      const highlight = session.highlight(index, RELATION_ORDER);
      setHoveredIndex(index);
      setHighlighted(highlight);
      publish({
        hovered: session.pointId(index),
        hoveredIndex: index,
        highlighted: { points: highlightIds(session.graph, highlight), links: highlight.links },
      });
      mountedCosmograph()?.selectPoint(index, false, true);
    };
    const leave = (): void => {
      setHoveredIndex(null);
      setHighlighted(EMPTY_HIGHLIGHT);
      publish({ hovered: null, hoveredIndex: null, highlighted: { points: [], links: [] } });
      mountedCosmograph()?.unselectAllPoints();
    };
    const rebuilt = (): void => {
      setReady(true);
      publish({ ready: true, camera: { zoom: mountedCosmograph()?.getZoomLevel() ?? null } });
    };
    const zoom = (): void => {
      publish({ camera: { zoom: mountedCosmograph()?.getZoomLevel() ?? null } });
    };
    setGraphHandlers({ enter, leave, rebuilt, zoom });
    setDiagnosticsSource({
      screenPositionOf: (index) => screenPositionOf(mountedCosmograph(), index),
      pointWithIncidentLinks: () => session.firstPointWithLinks(RELATION_ORDER),
    });
    return () => {
      setGraphHandlers(null);
      setDiagnosticsSource(null);
      clearMountedCosmograph();
    };
  }, [session, setHoveredIndex, setHighlighted, setReady]);

  return (
    <Cosmograph
      {...stylex.props(styles.root)}
      duckDBConnection={session.duckdb}
      points={session.pointsTable}
      links={session.linksTable}
      pointIdBy="id"
      pointIndexBy="index"
      pointXBy="x"
      pointYBy="y"
      linkSourceBy="source"
      linkTargetBy="target"
      linkSourceIndexBy="sourceIndex"
      linkTargetIndexBy="targetIndex"
      backgroundColor={BACKGROUND}
      enableSimulation={false}
      fitViewOnInit
      transitionDuration={0}
      selectPointOnClick={false}
      focusPointOnClick={false}
      resetSelectionOnEmptyCanvasClick={false}
      showLabels={false}
      showDynamicLabels={false}
      showTopLabels={false}
      showHoveredPointLabel={false}
      statusIndicatorMode={false}
      pointColorBy="domain"
      pointColorStrategy="map"
      pointColorByMap={POINT_COLORS}
      pointDefaultSize={12}
      pointGreyoutOpacity={0.08}
      linkGreyoutOpacity={0.02}
      linkColorBy="relation"
      linkColorByFn={relationColor}
      onMount={onGraphMount}
      onPointMouseOver={onPointMouseOver}
      onPointMouseOut={onPointMouseOut}
      onGraphRebuilt={onGraphRebuilt}
      onZoom={onZoom}
    />
  );
}
