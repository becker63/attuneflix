@Test
def typedScientificSchemaIsDeclaredInFlix(): Unit \ Assert = {
    let schema: ScientificTable.Schema = {
        format = "atlas-signature-observations-v1",
        columns = Vector#{
            {name = "signature_protocol", kind = ScientificTable.ColumnType.Text, nullable = false},
            {name = "depth", kind = ScientificTable.ColumnType.Int64, nullable = false},
            {name = "expansion_ratio", kind = ScientificTable.ColumnType.Float64, nullable = true},
            {name = "extinct", kind = ScientificTable.ColumnType.Boolean, nullable = false},
            {name = "route_atoms", kind = ScientificTable.ColumnType.TextList, nullable = false}
        }
    };
    Assert.assertEq(
        expected = "{\"columns\":[{\"name\":\"signature_protocol\",\"nullable\":false,\"type\":\"string\"},{\"name\":\"depth\",\"nullable\":false,\"type\":\"int64\"},{\"name\":\"expansion_ratio\",\"nullable\":true,\"type\":\"float64\"},{\"name\":\"extinct\",\"nullable\":false,\"type\":\"boolean\"},{\"name\":\"route_atoms\",\"nullable\":false,\"type\":\"list<string>\"}],\"format\":\"atlas-signature-observations-v1\"}",
        ScientificTable.schemaPayload(schema)
    )
}
