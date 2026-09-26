// Typed scientific tables: Flix owns the schema and the row meaning, and the
// transport only moves primitive columns. The kernel declares `Schema`/`Value`/
// `Row`; `Scientific.Schema`/`Scientific.Value`/`Scientific.Row` are their pure
// semantics. This law compiles and runs the whole pure surface with no FFI
// (VAL-KERN-002, VAL-DECOMP-001).
@Test
def typedScientificSchemaIsDeclaredInFlix(): Unit \ Assert = {
    let schema: Kernel.Contract.Schema = {
        format = "atlas-signature-observations-v1",
        columns = Vector#{
            {name = "signature_protocol", kind = Kernel.Contract.ColumnType.Text, nullable = false},
            {name = "depth", kind = Kernel.Contract.ColumnType.Int64, nullable = false},
            {name = "expansion_ratio", kind = Kernel.Contract.ColumnType.Float64, nullable = true},
            {name = "extinct", kind = Kernel.Contract.ColumnType.Boolean, nullable = false},
            {name = "route_atoms", kind = Kernel.Contract.ColumnType.TextList, nullable = false}
        }
    };
    Assert.assertEq(
        expected = "{\"columns\":[{\"name\":\"signature_protocol\",\"nullable\":false,\"type\":\"string\"},{\"name\":\"depth\",\"nullable\":false,\"type\":\"int64\"},{\"name\":\"expansion_ratio\",\"nullable\":true,\"type\":\"float64\"},{\"name\":\"extinct\",\"nullable\":false,\"type\":\"boolean\"},{\"name\":\"route_atoms\",\"nullable\":false,\"type\":\"list<string>\"}],\"format\":\"atlas-signature-observations-v1\"}",
        Kernel.Contract.schemaPayload(schema)
    )
}

@Test
def columnConstructorsDeclareNameKindAndNullability(): Unit \ Assert = {
    let columns = Vector#{
        Scientific.Schema.text("a"),
        Scientific.Schema.optionalText("b"),
        Scientific.Schema.textList("c"),
        Scientific.Schema.int32("d"),
        Scientific.Schema.optionalInt32("e"),
        Scientific.Schema.int64("f"),
        Scientific.Schema.optionalInt64("g"),
        Scientific.Schema.float64("h"),
        Scientific.Schema.optionalFloat64("i"),
        Scientific.Schema.boolean("j")
    };
    Assert.assertEq(
        expected = Vector#{
            ("a", Kernel.Contract.ColumnType.Text, false),
            ("b", Kernel.Contract.ColumnType.Text, true),
            ("c", Kernel.Contract.ColumnType.TextList, false),
            ("d", Kernel.Contract.ColumnType.Int32, false),
            ("e", Kernel.Contract.ColumnType.Int32, true),
            ("f", Kernel.Contract.ColumnType.Int64, false),
            ("g", Kernel.Contract.ColumnType.Int64, true),
            ("h", Kernel.Contract.ColumnType.Float64, false),
            ("i", Kernel.Contract.ColumnType.Float64, true),
            ("j", Kernel.Contract.ColumnType.Boolean, false)
        },
        Vector.map(column -> (column#name, column#kind, column#nullable), columns))
}

@Test
def valueAccessorsAndLiftsPreserveNulls(): Unit \ Assert = {
    let row: Kernel.Contract.Row = Map#{
        "flag" => Kernel.Contract.Value.Boolean(true),
        "depth" => Kernel.Contract.Value.Int32(3),
        "score" => Kernel.Contract.Value.Null,
        "reason" => Kernel.Contract.Value.Null
    };
    Assert.assertEq(expected = Ok(true), Scientific.Value.boolean(row, "flag"));
    Assert.assertEq(expected = Ok(Some(3)), Scientific.Value.optionalInt32(row, "depth"));
    Assert.assertEq(expected = Ok(None), Scientific.Value.optionalFloat64(row, "score"));
    Assert.assertEq(expected = Ok(None), Scientific.Value.optionalText(row, "reason"));
    Assert.assertEq(expected = Kernel.Contract.Value.Null, Scientific.Value.optionalInt32Value(None));
    Assert.assertEq(expected = Kernel.Contract.Value.Int32(3), Scientific.Value.optionalInt32Value(Some(3)));
    Assert.assertEq(expected = 0.0, Scientific.Value.ratio(1, 0));
    Assert.assertEq(expected = 3.0, Scientific.Value.maximum(Vector#{1.0, 3.0, 2.0}))
}
