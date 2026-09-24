/// Explicit Parquet schemas for the frozen population and protocol.
pub mod Population.Table {
    use ScientificTable.Value

    pub type alias Tables = {
        metadata = Vector[ScientificTable.Row],
        cases    = Vector[ScientificTable.Row]
    }

    pub def protocol(): String = "attune-swe-explore-population-v1"

    pub def metadata(): ScientificTable.Schema = {
        format = "attune-population-metadata-v1",
        columns = Vector#{
            text("protocol"), text("benchmark_revision"), text("multilingual_revision"),
            text("pro_revision"), text("source_routing"), text("atlas_protocol"),
            int32("max_depth"), int32("center_count"), int32("logical_routes"),
            int32("symbol_routes")
        }
    }

    pub def cases(): ScientificTable.Schema = {
        format = "attune-population-cases-v1",
        columns = Vector#{
            text("protocol"), int32("ordinal"), text("instance_id"), text("repository"),
            text("base_revision"), text("dataset_family"), text("language"),
            text("population"), text("split"), text("source_routing"),
            text("source_identity"), text("outcome"), optionalText("censor_reason")
        }
    }

    pub def rows(frozen: Population.Frozen): Tables = {
        metadata = Vector#{metadataRow(frozen#protocol)},
        cases = Vector.map(caseRow, frozen#cases)
    }

    pub def write(metadataPath: String, casesPath: String, tables: Tables): Tables \ IO = {
        metadata = ScientificTable.write(metadataPath, metadata(), tables#metadata),
        cases = ScientificTable.write(casesPath, cases(), tables#cases)
    }

    pub def read(metadataPath: String, casesPath: String): Result[String, Population.Frozen] \ IO =
        frozen({
            metadata = ScientificTable.read(metadataPath, metadata()),
            cases = ScientificTable.read(casesPath, cases())
        })

    pub def frozen(tables: Tables): Result[String, Population.Frozen] = forM (
        row <- exactlyOne(tables#metadata);
        protocol0 <- decodeMetadata(row);
        cases0 <- Vector.traverse(decodeCase, tables#cases);
        _ <- contiguous(cases0);
        _ <- if (Vector.length(cases0) == 78) Ok(()) else Err("population must contain 78 cases")
    ) yield {protocol = protocol0, cases = cases0}

    def metadataRow(value: Population.Protocol): ScientificTable.Row = Map#{
        "protocol" => Value.Text(protocol()),
        "benchmark_revision" => Value.Text(value#benchmarkRevision),
        "multilingual_revision" => Value.Text(value#multilingualRevision),
        "pro_revision" => Value.Text(value#proRevision),
        "source_routing" => Value.Text(value#sourceRouting),
        "atlas_protocol" => Value.Text(value#atlasProtocol),
        "max_depth" => Value.Int32(value#maxDepth),
        "center_count" => Value.Int32(value#centerCount),
        "logical_routes" => Value.Int32(value#logicalRoutes),
        "symbol_routes" => Value.Int32(value#symbolRoutes)
    }

    def caseRow(value: Population.Case): ScientificTable.Row = Map#{
        "protocol" => Value.Text(protocol()), "ordinal" => Value.Int32(value#ordinal),
        "instance_id" => Value.Text(value#instanceId), "repository" => Value.Text(value#repository),
        "base_revision" => Value.Text(value#baseRevision), "dataset_family" => Value.Text(value#datasetFamily),
        "language" => Value.Text(value#language), "population" => Value.Text(value#population),
        "split" => Value.Text(value#split), "source_routing" => Value.Text(value#sourceRouting),
        "source_identity" => Value.Text(value#sourceIdentity),
        "outcome" => Value.Text(outcomeName(value#outcome)),
        "censor_reason" => censorReason(value#outcome)
    }

    def decodeMetadata(row: ScientificTable.Row): Result[String, Population.Protocol] = forM (
        _ <- requireProtocol(row);
        benchmark <- ScientificTable.text(row, "benchmark_revision");
        multilingual <- ScientificTable.text(row, "multilingual_revision");
        pro <- ScientificTable.text(row, "pro_revision");
        routing <- ScientificTable.text(row, "source_routing");
        atlas <- ScientificTable.text(row, "atlas_protocol");
        depth <- ScientificTable.int32(row, "max_depth");
        centers <- ScientificTable.int32(row, "center_count");
        routes <- ScientificTable.int32(row, "logical_routes");
        symbols <- ScientificTable.int32(row, "symbol_routes")
    ) yield {
        benchmarkRevision = benchmark, multilingualRevision = multilingual,
        proRevision = pro, sourceRouting = routing, atlasProtocol = atlas,
        maxDepth = depth, centerCount = centers, logicalRoutes = routes, symbolRoutes = symbols
    }

    def decodeCase(row: ScientificTable.Row): Result[String, Population.Case] = forM (
        _ <- requireProtocol(row);
        ordinal <- ScientificTable.int32(row, "ordinal");
        instanceId <- ScientificTable.text(row, "instance_id");
        repository <- ScientificTable.text(row, "repository");
        revision <- ScientificTable.text(row, "base_revision");
        family <- ScientificTable.text(row, "dataset_family");
        language <- ScientificTable.text(row, "language");
        population <- ScientificTable.text(row, "population");
        split <- ScientificTable.text(row, "split");
        routing <- ScientificTable.text(row, "source_routing");
        source <- ScientificTable.text(row, "source_identity");
        outcome <- ScientificTable.text(row, "outcome");
        reason <- ScientificTable.optionalText(row, "censor_reason");
        outcome0 <- decodeOutcome(outcome, reason)
    ) yield {
        ordinal = ordinal, instanceId = instanceId, repository = repository,
        baseRevision = revision, datasetFamily = family, language = language,
        population = population, split = split, sourceRouting = routing,
        sourceIdentity = source, outcome = outcome0
    }

    def decodeOutcome(name: String, reason: Option[String]): Result[String, Population.Outcome] =
        match (name, reason) {
            case ("completed", None) => Ok(Population.Outcome.Completed)
            case ("censored", Some(value)) => Ok(Population.Outcome.Censored(value))
            case _ => Err("invalid population outcome")
        }

    def contiguous(values: Vector[Population.Case]): Result[String, Unit] =
        if (Vector.forAll(match (index, value) -> index == value#ordinal,
            Vector.mapWithIndex((index, value) -> (index, value), values))) Ok(())
        else Err("population ordinals must be contiguous")

    def requireProtocol(row: ScientificTable.Row): Result[String, Unit] =
        ScientificTable.text(row, "protocol")
        |> Result.flatMap(actual -> if (actual == protocol()) Ok(()) else Err("population protocol mismatch"))

    def exactlyOne(rows: Vector[a]): Result[String, a] =
        if (Vector.length(rows) == 1) Ok(Vector.get(0, rows)) else Err("population metadata requires one row")

    def outcomeName(value: Population.Outcome): String = match value {
        case Population.Outcome.Completed => "completed"
        case Population.Outcome.Censored(_) => "censored"
    }

    def censorReason(value: Population.Outcome): ScientificTable.Value = match value {
        case Population.Outcome.Completed => Value.Null
        case Population.Outcome.Censored(reason) => Value.Text(reason)
    }

    def text(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Text, nullable = false}
    def optionalText(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Text, nullable = true}
    def int32(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int32, nullable = false}
}
