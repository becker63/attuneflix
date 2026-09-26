/// Protocol and provenance law tests for the Round 1 candidate measurement
/// (PREREGISTRATION.md §4, §5, §9, §10, §11).
///
/// These fail if the §5 amendment leaks into the frozen control partition, if
/// the identity classification collapses a move into a new identity (or the
/// reverse), or if the round cut/cell cut stop being a function of the actual
/// admitted world translated on the logical-identity layer.
mod RoundTest {
    use AcquisitionFacts.Source

    // ---- the §5 amendment must not move the control protocol ----

    @Test
    def theRoundCellPartitionHomesLawSurfacesWithoutTouchingControl(): Unit \ Assert = {
        Assert.assertEq(expected = "world", ControlMap.roundCellOf("test/World/Repository.flix"));
        Assert.assertEq(expected = "engine", ControlMap.roundCellOf("test/Engine/ParityTest.flix"));
        Assert.assertEq(expected = "applications", ControlMap.roundCellOf("test/Applications/LocalizationTest.flix"));
        Assert.assertEq(expected = "kernel", ControlMap.roundCellOf("test/Kernel/IdentityTest.flix"));
        Assert.assertEq(expected = "law", ControlMap.roundCellOf("test/BUILD.bazel"));
        Assert.assertEq(expected = "law", ControlMap.roundCellOf("build/src/Repository.flix"));
        Assert.assertEq(expected = "engine", ControlMap.roundCellOf("src/Atlas.flix"));
        // The frozen control protocol still homes every `test/` path as `law`.
        Assert.assertEq(expected = "law", ControlMap.cellOf("test/World/Repository.flix"));
        Assert.assertEq(expected = "tests", ControlMap.regionOf("test/World/Repository.flix"))
    }

    // ---- §9 identity classification ----

    def frozenSource(path: String, hash: String): Source =
        {path = path, sha256 = hash, bytes = 4, language = "flix"}

    @Test
    def identityClassificationSeparatesStableModifiedMovedDroppedAndNew(): Unit \ {Assert, IO} = {
        let controlSources = Vector#{
            frozenSource("build/src/A.flix", "h-a"),
            frozenSource("build/src/B.flix", "h-b"),
            frozenSource("src/Keep.flix", "h-keep"),
            frozenSource("test/BUILD.bazel", "h-build")
        };
        let roundPaths = Vector#{
            "src/Keep.flix", "test/BUILD.bazel", "test/World/A.flix", "test/World/BUILD.bazel"
        };
        let roundHashes = Map#{
            "src/Keep.flix" => "h-keep",
            "test/BUILD.bazel" => "h-build-changed",
            "test/World/A.flix" => "h-a",
            "test/World/BUILD.bazel" => "h-new"
        };
        let round0 = RoundIdentity.round(controlSources, Vector.empty(), roundPaths, roundHashes);
        Assert.assertEq(expected = 1, countOf(round0, "stable"));
        Assert.assertEq(expected = 1, countOf(round0, "modified"));
        Assert.assertEq(expected = 1, countOf(round0, "moved"));
        Assert.assertEq(expected = 1, countOf(round0, "dropped"));
        Assert.assertEq(expected = 1, Vector.length(round0#newPaths));
        Assert.assertTrue(Vector.isEmpty(round0#collisions));
        // The moved identity keeps its logical id and gains the candidate path.
        Assert.assertEq(expected = 1, Vector.length(Vector.filterMap(entry ->
            if (entry#movement == "moved" and entry#currentPath == "test/World/A.flix") Some(()) else None,
            round0#entries)));
        Assert.assertEq(expected = "world", movedCell(round0));
        Assert.assertEq(expected = "law", movedControlCell(round0))
    }

    def countOf(round0: RoundIdentity.Round, movement: String): Int32 =
        Vector.count(entry -> entry#movement == movement, round0#entries)

    def movedCell(round0: RoundIdentity.Round): String =
        Vector.foldLeft((found, entry) ->
            if (entry#movement == "moved") entry#ownershipCell else found, "", round0#entries)

    def movedControlCell(round0: RoundIdentity.Round): String =
        Vector.foldLeft((found, entry) ->
            if (entry#movement == "moved") entry#controlCell else found, "", round0#entries)

    // ---- the frozen control basis re-expressed at candidate paths ----

    def source0(path: String): Repository.Source = {path = path, content = ""}

    def definition(path: String, name: String): Repository.Grit.Fact =
        {kind = "definition", path = path, startByte = 0, endByte = 1, value = name}

    def importFact(path: String, target: String): Repository.Grit.Fact =
        {kind = "import", path = path, startByte = 1, endByte = 2, value = target}

    def worldOf(paths: Vector[String], imports: Vector[Repository.Grit.Fact]): Repository.World =
        Repository.admit(
            Vector.map(source0, paths),
            Vector.mapWithIndex((index, path) -> definition(path, "D${index}"), paths),
            imports,
            Vector.empty())
            |> Result.mapErr(error -> ToString.toString(error))
            |> Experiment.require

    /// `src/Atlas.flix` is the engine cell; the law file `build/src/A.flix`
    /// imports it. At control the edge is law-excluded; moved into
    /// `test/World/` it becomes a considered world->engine edge.
    def twoFileWorld(): Repository.World =
        worldOf(Vector#{"build/src/A.flix", "src/Atlas.flix"},
            Vector#{importFact("build/src/A.flix", "Atlas")})

    @Test
    def theAmendedCellCutCountsTheRehomedLawEdges(): Unit \ Assert = {
        let world = twoFileWorld();
        let controlCut = ControlTopology.cellCut(ControlTopology.cellEdges(world));
        let roundCut = RoundTopology.cellCut(world, Map#{"build/src/A.flix" => "test/World/A.flix"});
        Assert.assertEq(expected = 0, controlCut#considered);
        Assert.assertEq(expected = 1, roundCut#considered);
        Assert.assertEq(expected = 1, roundCut#shared);
        Assert.assertTrue(Set.size(world#imports) == 1)
    }

    @Test
    def aPureMoveReHomesTheLawFileAndDropsTheEmptyRegion(): Unit \ Assert = {
        let world = twoFileWorld();
        let mapping = Map#{"build/src/A.flix" => "test/World/A.flix"};
        Assert.assertEq(expected = "build-src", ControlMap.regionOf("build/src/A.flix"));
        Assert.assertTrue(Vector.isEmpty(RoundTopology.regionFiles(world, mapping, "build-src")));
        Assert.assertEq(expected = Vector#{"test/World/A.flix"}, RoundTopology.regionFiles(world, mapping, "tests"));
        Assert.assertEq(expected = "tests", ControlMap.regionOf("test/World/A.flix"))
    }

    @Test
    def theCandidateBasisIsTheSameGraphAtCandidatePaths(): Unit \ {Assert, IO} = {
        let (sources, facts) = twoFileAcquisition();
        let round0 = RoundIdentity.round(sources, facts,
            Vector#{"src/Atlas.flix", "test/World/A.flix"},
            Map#{"src/Atlas.flix" => "h-atlas", "test/World/A.flix" => "h-a"});
        let candidate = RoundOracle.candidateWorld(round0, sources, facts);
        Assert.assertEq(expected = 2, Vector.length(candidate#files));
        Assert.assertEq(expected = Vector#{"src/Atlas.flix", "test/World/A.flix"}, candidate#files);
        Assert.assertEq(expected = 1, Set.size(candidate#imports));
        Assert.assertEq(expected = 2, Set.size(candidate#defines))
    }

    /// The seed panel is part of the frozen protocol, so a file move must carry
    /// the same logical seeds into the candidate world instead of re-hashing
    /// candidate paths (which would perturb the comparison — §6.2, §9).
    @Test
    def theSeedPanelIsCarriedOnLogicalIdentityNotPaths(): Unit \ {Assert, IO} = {
        let (sources, facts) = twoFileAcquisition();
        let world = Experiment.require(AcquisitionFacts.world(sources, facts));
        let round0 = RoundIdentity.round(sources, facts,
            Vector#{"src/Atlas.flix", "test/World/A.flix"},
            Map#{"src/Atlas.flix" => "h-atlas", "test/World/A.flix" => "h-a"});
        let candidate = RoundOracle.candidateWorld(round0, sources, facts);
        let seeds = RoundOracle.translatedSeeds(world, candidate, RoundIdentity.mapping(round0));
        Assert.assertEq(expected = Vector.length(Atlas.Signature.seeds(world)),
            Vector.length(seeds));
        // Control's `build/src/A.flix` file seed becomes candidate's
        // `test/World/A.flix`, which sorts second: [src/Atlas.flix, test/World/A.flix].
        Assert.assertTrue(Vector.exists(seed ->
            seed#state == Atlas.State.Files(Set#{Repository.Structure.FileId.FileId(1)}), seeds))
    }

    def twoFileAcquisition(): (Vector[Source], Vector[AcquisitionFacts.FactRow]) = (
        Vector#{
            frozenSource("build/src/A.flix", "h-a"),
            frozenSource("src/Atlas.flix", "h-atlas")
        },
        Vector#{
            {path = "build/src/A.flix", sourceSha256 = "h-a", language = "flix", program = "defines",
             kind = "definition", startByte = 0, endByte = 1, value = "D0"},
            {path = "build/src/A.flix", sourceSha256 = "h-a", language = "flix", program = "imports",
             kind = "import", startByte = 1, endByte = 2, value = "Atlas"},
            {path = "src/Atlas.flix", sourceSha256 = "h-atlas", language = "flix", program = "defines",
             kind = "definition", startByte = 0, endByte = 1, value = "D1"}
        })

    /// §6.2: an import fact resolves against the admitted *paths* (Flix module
    /// candidates are matched by path suffix), so a move can change which
    /// declaration the same frozen fact reaches. The instrument must report
    /// that as an explicit basis-edge drift, never absorb it silently.
    @Test
    def theBasisEdgeDriftIsReportedNotHidden(): Unit \ {Assert, IO} = {
        let sources = Vector#{
            frozenSource("build/src/A.flix", "h-a"),
            frozenSource("src/A.flix", "h-a2"),
            frozenSource("src/Atlas.flix", "h-atlas")
        };
        let facts = Vector#{
            {path = "build/src/A.flix", sourceSha256 = "h-a", language = "flix", program = "defines",
             kind = "definition", startByte = 0, endByte = 1, value = "A"},
            {path = "build/src/A.flix", sourceSha256 = "h-a", language = "flix", program = "imports",
             kind = "import", startByte = 1, endByte = 2, value = "A"},
            {path = "src/A.flix", sourceSha256 = "h-a2", language = "flix", program = "defines",
             kind = "definition", startByte = 0, endByte = 1, value = "A"},
            {path = "src/Atlas.flix", sourceSha256 = "h-atlas", language = "flix", program = "defines",
             kind = "definition", startByte = 0, endByte = 1, value = "Atlas"}
        };
        let world = Experiment.require(AcquisitionFacts.world(sources, facts));
        // At control `A` matches two paths, so the import is rejected.
        Assert.assertEq(expected = 0, Set.size(world#imports));
        let round0 = RoundIdentity.round(sources, facts,
            Vector#{"src/A.flix", "src/Atlas.flix", "test/World/Zed.flix"},
            Map#{"src/A.flix" => "h-a2", "src/Atlas.flix" => "h-atlas", "test/World/Zed.flix" => "h-a"});
        let candidate = RoundOracle.candidateWorld(round0, sources, facts);
        // After the move only `src/A.flix` matches, so the same fact resolves.
        Assert.assertEq(expected = 1, Set.size(candidate#imports));
        let translated = RoundOracle.translatedEdgePaths(world, RoundIdentity.mapping(round0));
        let (lost, gained) = RoundOracle.basisEdgeDrift(candidate, translated);
        Assert.assertTrue(Vector.isEmpty(lost));
        Assert.assertEq(expected = Vector#{("test/World/Zed.flix", "src/A.flix")}, gained)
    }

    /// T8 is applied to candidate region names through the frozen test-side
    /// rule: the emptied `build-src` region leaves the candidate's partition.
    @Test
    def theCandidateIndependentlyTestableRegionsUseTheFrozenTestSideRule(): Unit \ Assert = {
        let world = twoFileWorld();
        Assert.assertEq(expected = Vector#{"atlas", "build-src"},
            RoundTopology.independentlyTestableRegions(world, Map.empty()));
        Assert.assertEq(expected = Vector#{"atlas", "tests"},
            RoundTopology.independentlyTestableRegions(world, Map#{"build/src/A.flix" => "test/World/A.flix"}))
    }

    @Test
    def theFrozenGrammarIsInvariant(): Unit \ Assert = {        Assert.assertEq(expected = 3279, Vector.length(Atlas.programsFrom(Radii.Domain.File, 7)));
        Assert.assertEq(expected = 3279, Vector.length(Atlas.programsFrom(Radii.Domain.Symbol, 7)));
        Assert.assertEq(expected = 7, Vector.length(RoundOracle.grammarDepths()))
    }
}
