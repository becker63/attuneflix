/// Deterministic Markdown projections of recorded families tables. The charter
/// report embeds these blocks verbatim and `report_test` requires them to match
/// the regenerated projection byte for byte, so report numbers are never typed
/// by hand.
pub mod Families.Report {
    import java.math.{BigDecimal, RoundingMode}

    /// One acquired world as the report sees it: its recorded ledgers and its
    /// keyless replay proof.
    pub type alias Acquired = {
        repository = String,
        ledgers    = Vector[Families.Ledger.Entry],
        proof      = Families.Replay.Proof
    }

    /// The inventory table in the given (declared) world order, with a totals row.
    pub def inventory(values: Vector[Families.Inventory.Inventory]): String = {
        let header = Vector#{
            "| repository | snapshot | files | callables | directories | imports | calls | parents | callable source bytes |",
            "|---|---|---:|---:|---:|---:|---:|---:|---:|"
        };
        let total = Vector.foldLeft((sum, value) -> sum + value#callableSourceBytes, 0i64, values);
        let footer = "| **total** | | ${sumOf(value -> value#files, values)} | ${sumOf(value -> value#callables, values)} | " +
            "${sumOf(value -> value#directories, values)} | ${sumOf(value -> value#imports, values)} | " +
            "${sumOf(value -> value#calls, values)} | ${sumOf(value -> value#parents, values)} | ${total} |";
        Vector.join("\n", Vector.append(Vector.append(header, Vector.map(line, values)), Vector#{footer})) + "\n"
    }

    def line(value: Families.Inventory.Inventory): String =
        "| ${value#repository} | `${shortSnapshot(value#snapshotId)}` | ${value#files} | ${value#callables} | " +
        "${value#directories} | ${value#imports} | ${value#calls} | ${value#parents} | ${value#callableSourceBytes} |"

    def sumOf(field: Families.Inventory.Inventory -> Int32, values: Vector[Families.Inventory.Inventory]): Int32 =
        Vector.foldLeft((sum, value) -> sum + field(value), 0, values)

    /// The first twelve hex digits of the snapshot digest, the census display form.
    def shortSnapshot(snapshotId: String): String = {
        let digest = match String.indexOfRight(substr = ":", snapshotId) {
            case None => snapshotId
            case Some(index) => String.sliceRight(start = index + 1, snapshotId)
        };
        String.sliceLeft(end = 12, digest)
    }

    /// Evidence counts, the cost ledger, and the replay proof per world.
    pub def acquisition(values: Vector[Acquired]): String = {
        let counts = Vector.append(Vector#{
            "| repository | snapshot | documents | batches | seeds | decisions | retained exchanges |",
            "|---|---|---:|---:|---:|---:|---:|"
        }, Vector.map(value -> {
            let rows = name -> Vector.find(check -> check#table == name, value#proof#checks)
                |> Option.map(check -> Int32.toString(check#rows)) |> Option.getWithDefault("-");
            "| ${value#repository} | `${shortSnapshot(value#proof#snapshotId)}` | ${rows("embedding-documents")} | " +
            "${rows("embedding-batches")} | ${rows("family-outcomes")} | ${rows("decisions")} | ${value#proof#retained} |"
        }, values));
        let entries = Vector.flatMap(value -> Vector.map(entry -> (value#repository, entry), value#ledgers), values);
        let total = Vector.foldLeft((sum, pair) -> sum + snd(pair)#costUsd, 0.0, entries);
        let ledger = Vector.append(Vector.append(Vector#{
            "| repository | space | request | requests | cost reported | input tokens | output tokens | cost USD | unit USD | projected USD | envelope USD |",
            "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"
        }, Vector.map(match (repository, entry) ->
            "| ${repository} | `${entry#space}` | ${entry#kind} | ${entry#requests} | ${entry#reported} | " +
            "${entry#inputTokens} | ${entry#outputTokens} | ${usd(entry#costUsd)} | ${usd(entry#unitCostUsd)} | ${usd(entry#projectedUsd)} | ${usd(entry#envelopeUsd)} |",
            entries)), Vector#{
            "| **total** | | | ${Vector.foldLeft((sum, pair) -> sum + snd(pair)#requests, 0, entries)} | | | | " +
            "${usd(total)} | | ${usd(Vector.foldLeft((sum, pair) -> sum + snd(pair)#projectedUsd, 0.0, entries))} | |"
        });
        let replay = Vector.append(Vector#{
            "| repository | table | rows | recorded identity | replayed identity | equal |",
            "|---|---|---:|---|---|---|"
        }, Vector.flatMap(value -> Vector.map(check ->
            "| ${value#repository} | ${check#table} | ${check#rows} | `${shortSnapshot(check#recorded)}` | " +
            "`${shortSnapshot(check#replayed)}` | ${if (check#recorded == check#replayed) "yes" else "no"} |",
            value#proof#checks), values));
        let verdicts = Vector.map(value ->
            "- ${value#repository}: ${value#proof#served} of ${value#proof#retained} retained exchanges served, " +
            "${value#proof#providerCalls} provider calls, key absent: ${if (value#proof#keyAbsent) "yes" else "no"}, " +
            "exact: ${if (Families.Replay.exact(value#proof)) "yes" else "no"}.", values);
        let envelope = "Current pass cap: ${usd(Families.Protocol.envelopeUsd())} USD. Measured total: ${usd(total)} USD.";
        Vector.join("\n", Vector.flatten(Vector#{
            Vector#{"**Recorded evidence**", ""}, counts,
            Vector#{"", "**Cost ledger** (provider-reported usage and cost)", ""}, ledger,
            Vector#{"", envelope, "", "**Keyless replay proof**", ""}, replay, Vector#{""}, verdicts
        })) + "\n"
    }

    /// The protocol constants and exact model-visible instructions.
    pub def protocol(): String = {
        let rows = Vector#{
            ("decision protocol", Families.Protocol.decisions()),
            ("decision space", Families.Protocol.decisionSpace()),
            ("decision endpoint", Families.Protocol.decisionEndpoint()),
            ("decision model", Families.Protocol.decisionModel()),
            ("state header", Families.Protocol.stateHeader()),
            ("state identity protocol", Families.Protocol.stateProtocol()),
            ("objective", Families.Protocol.objective()),
            ("maximum depth", Int32.toString(Families.Protocol.maxDepth())),
            ("preview members", Int32.toString(Families.Protocol.previewSize())),
            ("name candidates", Int32.toString(Families.Protocol.nameCandidates())),
            ("navigation question", Families.Protocol.navigationQuestion()),
            ("naming question", Families.Protocol.namingQuestion()),
            ("embedding protocol", Families.Protocol.embeddings()),
            ("embedding space", Families.Protocol.embeddingSpace()),
            ("embedding endpoint", Families.Protocol.embeddingEndpoint()),
            ("embedding model", Families.Protocol.embeddingModel()),
            ("dimension", Int32.toString(Families.Protocol.dimension())),
            ("document limit (code points)", Int32.toString(Families.Protocol.textLimit())),
            ("batch size", Int32.toString(Families.Protocol.batchSize())),
            ("encoding format", Families.Protocol.encodingFormat()),
            ("ledger protocol", Families.Protocol.ledger()),
            ("pass envelope USD", usd(Families.Protocol.envelopeUsd())),
            ("historical Preact envelope USD", usd(Families.Protocol.legacyEnvelopeUsd())),
            ("embedding USD per token", BigDecimal.valueOf(Families.Protocol.embeddingUsdPerToken()).setScale(8, RoundingMode.HALF_EVEN).toPlainString()),
            ("decision USD bound", usd(Families.Protocol.decisionUsdBound())),
            ("bounded seeds per pass", Int32.toString(Families.Protocol.boundedSeedsPerPass()))
        };
        Vector.join("\n", Vector.flatten(Vector#{
            Vector#{"| constant | value |", "|---|---|"},
            Vector.map(match (name, value) -> "| ${name} | `${value}` |", rows),
            Vector#{"", "Navigation instructions (`${Families.Protocol.navigationQuestion()}`):", "",
                "> ${Families.Protocol.navigationInstructions()}", "",
                "Naming instructions (`${Families.Protocol.namingQuestion()}`):", "",
                "> ${Families.Protocol.namingInstructions()}"}
        })) + "\n"
    }

    /// The clustering method constants: the versioned method and its weights.
    pub def method(): String = Vector.join("\n", Vector.flatten(Vector#{
        Vector#{"| constant | value |", "|---|---|",
            "| method protocol | `${Families.Method.protocol()}` |",
            "| output space | `${Families.Method.space()}` |",
            "| families table | `${Families.Cluster.Table.families()#format}` |",
            "| members table | `${Families.Cluster.Table.members()#format}` |",
            "| rollups table | `${Families.Cluster.Table.rollups()#format}` |",
            "| family edges table | `${Families.Edge.Table.edges()#format}` |",
            "| edge contributions table | `${Families.Edge.Table.contributions()#format}` |"},
        Vector.map(match (name, weight) -> "| weight: ${name} | `${decimal(weight, 2)}` |",
            Families.Method.weightRows(Families.Method.weights()))
    })) + "\n"

    def usd(value: Float64): String = decimal(value, 6)

    def decimal(value: Float64, scale: Int32): String =
        BigDecimal.valueOf(value).setScale(scale, RoundingMode.HALF_EVEN).toPlainString()

    /// One clustered world as the report sees it: the recorded clustering,
    /// the candidate and seed counts, and the single-source ablations (how
    /// many symbols change family without one source).
    pub type alias Clustered = {
        repository     = String,
        clustering     = Families.Cluster.Clustering,
        seeds          = Int32,
        candidates     = Int32,
        structuralOnly = Int32,
        semanticOnly   = Int32
    }

    /// One exported world as the report sees it: its clustering, its family
    /// edges, and every exported file with its rows and SHA-256.
    pub type alias Edged = {
        repository  = String,
        world       = Repository.World,
        clustering  = Families.Cluster.Clustering,
        aggregation = Families.Edge.Aggregation,
        files       = Vector[(String, Int32, String)]
    }

    /// Family edges per relation, the heaviest cross-family edges with their
    /// first contributing exact edge, and the exported files.
    pub def edges(values: Vector[Edged]): String = {
        let counts = Vector.append(Vector#{
            "| repository | snapshot | relation | grain | exact edges | attributed | unattributed | family edges | intra-family edges | intra-family multiplicity | cross-family multiplicity |",
            "|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|"
        }, Vector.flatMap(value -> Vector.map(match (relation, grain) -> {
            let a = value#aggregation;
            let edges0 = Vector.filter(edge -> edge#relation == relation, a#edges);
            let contributions = Vector.filter(c -> c#relation == relation, a#contributions);
            let intra = Vector.filter(edge -> edge#sourceFamily == edge#targetFamily, edges0);
            let weight = Vector.sumWith(edge -> edge#multiplicity);
            let attributed = Vector.count(c -> not Option.isEmpty(c#edge), contributions);
            "| ${value#repository} | `${shortSnapshot(a#snapshotId)}` | ${relation} | ${grain} | ${Vector.length(contributions)} | " +
            "${attributed} | ${Vector.length(contributions) - attributed} | ${Vector.length(edges0)} | ${Vector.length(intra)} | " +
            "${weight(intra)} | ${weight(edges0) - weight(intra)} |"
        }, Families.Edge.relations()), values));
        let heaviest = Vector.append(Vector#{
            "| repository | relation | source family | target family | multiplicity | first contributing exact edge |",
            "|---|---|---|---|---:|---|"
        }, Vector.flatMap(value -> value#aggregation#edges
            |> Vector.filter(edge -> edge#sourceFamily != edge#targetFamily)
            |> Vector.sortBy(edge -> (0 - edge#multiplicity, edge#edge))
            |> Vector.take(8)
            |> Vector.map(edge -> {
                let first = Vector.find(c -> c#edge == Some(edge#edge), value#aggregation#contributions)
                    |> Option.map(c -> "`${endpoint(value#world, c#relation, c#sourceId)}` -> `${endpoint(value#world, c#relation, c#targetId)}`")
                    |> Option.getWithDefault("none");
                "| ${value#repository} | ${edge#relation} | ${familyLabel(value#clustering, edge#sourceFamily)} | " +
                "${familyLabel(value#clustering, edge#targetFamily)} | ${edge#multiplicity} | ${first} |"
            }), values));
        let files = Vector.append(Vector#{"| repository | exported file | rows | sha256 |", "|---|---|---:|---|"},
            Vector.flatMap(value -> Vector.map(match (file, rows, sha) ->
                "| ${value#repository} | `${file}` | ${rows} | `${String.takeLeft(12, sha)}` |", value#files), values));
        Vector.join("\n", Vector.flatten(Vector#{
            Vector#{"**Family edges**", ""}, counts,
            Vector#{"", "**Heaviest cross-family edges**", ""}, heaviest,
            Vector#{"", "**Exported files** (`data/<digest>/` in the Atlas Live data tree)", ""}, files
        })) + "\n"
    }

    def familyLabel(clustering: Families.Cluster.Clustering, family: Int32): String =
        Vector.nth(family, clustering#families)
            |> Option.map(value -> "${family} `${value#name}`")
            |> Option.getWithDefault("${family}")

    def endpoint(world: Repository.World, relation: String, id: Int32): String =
        if (relation == Families.Edge.imports()) Vector.nth(id, world#files) |> Option.getWithDefault("${id}")
        else Vector.nth(id, world#symbols) |> Option.map(s -> "${s#path}#${s#name}") |> Option.getWithDefault("${id}")

    /// Family counts, affinity sources, rollups, and the largest families.
    pub def clustering(values: Vector[Clustered]): String = {
        let counts = Vector.append(Vector#{
            "| repository | snapshot | seeds | candidates | families | members | largest | singletons | held by 2+ frontiers | seed fallback | named by decision |",
            "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
        }, Vector.map(value -> {
            let c = value#clustering;
            let sizes = Vector.map(family -> family#members, c#families);
            "| ${value#repository} | `${shortSnapshot(c#snapshotId)}` | ${value#seeds} | ${value#candidates} | " +
            "${Vector.length(c#families)} | ${Vector.length(c#members)} | ${Vector.foldLeft(Int32.max, 0, sizes)} | " +
            "${Vector.count(size -> size == 1, sizes)} | ${Vector.count(member -> member#candidates >= 2, c#members)} | " +
            "${Vector.count(member -> member#candidates == 0, c#members)} | ${Vector.count(family -> family#named, c#families)} |"
        }, values));
        let sources = Vector.append(Vector#{
            "| repository | mean structural | mean semantic | moved without semantic | moved without structure |",
            "|---|---:|---:|---:|---:|"
        }, Vector.map(value -> {
            let members = value#clustering#members;
            let mean = f -> if (Vector.isEmpty(members)) 0.0
                else Vector.foldLeft((sum, member) -> sum + f(member), 0.0, members) / Int32.toFloat64(Vector.length(members));
            "| ${value#repository} | ${decimal(mean(member -> member#structural), 6)} | ${decimal(mean(member -> member#semantic), 6)} | " +
            "${value#structuralOnly} | ${value#semanticOnly} |"
        }, values));
        let rollup = Vector.append(Vector#{
            "| repository | files | files split across families | directories | directories with one family |",
            "|---|---:|---:|---:|---:|"
        }, Vector.map(value -> {
            let rows = level -> Vector.filter(row -> row#level == level, value#clustering#rollups);
            let locations = level -> Vector.map(row -> row#locationId, rows(level)) |> Vector.toSet |> Set.size;
            let whole = level -> Vector.count(row -> row#dominant and row#members == row#locationMembers, rows(level));
            let files = Families.Rollup.fileLevel();
            let directories = Families.Rollup.directoryLevel();
            "| ${value#repository} | ${locations(files)} | ${locations(files) - whole(files)} | " +
            "${locations(directories)} | ${whole(directories)} |"
        }, values));
        let largest = Vector.append(Vector#{
            "| repository | family | name | kind | members | files | seeds | name provenance |",
            "|---|---:|---|---|---:|---:|---:|---|"
        }, Vector.flatMap(value -> value#clustering#families
            |> Vector.sortBy(family -> (0 - family#members, family#family))
            |> Vector.take(8)
            |> Vector.map(family ->
                "| ${value#repository} | ${family#family} | `${family#name}` | ${family#nameKind} | ${family#members} | " +
                "${family#files} | ${Vector.length(family#seedFiles)} | " +
                "${family#nameDecision |> Option.map(id -> "decision `${shortSnapshot(id)}`") |> Option.getWithDefault("single location")} |"),
            values));
        Vector.join("\n", Vector.flatten(Vector#{
            Vector#{"**Families**", ""}, counts,
            Vector#{"", "**Affinity sources** (per member, weighted; ablations count members whose family changes)", ""}, sources,
            Vector#{"", "**Rollup**", ""}, rollup,
            Vector#{"", "**Largest families**", ""}, largest
        })) + "\n"
    }
}
