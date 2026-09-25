/// Typed Parquet representation of one admitted repository world.
///
/// This is downstream of source acquisition and Grit. It contains exactly the
/// nominal entities and admitted basis relations needed by Datalog, Radii, and
/// Atlas. A warm structural action therefore does not need source text, a
/// checkout path, Nix, or Marzano.
pub mod Repository.Table {
    use ScientificTable.Value
    use ScientificTable.Columns.{text, optionalText, int32, optionalInt32}

    pub type alias Identity = {
        repository         = String,
        baseRevision       = String,
        sourceTreeIdentity = String,
        factIdentity       = String,
        snapshotId         = String
    }

    pub type alias Rows = {
        metadata  = Vector[ScientificTable.Row],
        entities  = Vector[ScientificTable.Row],
        relations = Vector[ScientificTable.Row]
    }

    enum Entity {
        case File(Int32, String)
        case Symbol(Int32, String, String, Int32, Int32)
    }

    enum Relation {
        case Defines(Repository.Structure.FileId, Repository.Structure.SymbolId)
        case Imports(Repository.Structure.FileId, Repository.Structure.FileId)
        case Calls(Repository.Structure.SymbolId, Repository.Structure.SymbolId)
        case Parent(Repository.Structure.LocationId, Repository.Structure.LocationId)
    }

    pub def metadata(): ScientificTable.Schema = {
        format = "attune-repository-world-metadata-v1",
        columns = Vector#{
            text("repository"), text("base_revision"), text("source_tree_identity"),
            text("fact_identity"), text("snapshot_id"), int32("file_count"),
            int32("symbol_count"), int32("defines_count"), int32("imports_count"),
            int32("calls_count"), int32("parent_count"),
            int32("unresolved_imports"), int32("unresolved_calls")
        }
    }

    /// Files and Symbols share nominal integer storage but retain an explicit
    /// domain. Symbol-only source geometry is nullable; File rows must leave it
    /// empty and Symbol rows must populate it.
    pub def entities(): ScientificTable.Schema = {
        format = "attune-repository-world-entities-v1",
        columns = Vector#{
            text("snapshot_id"), text("domain"), int32("entity_id"),
            int32("ordinal"), text("path"), optionalText("name"),
            optionalInt32("start_byte"), optionalInt32("end_byte")
        }
    }

    /// The four admitted basis relations. Derived inverses and neighborhoods
    /// are intentionally absent: Datalog and the physical evaluator derive
    /// them from this smaller authoritative basis.
    pub def relations(): ScientificTable.Schema = {
        format = "attune-repository-world-relations-v1",
        columns = Vector#{
            text("snapshot_id"), text("relation"), text("source_domain"),
            int32("source_id"), text("target_domain"), int32("target_id")
        }
    }

    pub def rows(identity: Identity, world: Repository.World): Rows = {
        metadata = Vector#{metadataRow(identity, world)},
        entities = Vector.append(fileRows(identity#snapshotId, world#files),
            symbolRows(identity#snapshotId, world#symbols)),
        relations = relationRows(identity#snapshotId, world)
    }

    /// Semantic fact identity. This includes the admitted source tree and
    /// Grit/Marzano protocol plus the canonical nominal world. Store paths,
    /// Parquet bytes, and evaluator representations are deliberately absent.
    pub def factIdentity(
        sourceTreeIdentity: String,
        gritIdentity: String,
        world: Repository.World
    ): String \ IO = ScientificIdentity.versioned("repository-facts-v2",
        field(sourceTreeIdentity) + field(gritIdentity) + worldPayload(world))

    pub def snapshotIdentity(
        repository: String,
        baseRevision: String,
        sourceTreeIdentity: String,
        factIdentity0: String
    ): String \ IO = ScientificIdentity.versioned("repository-snapshot-v1",
        field(repository) + field(baseRevision) +
        field(sourceTreeIdentity) + field(factIdentity0))

    /// Decode only the exact declared snapshot. Row order is not trusted;
    /// ordinals restore the vectors that define nominal FileId/SymbolId values.
    pub def world(expected: Identity, rows0: Rows): Result[String, Repository.World] = forM (
        _ <- requireMetadata(expected, rows0#metadata);
        entities0 <- Vector.traverse(row -> decodeEntity(expected#snapshotId, row), rows0#entities);
        files <- orderedFiles(entities0);
        symbols <- orderedSymbols(entities0);
        relations0 <- Vector.traverse(row -> decodeRelation(expected#snapshotId, row), rows0#relations);
        world <- makeWorld(files, symbols, relations0, rows0#metadata);
        _ <- requireCounts(world, Vector.get(0, rows0#metadata))
    ) yield world

    pub def write(
        metadataPath: String,
        entitiesPath: String,
        relationsPath: String,
        identity: Identity,
        world: Repository.World
    ): Rows \ IO = {
        let encoded = rows(identity, world);
        {
            metadata = ScientificTable.write(metadataPath, metadata(), encoded#metadata),
            entities = ScientificTable.write(entitiesPath, entities(), encoded#entities),
            relations = ScientificTable.write(relationsPath, relations(), encoded#relations)
        }
    }

    pub def read(
        metadataPath: String,
        entitiesPath: String,
        relationsPath: String,
        identity: Identity
    ): Result[String, Repository.World] \ IO = world(identity, {
        metadata = ScientificTable.read(metadataPath, metadata()),
        entities = ScientificTable.read(entitiesPath, entities()),
        relations = ScientificTable.read(relationsPath, relations())
    })

    def metadataRow(identity: Identity, world: Repository.World): ScientificTable.Row = Map#{
        "repository" => Value.Text(identity#repository),
        "base_revision" => Value.Text(identity#baseRevision),
        "source_tree_identity" => Value.Text(identity#sourceTreeIdentity),
        "fact_identity" => Value.Text(identity#factIdentity),
        "snapshot_id" => Value.Text(identity#snapshotId),
        "file_count" => Value.Int32(Vector.length(world#files)),
        "symbol_count" => Value.Int32(Vector.length(world#symbols)),
        "defines_count" => Value.Int32(Set.size(world#defines)),
        "imports_count" => Value.Int32(Set.size(world#imports)),
        "calls_count" => Value.Int32(Set.size(world#calls)),
        "parent_count" => Value.Int32(Set.size(world#parents)),
        "unresolved_imports" => Value.Int32(world#unresolvedImports),
        "unresolved_calls" => Value.Int32(world#unresolvedCalls)
    }

    def worldPayload(world: Repository.World): String = {
        let files = Vector.mapWithIndex((ordinal, path) ->
            "F:${ordinal}:${field(path)}", world#files);
        let symbols = Vector.mapWithIndex((ordinal, symbol) ->
            "S:${ordinal}:${field(symbol#path)}${field(symbol#name)}:${symbol#startByte}:${symbol#endByte}",
            world#symbols);
        let defines = edgePayload("D", fileId, symbolId, world#defines);
        let imports = edgePayload("I", fileId, fileId, world#imports);
        let calls = edgePayload("C", symbolId, symbolId, world#calls);
        let parents = edgePayload("P", locationId, locationId, world#parents);
        Vector.flatten(Vector#{files, symbols, defines, imports, calls, parents})
            |> Vector.append(Vector#{
                "UI:${world#unresolvedImports}", "UC:${world#unresolvedCalls}"
            })
            |> Vector.join("\n")
    }

    /// Canonical sorted payload lines for one admitted edge relation.
    def edgePayload[a: Type, b: Type](prefix: String, sourceId: a -> Int32, targetId: b -> Int32,
                                      edges: Set[(a, b)]): Vector[String] with Order[a], Order[b] =
        Set.toVector(edges)
            |> Vector.map(match (source, target) -> "${prefix}:${sourceId(source)}:${targetId(target)}")
            |> Vector.sort

    def field(value: String): String = "${String.length(value)}:${value}"

    def fileRows(snapshotId: String, files0: Vector[String]): Vector[ScientificTable.Row] =
        Vector.mapWithIndex((ordinal, path) -> Map#{
            "snapshot_id" => Value.Text(snapshotId), "domain" => Value.Text("file"),
            "entity_id" => Value.Int32(ordinal), "ordinal" => Value.Int32(ordinal),
            "path" => Value.Text(path), "name" => Value.Null,
            "start_byte" => Value.Null, "end_byte" => Value.Null
        }, files0)

    def symbolRows(snapshotId: String, symbols0: Vector[Repository.Symbol]): Vector[ScientificTable.Row] =
        Vector.mapWithIndex((ordinal, symbol) -> Map#{
            "snapshot_id" => Value.Text(snapshotId), "domain" => Value.Text("symbol"),
            "entity_id" => Value.Int32(ordinal), "ordinal" => Value.Int32(ordinal),
            "path" => Value.Text(symbol#path), "name" => Value.Text(symbol#name),
            "start_byte" => Value.Int32(symbol#startByte),
            "end_byte" => Value.Int32(symbol#endByte)
        }, symbols0)

    def relationRows(snapshotId: String, world: Repository.World): Vector[ScientificTable.Row] =
        Vector.flatten(Vector#{
            Set.toVector(world#defines) |> Vector.map(match (source, target) ->
                relationRow(snapshotId, "defines", "file", fileId(source), "symbol", symbolId(target))),
            Set.toVector(world#imports) |> Vector.map(match (source, target) ->
                relationRow(snapshotId, "imports", "file", fileId(source), "file", fileId(target))),
            Set.toVector(world#calls) |> Vector.map(match (source, target) ->
                relationRow(snapshotId, "calls", "symbol", symbolId(source), "symbol", symbolId(target))),
            Set.toVector(world#parents) |> Vector.map(match (source, target) ->
                relationRow(snapshotId, "parent", "location", locationId(source), "location", locationId(target)))
        })

    def relationRow(snapshotId: String, relation: String, sourceDomain: String,
                    source: Int32, targetDomain: String, target: Int32): ScientificTable.Row = Map#{
        "snapshot_id" => Value.Text(snapshotId), "relation" => Value.Text(relation),
        "source_domain" => Value.Text(sourceDomain), "source_id" => Value.Int32(source),
        "target_domain" => Value.Text(targetDomain), "target_id" => Value.Int32(target)
    }

    def requireMetadata(expected: Identity, rows0: Vector[ScientificTable.Row]): Result[String, Unit] =
        if (Vector.length(rows0) != 1) Err("repository world requires exactly one metadata row")
        else {
            let row = Vector.get(0, rows0);
            forM (
                _ <- ScientificTable.requireText("repository", expected#repository, row, "repository world");
                _ <- ScientificTable.requireText("base_revision", expected#baseRevision, row, "repository world");
                _ <- ScientificTable.requireText("source_tree_identity", expected#sourceTreeIdentity, row, "repository world");
                _ <- ScientificTable.requireText("fact_identity", expected#factIdentity, row, "repository world");
                _ <- ScientificTable.requireText("snapshot_id", expected#snapshotId, row, "repository world")
            ) yield ()
        }

    def decodeEntity(snapshotId: String, row: ScientificTable.Row): Result[String, Entity] = forM (
        _ <- ScientificTable.requireText("snapshot_id", snapshotId, row, "repository world");
        domain <- ScientificTable.text(row, "domain");
        id <- ScientificTable.int32(row, "entity_id");
        ordinal <- ScientificTable.int32(row, "ordinal");
        _ <- if (id == ordinal) Ok(()) else Err("repository entity id/ordinal mismatch");
        path <- ScientificTable.text(row, "path");
        entity <- match domain {
            case "file" => forM (
                _ <- requireNull("name", row);
                _ <- requireNull("start_byte", row);
                _ <- requireNull("end_byte", row)
            ) yield Entity.File(ordinal, path)
            case "symbol" => forM (
                name <- ScientificTable.text(row, "name");
                start <- ScientificTable.int32(row, "start_byte");
                end <- ScientificTable.int32(row, "end_byte")
            ) yield Entity.Symbol(ordinal, path, name, start, end)
            case _ => Err("unknown repository entity domain: ${domain}")
        }
    ) yield entity

    def decodeRelation(snapshotId: String, row: ScientificTable.Row): Result[String, Relation] = forM (
        _ <- ScientificTable.requireText("snapshot_id", snapshotId, row, "repository world");
        relation <- ScientificTable.text(row, "relation");
        sourceDomain <- ScientificTable.text(row, "source_domain");
        source <- ScientificTable.int32(row, "source_id");
        targetDomain <- ScientificTable.text(row, "target_domain");
        target <- ScientificTable.int32(row, "target_id");
        edge <- match (relation, sourceDomain, targetDomain) {
            case ("defines", "file", "symbol") => Ok(Relation.Defines(file(source), symbol(target)))
            case ("imports", "file", "file") => Ok(Relation.Imports(file(source), file(target)))
            case ("calls", "symbol", "symbol") => Ok(Relation.Calls(symbol(source), symbol(target)))
            case ("parent", "location", "location") => Ok(Relation.Parent(location(source), location(target)))
            case _ => Err("invalid repository relation/domain combination: ${relation}")
        }
    ) yield edge

    def orderedFiles(entities0: Vector[Entity]): Result[String, Vector[String]] = {
        let entries = Vector.filterMap(match entity -> match entity {
            case Entity.File(ordinal, path) => Some((ordinal, path))
            case _ => None
        }, entities0) |> ScientificTable.canonicalOrdinals;
        ScientificTable.requireContiguous("repository entity ordinals must be contiguous from zero", entries)
            |> Result.map(_ -> Vector.map(match (_, path) -> path, entries))
    }

    def orderedSymbols(entities0: Vector[Entity]): Result[String, Vector[Repository.Symbol]] = {
        let entries = Vector.filterMap(match entity -> match entity {
            case Entity.Symbol(ordinal, path, name, start, end) => Some((ordinal, {
                path = path, name = name, startByte = start, endByte = end
            }))
            case _ => None
        }, entities0) |> ScientificTable.canonicalOrdinals;
        ScientificTable.requireContiguous("repository entity ordinals must be contiguous from zero", entries)
            |> Result.map(_ -> Vector.map(match (_, value) -> value, entries))
    }

    def makeWorld(files0: Vector[String], symbols0: Vector[Repository.Symbol], relations0: Vector[Relation], metadata0: Vector[ScientificTable.Row]): Result[String, Repository.World] =
        forM (
            unresolvedImports <- ScientificTable.int32(Vector.get(0, metadata0), "unresolved_imports");
            unresolvedCalls <- ScientificTable.int32(Vector.get(0, metadata0), "unresolved_calls")
        ) yield {
            files = files0,
            symbols = symbols0,
            defines = Vector.filterMap(definesEdge, relations0) |> Vector.toSet,
            imports = Vector.filterMap(importsEdge, relations0) |> Vector.toSet,
            calls = Vector.filterMap(callsEdge, relations0) |> Vector.toSet,
            parents = Vector.filterMap(parentEdge, relations0) |> Vector.toSet,
            unresolvedImports = unresolvedImports,
            unresolvedCalls = unresolvedCalls
        }

    def definesEdge(edge: Relation): Option[(Repository.Structure.FileId, Repository.Structure.SymbolId)] = match edge {
        case Relation.Defines(source, target) => Some((source, target))
        case _ => None
    }

    def importsEdge(edge: Relation): Option[(Repository.Structure.FileId, Repository.Structure.FileId)] = match edge {
        case Relation.Imports(source, target) => Some((source, target))
        case _ => None
    }

    def callsEdge(edge: Relation): Option[(Repository.Structure.SymbolId, Repository.Structure.SymbolId)] = match edge {
        case Relation.Calls(source, target) => Some((source, target))
        case _ => None
    }

    def parentEdge(edge: Relation): Option[(Repository.Structure.LocationId, Repository.Structure.LocationId)] = match edge {
        case Relation.Parent(source, target) => Some((source, target))
        case _ => None
    }

    def requireCounts(world: Repository.World, row: ScientificTable.Row): Result[String, Unit] = {
        let actual = Vector#{
            ("file_count", Vector.length(world#files)), ("symbol_count", Vector.length(world#symbols)),
            ("defines_count", Set.size(world#defines)), ("imports_count", Set.size(world#imports)),
            ("calls_count", Set.size(world#calls)), ("parent_count", Set.size(world#parents))
        };
        Vector.traverse(match (name, count) -> ScientificTable.int32(row, name)
            |> Result.flatMap(expected -> if (expected == count) Ok(()) else Err("repository world count mismatch: ${name}")), actual)
            |> Result.map(_ -> ())
    }

    def requireNull(name: String, row: ScientificTable.Row): Result[String, Unit] = match Map.get(name, row) {
        case Some(Value.Null) => Ok(())
        case Some(_) => Err("repository world field must be null: ${name}")
        case None => Err("missing repository world field: ${name}")
    }

    def file(value: Int32): Repository.Structure.FileId = Repository.Structure.FileId.FileId(value)
    def symbol(value: Int32): Repository.Structure.SymbolId = Repository.Structure.SymbolId.SymbolId(value)
    def location(value: Int32): Repository.Structure.LocationId = Repository.Structure.LocationId.LocationId(value)
    def fileId(value: Repository.Structure.FileId): Int32 = let Repository.Structure.FileId.FileId(id) = value; id
    def symbolId(value: Repository.Structure.SymbolId): Int32 = let Repository.Structure.SymbolId.SymbolId(id) = value; id
    def locationId(value: Repository.Structure.LocationId): Int32 = let Repository.Structure.LocationId.LocationId(id) = value; id
}
