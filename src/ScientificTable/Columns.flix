/// Shared explicit-column constructors for the typed scientific tables.
/// Every table module declares its schemas through these so the
/// {name, kind, nullable} literal has exactly one owner.
pub mod ScientificTable.Columns {
    pub def text(name: String): Kernel.Contract.Column = {name = name, kind = Kernel.Contract.ColumnType.Text, nullable = false}
    pub def optionalText(name: String): Kernel.Contract.Column = {name = name, kind = Kernel.Contract.ColumnType.Text, nullable = true}
    pub def textList(name: String): Kernel.Contract.Column = {name = name, kind = Kernel.Contract.ColumnType.TextList, nullable = false}
    pub def int32(name: String): Kernel.Contract.Column = {name = name, kind = Kernel.Contract.ColumnType.Int32, nullable = false}
    pub def optionalInt32(name: String): Kernel.Contract.Column = {name = name, kind = Kernel.Contract.ColumnType.Int32, nullable = true}
    pub def int64(name: String): Kernel.Contract.Column = {name = name, kind = Kernel.Contract.ColumnType.Int64, nullable = false}
    pub def optionalInt64(name: String): Kernel.Contract.Column = {name = name, kind = Kernel.Contract.ColumnType.Int64, nullable = true}
    pub def float64(name: String): Kernel.Contract.Column = {name = name, kind = Kernel.Contract.ColumnType.Float64, nullable = false}
    pub def optionalFloat64(name: String): Kernel.Contract.Column = {name = name, kind = Kernel.Contract.ColumnType.Float64, nullable = true}
    pub def boolean(name: String): Kernel.Contract.Column = {name = name, kind = Kernel.Contract.ColumnType.Boolean, nullable = false}
}
