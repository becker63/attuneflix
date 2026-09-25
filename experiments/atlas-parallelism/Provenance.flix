/// Provenance fixture for the v2 parallelism measurement: the reported file
/// neighborhoods must be produced by ACTUAL Atlas evaluation over the admitted
/// world. These tests fail if the expansion is replaced by a seed echo, by a
/// handwritten traversal that ignores the evaluator, or by a stub that ignores
/// the admitted relations or the program family.
///
/// The worlds here are tiny and synthesized through ordinary
/// `Repository.admit`; the neighborhoods come from `Parallelism.expansion`,
/// the same function the measurement uses.
mod Provenance {
    use Repository.Grit.Fact

    pub def world(imports: Vector[Fact], calls: Vector[Fact]): Repository.World = Repository.admit(
        Vector#{source("a.flix"), source("b.flix"), source("c.flix")},
        Vector#{
            fact("definition", "a.flix", 0, 10, "Alpha"),
            fact("definition", "b.flix", 0, 10, "Beta")
        },
        imports, calls)
        |> Result.mapErr(error -> ToString.toString(error))
        |> Experiment.require

    /// One import edge plus one call edge: `a` imports `b` and calls `Beta`.
    pub def linked(): Repository.World = world(
        Vector#{fact("import", "a.flix", 14, 15, "b")},
        Vector#{fact("call", "a.flix", 20, 24, "Beta")})

    /// No relations at all: the seed can only reach itself.
    pub def isolated(): Repository.World = world(Vector.empty(), Vector.empty())

    /// The import chain `a -> b -> c`, so the family depth decides the reach.
    pub def chain(): Repository.World = world(
        Vector#{
            fact("import", "a.flix", 14, 15, "b"),
            fact("import", "b.flix", 14, 15, "c")
        },
        Vector.empty())

    def source(path: String): Repository.Source = {path = path, content = ""}

    def fact(kind: String, path: String, start: Int32, end: Int32, value: String): Fact =
        {kind = kind, path = path, startByte = start, endByte = end, value = value}

    def fileId(index: Int32): Repository.Structure.FileId = Repository.Structure.FileId.FileId(index)

    @Test
    def neighborhoodsComeFromActualAtlasTransitions(): Unit \ Assert = {
        let seed = Set#{fileId(0)};
        Assert.assertEq(expected = Set#{"a.flix"}, Parallelism.outputUnion(isolated(), seed));
        Assert.assertEq(expected = Set#{"a.flix", "b.flix"}, Parallelism.outputUnion(linked(), seed))
    }

    @Test
    def changingAnAdmittedRelationChangesTheNeighborhood(): Unit \ Assert =
        Assert.assertTrue(
            Parallelism.outputUnion(isolated(), Set#{fileId(0)}) !=
                Parallelism.outputUnion(linked(), Set#{fileId(0)}))

    @Test
    def changingTheAtlasFamilyChangesTheNeighborhood(): Unit \ Assert = {
        let seed = Set#{fileId(0)};
        let depthOne = Parallelism.expansion(chain(), seed, Atlas.programsFrom(Radii.Domain.File, 1));
        let depthTwo = Parallelism.expansion(chain(), seed, Atlas.programsFrom(Radii.Domain.File, 2));
        Assert.assertEq(expected = Set#{"a.flix", "b.flix"}, depthOne);
        Assert.assertEq(expected = Set#{"a.flix", "b.flix", "c.flix"}, depthTwo);
        Assert.assertTrue(depthOne != depthTwo)
    }
}
