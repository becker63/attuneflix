/**
 * The one persistent Cosmograph instance. It is fed by the session's Arrow tables
 * through our own DuckDB connection (table names, precomputed index columns), so
 * the renderer never resolves ids itself and never re-ingests data for an
 * overlay or a relation filter.
 *
 * Emphasis uses the renderer's selection/greyout channel with the sets computed
 * from the projected adjacency: hover, the pinned selection (re-applied whenever
 * the pointer leaves a point), and the active filter and depth all come from
 * Jotai atoms, so clicking a point pins it independently of hover.
 */
import { Cosmograph } from "@cosmograph/react";
import * as stylex from "@stylexjs/stylex";
import { useAtomValue, useSetAtom } from "jotai";
import { useEffect, useRef } from "react";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import {
  clearSelectionAtom,
  drillFamilyEdgeAtom,
  drilledFamilyEdgeAtom,
  emphasisAtom,
  filterRevisionAtom,
  hoveredIndexAtom,
  neighbourhoodDepthAtom,
  overlayAtom,
  overlayRevisionAtom,
  readyAtom,
  relationMaskAtom,
  selectOnlyAtom,
  selectedAtom,
  toggleSelectedAtom,
  visibleRelationSetAtom,
} from "./atoms.ts";
import { publish, setDiagnosticsSource } from "./diagnostics.ts";
import { reapplyEmphasis, setEmphasis } from "./emphasis.ts";
import { familyMembership, familyPointColor } from "./families.ts";
import {
  clearMountedCosmograph,
  mountedCosmograph,
  onBackgroundClick,
  onGraphMount,
  onGraphRebuilt,
  onLinkClick,
  onPointClick,
  onPointMouseOut,
  onPointMouseOver,
  onZoom,
  setGraphHandlers,
  type MountedCosmograph,
} from "./graphHandlers.ts";
import { linkColorAccessor, linkWidthAccessor } from "./linkAccessors.ts";
import { highlightIds } from "./neighbourhood.ts";
import { sortedSelection } from "./selection.ts";
import type { GraphSession } from "./session.ts";
import { pointColorMap } from "./vocabulary.ts";

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
  const setReady = useSetAtom(readyAtom);
  const setSelectedOnly = useSetAtom(selectOnlyAtom);
  const setToggleSelected = useSetAtom(toggleSelectedAtom);
  const clearSelection = useSetAtom(clearSelectionAtom);

  const hovered = useAtomValue(hoveredIndexAtom);
  const emphasis = useAtomValue(emphasisAtom);
  const selected = useAtomValue(selectedAtom);
  const visibleRelations = useAtomValue(visibleRelationSetAtom);
  const depth = useAtomValue(neighbourhoodDepthAtom);
  const filterRevision = useAtomValue(filterRevisionAtom);
  const relationMask = useAtomValue(relationMaskAtom);
  const overlay = useAtomValue(overlayAtom);
  const overlayRevision = useAtomValue(overlayRevisionAtom);
  const drill = useAtomValue(drilledFamilyEdgeAtom);
  const setDrill = useSetAtom(drillFamilyEdgeAtom);

  const families = session.families;
  const familiesOverlay = overlay === "families" && families !== null;
  // The renderer's stable callbacks run outside React; the ref lets the link
  // click handler read the current overlay without re-registering the handlers
  // (which would drop the mounted instance) on every overlay change.
  const familiesOverlayRef = useRef(familiesOverlay);
  useEffect(() => {
    familiesOverlayRef.current = familiesOverlay;
  }, [familiesOverlay]);

  // The renderer's stable callbacks delegate here; the dependency list is only
  // the setters (all stable) and the session. Disposing the session removes
  // these handlers even before React unmounts the component.
  useEffect(() => {
    const rebuilt = (): void => {
      // Fit the camera to the freshly loaded dataset, so a switch never keeps the
      // previous world's zoom and pan.
      const instance = mountedCosmograph();
      instance?.fitView(0);
      setReady(true);
      reapplyEmphasis();
      publish({ ready: true, camera: { zoom: instance?.getZoomLevel() ?? null } });
    };
    const zoom = (): void => {
      publish({ camera: { zoom: mountedCosmograph()?.getZoomLevel() ?? null } });
    };
    setGraphHandlers({
      enter: (index) => setHoveredIndex(index),
      leave: () => setHoveredIndex(null),
      click: (index, additive) => {
        const id = session.pointId(index);
        if (id === null) return;
        if (additive) setToggleSelected(id);
        else setSelectedOnly(id);
      },
      linkClick: (linkIndex) => {
        // A click on a family edge drills into it; exact link rows do nothing.
        if (!familiesOverlayRef.current) return;
        const ordinal = session.familyEdgeAt(linkIndex);
        if (ordinal !== null) setDrill(ordinal);
      },
      background: () => {
        clearSelection();
        setDrill(null);
      },
      rebuilt,
      zoom,
    });
    setDiagnosticsSource({
      screenPositionOf: (index) => screenPositionOf(mountedCosmograph(), index),
      pointWithIncidentLinks: () => session.firstPointWithLinks(RELATION_ORDER),
      pointIdOf: (index) => session.pointId(index),
      pointCount: () => session.pointCount,
      familyOfPoint: (index) =>
        session.families === null ? null : familyMembership(session.families, index),
    });
    const unsubscribe = session.onDispose(() => {
      setGraphHandlers(null);
      setDiagnosticsSource(null);
    });
    return () => {
      unsubscribe();
      setGraphHandlers(null);
      setDiagnosticsSource(null);
      clearMountedCosmograph();
    };
  }, [session, setHoveredIndex, setReady, setSelectedOnly, setToggleSelected, clearSelection, setDrill]);

  // The documented clear action on the keyboard (the canvas is not focusable).
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent): void => {
      if (event.key === "Escape") {
        clearSelection();
        setDrill(null);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [clearSelection, setDrill]);

  useEffect(() => {
    setEmphasis(emphasis);
  }, [emphasis]);

  useEffect(() => {
    publish({
      hovered: hovered === null ? null : session.pointId(hovered),
      hoveredIndex: hovered,
      highlighted: { points: highlightIds(session.graph, emphasis), links: [...emphasis.links] },
      selected: sortedSelection(selected),
      relationFilter: [...visibleRelations],
      depth,
      filterRevision,
      overlay: { name: overlay, revision: overlayRevision },
      drilledFamilyEdge: drill,
    });
  }, [
    session,
    hovered,
    emphasis,
    selected,
    visibleRelations,
    depth,
    filterRevision,
    overlay,
    overlayRevision,
    drill,
  ]);

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
      pointColorStrategy={familiesOverlay ? "direct" : "map"}
      pointColorByMap={POINT_COLORS}
      pointColorByFn={familiesOverlay ? familyPointColor(families) : undefined}
      pointDefaultSize={12}
      pointGreyoutOpacity={0.08}
      linkGreyoutOpacity={0.02}
      linkColorBy="relation"
      linkColorByFn={linkColorAccessor({
        mask: relationMask,
        renderLinks: session.renderLinks,
        overlay,
        families,
        exactLinkCount: session.graph.linkCount,
        drill,
      })}
      linkWidthBy="relation"
      linkWidthByFn={linkWidthAccessor({
        mask: relationMask,
        renderLinks: session.renderLinks,
        overlay,
        families,
        exactLinkCount: session.graph.linkCount,
        drill,
      })}
      onMount={onGraphMount}
      onPointMouseOver={onPointMouseOver}
      onPointMouseOut={onPointMouseOut}
      onPointClick={onPointClick}
      onLinkClick={onLinkClick}
      selectLinkOnClick={false}
      onBackgroundClick={onBackgroundClick}
      onGraphRebuilt={onGraphRebuilt}
      onZoom={onZoom}
    />
  );
}
