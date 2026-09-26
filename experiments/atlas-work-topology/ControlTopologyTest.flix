/// Provenance and protocol tests for the control work-topology instrument
/// (PREREGISTRATION.md §4, §5, §6, §8).
///
/// The reported cuts, cell cut, blast radii and co-change weights must be
/// produced by the frozen protocols over ACTUAL admitted worlds: these tests
/// fail if a cut is replaced by a lexical grouping, if the ATLAS quantities stop
/// depending on the admitted relations and the frozen Atlas family, or if the
/// three co-change weight models are collapsed into one column.
mod ControlTopologyTest {
    use Repository.Grit.Fact

    // ---- Tiny synthesized worlds, through ordinary Repository.admit ----

    def source(path: String): Repository.Source = {path = path, content = ""}

    def fact(kind: String, path: String, start: Int32, end: Int32, value: String): Fact =
        {kind = kind, path = path, startByte = start, endByte = end, value = value}

    def definition(path: String, name: String): Fact = fact("definition", path, 0, 1, name)

    def importFact(path: String, target: String): Fact = fact("import", path, 2, 3, target)

    def worldOf(paths: Vector[String], imports: Vector[Fact]): Repository.World =
        Repository.admit(
            Vector.map(source, paths),
            Vector.mapWithIndex((index, path) -> definition(path, "D${index}"), paths),
            imports,
            Vector.empty())
            |> Result.mapErr(error -> ToString.toString(error))
            |> Experiment.require

    /// Four files in four distinct regions; `a`<->`b` is a two-edge clique and
    /// `c`->`d` is a single edge.
    def fourRegionWorld(): Repository.World =
        worldOf(
            Vector#{"src/Atlas.flix", "src/Radii.flix", "src/Repository.flix", "test/T.flix"},
            Vector#{
                importFact("src/Atlas.flix", "Radii"),
                importFact("src/Radii.flix", "Atlas"),
                importFact("src/Repository.flix", "T")
            })

    // ---- §4 region / §5 cell separation ----

    @Test
    def regionsAndCellsAreReportedSeparately(): Unit \ Assert = {
        Assert.assertEq(expected = "repository", ControlMap.regionOf("src/Repository/Physical.flix"));
        Assert.assertEq(expected = "engine", ControlMap.cellOf("src/Repository/Physical.flix"));
        Assert.assertEq(expected = "tables", ControlMap.regionOf("src/ScientificTable.flix"));
        Assert.assertEq(expected = "kernel", ControlMap.cellOf("src/ScientificTable.flix"));
        Assert.assertEq(expected = "other", ControlMap.regionOf("build/attune.bzl"));
        Assert.assertEq(expected = "law", ControlMap.cellOf("build/attune.bzl"))
    }

    // ---- T4: the frozen greedy agglomerative cut ----

    @Test
    def theGreedyCutFollowsTheFrozenMergeRule(): Unit \ Assert = {
        let world = fourRegionWorld();
        Assert.assertEq(expected = 3, ControlTopology.crossEdges(world, 4));
        Assert.assertEq(expected = 1, ControlTopology.crossEdges(world, 3));
        Assert.assertEq(expected = 0, ControlTopology.crossEdges(world, 2));
        Assert.assertEq(expected = Some("atlas"), ControlTopology.groupOf(ControlTopology.regionGroups(world, 3), "radii"));
        Assert.assertEq(expected = Some("repository"),
            ControlTopology.groupOf(ControlTopology.regionGroups(world, 2), "tests"))
    }

    @Test
    def cutCountsAreNonDecreasingInK(): Unit \ Assert = {
        let cuts = ControlTopology.cutCounts(fourRegionWorld());
        let counts = Vector.map(match (_, cross) -> cross, cuts);
        Assert.assertEq(expected = 9, Vector.length(cuts));
        Assert.assertTrue(Vector.forAll(match (index, value) ->
            index == 0 or Vector.get(index - 1, counts) <= value,
            Vector.mapWithIndex((index, value) -> (index, value), counts)))
    }

    /// §4: an edge whose source or target is `other`-homed crosses at every `k`.
    @Test
    def anOtherHomedEdgeCrossesAtEveryK(): Unit \ Assert = {
        let world = worldOf(Vector#{"Root.flix", "src/Atlas.flix"}, Vector#{importFact("Root.flix", "Atlas")});
        Assert.assertEq(expected = "other", ControlMap.regionOf("Root.flix"));
        Assert.assertEq(expected = 1, Vector.length(ControlTopology.regionFiles(world, "other")));
        Assert.assertEq(expected = 1, ControlTopology.crossEdges(world, 2));
        Assert.assertEq(expected = 1, ControlTopology.crossEdges(world, 10))
    }

    // ---- T5: the K4 ownership-cell cut ----

    @Test
    def theCellCutExcludesKernelLawAndOtherEdges(): Unit \ Assert = {
        let world = worldOf(
            Vector#{"src/Atlas.flix", "src/Radii.flix", "src/Repository.flix", "test/T.flix", "src/ScientificTable.flix"},
            Vector#{
                importFact("src/Repository.flix", "Atlas"),
                importFact("src/Atlas.flix", "Radii"),
                importFact("test/T.flix", "Repository"),
                importFact("src/ScientificTable.flix", "Repository")
            });
        let cut = ControlTopology.cellCut(ControlTopology.cellEdges(world));
        Assert.assertEq(expected = 1, cut#shared);
        Assert.assertEq(expected = 2, cut#considered);
        Assert.assertEq(expected = 0.5, cut#fraction);
        Assert.assertEq(expected = 1, cut#lawEdges);
        Assert.assertEq(expected = 1, cut#kernelEdges);
        Assert.assertEq(expected = 0, cut#otherEdges)
    }

    // ---- T9/T10: ATLAS quantities come from the admitted world ----

    @Test
    def blastRadiusComesFromAtlasOverTheAdmittedRelations(): Unit \ Assert = {
        let paths = Vector#{"src/Atlas.flix", "src/Radii.flix", "src/Repository.flix", "test/T.flix"};
        let isolated = worldOf(paths, Vector.empty());
        let linked = worldOf(paths, Vector#{importFact("test/T.flix", "Repository")});
        let repository = Repository.Structure.FileId.FileId(2);
        Assert.assertEq(expected = 12, Vector.length(ControlTopology.family()));
        Assert.assertTrue(ControlTopology.blast(linked, repository) > ControlTopology.blast(isolated, repository));
        Assert.assertTrue(ControlTopology.blast(linked, repository) > 0)
    }

    // ---- T10 percentile rule ----

    @Test
    def percentileUsesTheNearestRankRule(): Unit \ Assert = {
        let sample = Vector#{1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
        Assert.assertEq(expected = 6, ControlTopology.percentile(sample, 50));
        Assert.assertEq(expected = 10, ControlTopology.percentile(sample, 90))
    }

    // ---- §8: the three co-change weight models ----

    @Test
    def coChangeWeightsAreReportedAsThreeDistinctModels(): Unit \ Assert = {
        let history = ControlCoChange.parseHistory(
            "C\tdeadbeef\n10\t0\ta.flix\n5\t5\tb.flix\n20\t0\tc.flix\nC\tcafebabe\n3\t1\ta.flix\n");
        let admitted = Set#{"a.flix", "b.flix", "c.flix"};
        let entries = Map.toVector(ControlCoChange.graph(history, admitted));
        Assert.assertEq(expected = 2, Vector.length(history));
        Assert.assertEq(expected = 2, ControlCoChange.commitsTouchingAdmitted(history, admitted));
        Assert.assertEq(expected = 3, Vector.length(entries));
        Assert.assertEq(expected = 3, ControlCoChange.totalRaw(entries));
        Assert.assertEq(expected = 30, ControlCoChange.totalLineWeighted(entries));
        Assert.assertTrue(ControlCoChange.totalNormalized(entries) > 0.99);
        Assert.assertTrue(ControlCoChange.totalNormalized(entries) < 1.01);
        Assert.assertEq(expected = 3, ControlCoChange.regionInternalRaw(entries, "other"))
    }

    /// A single-file commit contributes no pair; a two-file commit contributes
    /// exactly one raw unit and `1 / C(2, 2) = 1` normalized unit.
    @Test
    def commitMassIsNormalizedByPairCount(): Unit \ Assert = {
        let two = ControlCoChange.parseHistory("C\tone\n7\t1\ta.flix\n2\t3\tb.flix\n");
        let admitted = Set#{"a.flix", "b.flix"};
        let entries = Map.toVector(ControlCoChange.graph(two, admitted));
        Assert.assertEq(expected = 1, ControlCoChange.totalRaw(entries));
        Assert.assertEq(expected = 1.0, ControlCoChange.totalNormalized(entries));
        // changed_lines(a) = 7 + 1 = 8, changed_lines(b) = 2 + 3 = 5, so the
        // line-weighted model adds min(8, 5) = 5.
        Assert.assertEq(expected = 5, ControlCoChange.totalLineWeighted(entries))
    }
}
