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
            "| repository | space | request | requests | cost reported | input tokens | output tokens | cost USD | unit USD | projected USD |",
            "|---|---|---|---:|---:|---:|---:|---:|---:|---:|"
        }, Vector.map(match (repository, entry) ->
            "| ${repository} | `${entry#space}` | ${entry#kind} | ${entry#requests} | ${entry#reported} | " +
            "${entry#inputTokens} | ${entry#outputTokens} | ${usd(entry#costUsd)} | ${usd(entry#unitCostUsd)} | ${usd(entry#projectedUsd)} |",
            entries)), Vector#{
            "| **total** | | | ${Vector.foldLeft((sum, pair) -> sum + snd(pair)#requests, 0, entries)} | | | | " +
            "${usd(total)} | | ${usd(Vector.foldLeft((sum, pair) -> sum + snd(pair)#projectedUsd, 0.0, entries))} |"
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
        let envelope = "Pass envelope: ${usd(Families.Protocol.envelopeUsd())} USD. Measured total: ${usd(total)} USD.";
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
            ("embedding USD per token", BigDecimal.valueOf(Families.Protocol.embeddingUsdPerToken()).setScale(8, RoundingMode.HALF_EVEN).toPlainString()),
            ("decision USD bound", usd(Families.Protocol.decisionUsdBound()))
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

    def usd(value: Float64): String =
        BigDecimal.valueOf(value).setScale(6, RoundingMode.HALF_EVEN).toPlainString()
}
