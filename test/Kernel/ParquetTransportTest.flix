// Table transport boundary law (VAL-DECOMP-001).
//
// The Arrow boundary never carries meaning: it moves the canonical payload that
// pure Flix composes and the kernel decodes. These laws pin that wire contract,
// which is exactly what `Scientific.Parquet` hands to the native engine. The
// native engine itself runs under `//src/native/parquet:attune_parquet_test`,
// whose lib flags the plain Flix law runner cannot set.
use Kernel.Contract.{ColumnType, Row, Schema, Value}

def transportSchema(): Schema = {
    format = "attune-transport-boundary-v1",
    columns = Vector#{
        {name = "protocol", kind = ColumnType.Text, nullable = false},
        {name = "ordinal", kind = ColumnType.Int32, nullable = false},
        {name = "score", kind = ColumnType.Float64, nullable = true},
        {name = "route_atoms", kind = ColumnType.TextList, nullable = false}
    }
}

def transportRows(): Vector[Row] = Vector#{
    Map#{
        "protocol" => Value.Text("p"), "ordinal" => Value.Int32(0),
        "score" => Value.Float64(1.5), "route_atoms" => Value.TextList(Vector#{"Defines"})
    },
    Map#{
        "protocol" => Value.Text("p"), "ordinal" => Value.Int32(1),
        "score" => Value.Null, "route_atoms" => Value.TextList(Vector#{"Calls", "Callers"})
    }
}

@Test
def canonicalRowsRoundTripThroughTheDeclaredSchema(): Unit \ Assert =
    Assert.assertEq(
        expected = Ok(transportRows()),
        Kernel.Contract.decodeRows(transportSchema(), Scientific.Row.canonicalRows(transportRows())))

@Test
def ordinalsAreCanonicalizedToTheirDeclaredOrder(): Unit \ Assert = {
    let entries = Vector#{(2, "c"), (0, "a"), (1, "b")};
    let ordered = Scientific.Row.canonicalOrdinals(entries);
    Assert.assertEq(expected = Vector#{(0, "a"), (1, "b"), (2, "c")}, ordered);
    Assert.assertEq(expected = Ok(()), Scientific.Row.requireContiguous("contiguous", ordered));
    Assert.assertEq(expected = false, Scientific.Row.ordinalsOrdered(entries))
}
