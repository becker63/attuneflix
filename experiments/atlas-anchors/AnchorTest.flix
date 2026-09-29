mod AnchorTest {
    use Repository.Structure.{FileId, SymbolId}

    def world(): Repository.World = {
        let a = FileId.FileId(0);
        let b = FileId.FileId(1);
        let sa = SymbolId.SymbolId(0);
        let sb = SymbolId.SymbolId(1);
        {
            files = Vector#{"packages/a/a.ts", "packages/b/b.ts"},
            symbols = Vector#{
                {path = "packages/a/a.ts", name = "a", startByte = 0, endByte = 1},
                {path = "packages/b/b.ts", name = "b", startByte = 0, endByte = 1}
            },
            defines = Set#{(a, sa), (b, sb)},
            imports = Set#{(a, a), (a, b), (b, a)},
            calls = Set#{(sa, sa), (sa, sb)},
            parents = Set.empty(), unresolvedImports = 0, unresolvedCalls = 0
        }
    }

    @Test
    def liveRecurrenceExcludesTypedEmptyStates(): Unit \ Assert = {
        let a = FileId.FileId(0);
        let b = FileId.FileId(1);
        let rows = Vector#{
            Atlas.State.Files(Set.empty()), Atlas.State.Files(Set.empty()),
            Atlas.State.Files(Set#{a}), Atlas.State.Files(Set#{a}),
            Atlas.State.Files(Set#{b})
        };
        let result = Anchor.decompose(rows);
        Assert.assertEq(expected = 5, result#observations);
        Assert.assertEq(expected = 2, result#extinctObservations);
        Assert.assertEq(expected = 3, result#liveObservations);
        Assert.assertEq(expected = 3, result#uniqueStates);
        Assert.assertEq(expected = 2, result#uniqueLiveStates);
        Assert.assertEq(expected = 5.0 / 3.0, result#totalRecurrence);
        Assert.assertEq(expected = 1.5, result#liveRecurrence);
        let symbol = Anchor.decompose(Vector#{Atlas.State.Symbols(Set.empty())});
        Assert.assertEq(expected = 1, symbol#uniqueStates);
        Assert.assertEq(expected = 0, symbol#uniqueLiveStates);
        let typed = Anchor.decompose(Vector#{
            Atlas.State.Files(Set.empty()), Atlas.State.Symbols(Set.empty())
        });
        Assert.assertEq(expected = 2, typed#uniqueStates);
        Assert.assertEq(expected = 2, typed#extinctObservations)
    }

    @Test
    def anchorMassSeparatesUniqueStatesFromObservationTraffic(): Unit \ Assert = {
        let a = FileId.FileId(0);
        let b = FileId.FileId(1);
        let rows = Vector#{
            Atlas.State.Files(Set#{a}), Atlas.State.Files(Set#{a}),
            Atlas.State.Files(Set#{a, b}), Atlas.State.Files(Set#{b}),
            Atlas.State.Files(Set.empty())
        };
        let mass = match Vector.find(row -> row#anchorPath == "packages/a", Anchor.masses(world(), rows)) {
            case Some(value) => value
            case None => bug!("missing anchor")
        };
        Assert.assertEq(expected = 2, mass#uniqueContaining);
        Assert.assertEq(expected = 3, mass#weightedContaining);
        Assert.assertEq(expected = 3, mass#uniqueLiveStates);
        Assert.assertEq(expected = 4, mass#liveObservations);
        Assert.assertEq(expected = 2.0 / 3.0, mass#uniqueFraction);
        Assert.assertEq(expected = 0.75, mass#weightedFraction)
    }

    @Test
    def maskingRemovesOnlyBoundaryDependencies(): Unit \ Assert = {
        let original = world();
        let masked = Anchor.maskBoundary(original, "packages/a");
        Assert.assertEq(expected = 3, Set.size(original#imports));
        Assert.assertEq(expected = 1, Set.size(masked#imports));
        Assert.assertEq(expected = 1, Set.size(masked#calls));
        Assert.assertEq(expected = original#files, masked#files);
        Assert.assertEq(expected = Vector.map(symbol -> symbol#path, original#symbols),
            Vector.map(symbol -> symbol#path, masked#symbols));
        Assert.assertEq(expected = original#defines, masked#defines);
        Assert.assertEq(expected = original#parents, masked#parents);
        Assert.assertEq(expected = 3, Anchor.crossingVolume(original, "packages/a"))
    }
}
