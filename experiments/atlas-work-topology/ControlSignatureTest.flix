/// Provenance and protocol tests for the control signature instrument
/// (PREREGISTRATION.md §3, §4, §5, §9, §14).
///
/// The reported depth-response curve must be produced by ACTUAL Atlas
/// evaluation over the admitted world: these tests fail if a landmark is
/// replaced by a seed echo, a handwritten traversal, or a stub that ignores an
/// admitted relation or the frozen program family. They also pin the region,
/// cell, surface and declared-identity protocols on representative paths.
mod ControlSignatureTest {
    use Repository.Grit.Fact

    // ---- Tiny synthesized worlds, through ordinary Repository.admit ----

    def source(path: String): Repository.Source = {path = path, content = ""}

    def fact(kind: String, path: String, start: Int32, end: Int32, value: String): Fact =
        {kind = kind, path = path, startByte = start, endByte = end, value = value}

    /// Two files, each with one definition; `imports` is the only admitted edge
    /// the caller varies.
    def twoFileWorld(imports: Vector[Fact]): Repository.World =
        Repository.admit(
            Vector#{source("a.flix"), source("b.flix")},
            Vector#{fact("definition", "a.flix", 0, 5, "Alpha"), fact("definition", "b.flix", 0, 4, "Beta")},
            imports, Vector.empty())
            |> Result.mapErr(error -> ToString.toString(error))
            |> Experiment.require

    /// An isolated pair (no edge) and a linked pair (`a` imports `b`).
    def isolated(): Repository.World = twoFileWorld(Vector.empty())

    def linked(): Repository.World =
        twoFileWorld(Vector#{fact("import", "a.flix", 12, 13, "b")})

    // ---- Provenance: the response curve comes from Atlas ----

    @Test
    def depthResponseChangesWhenAnAdmittedRelationChanges(): Unit \ Assert = {
        let seed = Atlas.State.Files(Set#{Repository.Structure.FileId.FileId(0)});
        let isolatedCards = Vector.map(observation -> (observation#depth, observation#outputCardinality),
            Experiment.require(Atlas.Signature.compute(isolated(), seed, 1))#observations);
        let linkedCards = Vector.map(observation -> (observation#depth, observation#outputCardinality),
            Experiment.require(Atlas.Signature.compute(linked(), seed, 1))#observations);
        Assert.assertTrue(isolatedCards != linkedCards)
    }

    @Test
    def depthResponseChangesWhenTheFamilyChanges(): Unit \ Assert = {
        let world = linked();
        let seed = Atlas.State.Files(Set#{Repository.Structure.FileId.FileId(0)});
        let depthOne = Experiment.require(Atlas.Signature.compute(world, seed, 1));
        let depthTwo = Experiment.require(Atlas.Signature.compute(world, seed, 2));
        Assert.assertEq(expected = 3, depthOne#logicalPrograms);
        Assert.assertEq(expected = 12, depthTwo#logicalPrograms)
    }

    @Test
    def frozenGrammarAdmitsExactlySixDirectedAtomsThroughDepthSeven(): Unit \ Assert = {
        Assert.assertEq(expected = 3279, Vector.length(Atlas.programsFrom(Radii.Domain.File, 7)));
        Assert.assertEq(expected = 3279, Vector.length(Atlas.programsFrom(Radii.Domain.Symbol, 7)))
    }

    // ---- Mixing landmarks ----

    @Test
    def landmarksAreMonotoneAndBoundedOnASyntheticWorld(): Unit \ {Assert, IO} = {
        let world = linked();
        let landmarks = ControlSignature.landmarks(world, ControlSignature.signatures(world));
        let coverage = landmarks#meanCoverage;
        Assert.assertEq(expected = 7, Vector.length(coverage));
        Assert.assertTrue(Vector.forAll(depth ->
            Vector.get(depth - 1, coverage) <= Vector.get(depth, coverage), Vector.range(1, 7)));
        Assert.assertEq(expected = Vector.get(6, coverage), landmarks#depth7Reach);
        Assert.assertTrue(landmarks#d50 >= 1 and landmarks#d50 <= 8);
        Assert.assertTrue(landmarks#d50 <= landmarks#d80 and landmarks#d80 <= landmarks#d90
            and landmarks#d90 <= landmarks#d95)
    }

    @Test
    def aFullyConnectedPairReachesAllFilesAtDepthOne(): Unit \ {Assert, IO} = {
        let landmarks = ControlSignature.landmarks(linked(), ControlSignature.signatures(linked()));
        Assert.assertEq(expected = 1.0, Vector.get(0, landmarks#meanCoverage));
        Assert.assertEq(expected = 1, landmarks#d50);
        Assert.assertEq(expected = 1, landmarks#d95);
        Assert.assertEq(expected = 1.0, landmarks#depth7Reach)
    }

    // ---- Region and cell partitions (§4, §5) ----

    @Test
    def regionAndCellPartitionsFollowTheFrozenRules(): Unit \ Assert = {
        Assert.assertEq(expected = "atlas", ControlMap.regionOf("src/Atlas/Signature.flix"));
        Assert.assertEq(expected = "engine", ControlMap.cellOf("src/Atlas/Signature.flix"));
        Assert.assertEq(expected = "repository", ControlMap.regionOf("src/Repository/Structure.flix"));
        Assert.assertEq(expected = "world", ControlMap.cellOf("src/Repository/Structure.flix"));
        Assert.assertEq(expected = "engine", ControlMap.cellOf("src/Repository/Physical.flix"));
        Assert.assertEq(expected = "kernel", ControlMap.cellOf("src/ScientificTable/Columns.flix"));
        Assert.assertEq(expected = "tables", ControlMap.regionOf("src/ScientificTable/Columns.flix"));
        Assert.assertEq(expected = "src-root", ControlMap.regionOf("src/native/grit/AttuneGrit.java"));
        Assert.assertEq(expected = "world", ControlMap.cellOf("src/native/grit/AttuneGrit.java"));
        Assert.assertEq(expected = "tests", ControlMap.regionOf("test/ParityTest.flix"));
        Assert.assertEq(expected = "law", ControlMap.cellOf("test/ParityTest.flix"));
        Assert.assertEq(expected = "other", ControlMap.regionOf("build/BUILD.bazel"));
        Assert.assertEq(expected = "law", ControlMap.cellOf("build/BUILD.bazel"));
        Assert.assertEq(expected = "experiments", ControlMap.regionOf("experiments/atlas-parallelism/Main.flix"));
        Assert.assertEq(expected = "research", ControlMap.cellOf("experiments/atlas-parallelism/Main.flix"))
    }

    // ---- Declared identity (§9) ----

    @Test
    def declaredIdentityUsesTheDeclaredModuleWhenPresent(): Unit \ Assert = {
        Assert.assertEq(expected = "Atlas.Signature", ControlMap.declaredIdentity("src/Atlas/Signature.flix",
            "flix", Vector#{("Atlas.Signature", 0, 100), ("routeId", 10, 20)}));
        // A module declared below a top-level `def main` is still the unique
        // maximal enclosing declaration.
        Assert.assertEq(expected = "CensusMain", ControlMap.declaredIdentity("experiments/atlas-swe-explore/Main.flix",
            "flix", Vector#{("main", 0, 40), ("CensusMain", 45, 300), ("execute", 60, 80)}))
    }

    @Test
    def declaredIdentityFallsBackToTheBasenameWithoutAModule(): Unit \ Assert = {
        Assert.assertEq(expected = "Main", ControlMap.declaredIdentity("experiments/atlas-parallelism/Main.flix",
            "flix", Vector#{("main", 0, 40)}));
        Assert.assertEq(expected = "Aggregate", ControlMap.declaredIdentity("experiments/atlas-swe-explore/Aggregate.flix",
            "flix", Vector#{("main", 0, 40), ("load", 50, 90)}))
    }

    @Test
    def declaredIdentityIsLanguageAware(): Unit \ Assert = {
        Assert.assertEq(expected = "attune.grit.AttuneGrit", ControlMap.declaredIdentity("src/native/grit/AttuneGrit.java",
            "java", Vector.empty()));
        Assert.assertEq(expected = "build/attune.bzl", ControlMap.declaredIdentity("build/attune.bzl",
            "starlark", Vector.empty()));
        Assert.assertEq(expected = "root/BUILD.bazel", ControlMap.declaredIdentity("BUILD.bazel",
            "starlark", Vector.empty()));
        Assert.assertEq(expected = "defines/flix", ControlMap.declaredIdentity("src/grit/defines/flix.grit",
            "grit", Vector.empty()))
    }

    /// Identity survives a move (no path bytes) yet keeps two files that declare
    /// the same module name distinct when their surface class differs.
    @Test
    def logicalIdentityDependsOnLanguageIdentityAndSurfaceNotPath(): Unit \ {Assert, IO} = {
        let production = ControlIdentity.entry(
            {path = "src/Repository.flix", sha256 = "", bytes = 0, language = "flix"},
            Vector#{("Repository", 0, 15)});
        let moved = ControlIdentity.entry(
            {path = "src/engine/Repository.flix", sha256 = "", bytes = 0, language = "flix"},
            Vector#{("Repository", 0, 15)});
        let law = ControlIdentity.entry(
            {path = "build/src/Repository.flix", sha256 = "", bytes = 0, language = "flix"},
            Vector#{("Repository", 0, 15)});
        Assert.assertEq(expected = production#logicalId, moved#logicalId);
        Assert.assertTrue(production#logicalId != law#logicalId)
    }
}
