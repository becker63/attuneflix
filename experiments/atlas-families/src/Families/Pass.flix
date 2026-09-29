/// One families acquisition pass over one admitted world, and its keyless
/// replay. Both run the same pipeline: embed the recorded documents, navigate
/// every seed, and project six typed tables. They differ only in how a store
/// miss is served, so replay proves the recorded tables are a function of the
/// retained raw evidence, the protocol, and the world alone.
pub mod Families.Pass {
    use Families.Provider.Transport

    pub type alias Subject = {
        identity = Repository.Table.Identity,
        world    = Repository.World
    }

    /// The per-world directories of the two evidence spaces.
    pub type alias Roots = {
        embeddings = String,
        decisions  = String
    }

    pub type alias Tables = Map[String, Vector[ScientificTable.Row]]

    pub type alias Run = {
        tables    = Tables,
        embedding = Families.Provider.Stats,
        decision  = Families.Provider.Stats
    }

    /// Every recorded table: its name, its file under the space roots, and its schema.
    pub def layout(roots: Roots): Vector[(String, String, ScientificTable.Schema)] = Vector#{
        ("embedding-documents", "${roots#embeddings}/documents.parquet", Families.Embedding.Table.documents()),
        ("embedding-batches", "${roots#embeddings}/batches.parquet", Families.Embedding.Table.batches()),
        ("embedding-ledger", "${roots#embeddings}/ledger.parquet", Families.Ledger.schema()),
        ("decisions", "${roots#decisions}/decisions.parquet", Families.Decision.Table.decisions()),
        ("family-outcomes", "${roots#decisions}/outcomes.parquet", Families.Decision.Table.outcomes()),
        ("decision-ledger", "${roots#decisions}/ledger.parquet", Families.Ledger.schema())
    }

    /// The pre-acquisition upper bound for one world's pass.
    pub def projectedUsd(world: Repository.World, documents: Vector[Families.Embedding.Document]): Float64 \ IO =
        Families.Protocol.projectedEmbeddingUsd(Families.Ledger.documentBytes(documents)) +
        Families.Protocol.projectedDecisionUsd(Vector.length(Families.Navigation.seeds(world)))

    /// The live pass. It stops before any provider call when the projection
    /// exceeds the envelope, and the handler stops before any call once the
    /// measured spend reaches it. Tables are retained only after the whole
    /// pass is admitted; raw exchanges are retained as they arrive.
    pub def acquire(subject: Subject, sourceRoot: String, roots: Roots, transport: Transport): Result[String, Run] \ IO = forM (
        documents <- Families.Embedding.documents(subject#world, sourceRoot);
        projected = projectedUsd(subject#world, documents);
        _ <- if (projected <= Families.Protocol.envelopeUsd()) Ok(())
             else Err("projected pass cost ${projected} USD exceeds the ${Families.Protocol.envelopeUsd()} USD envelope");
        passed <- derive(subject, documents, roots, transport);
        _ <- Vector.traverse(match (name, path, schema) ->
            Families.Rows.retain(path, schema, Map.getWithDefault(name, Vector.empty(), passed#tables)), layout(roots))
    ) yield passed

    /// Record the immutable embedding batches in one bounded pass. No typed
    /// table is written until all decision ranges have also been recorded.
    pub def prefillEmbeddings(subject: Subject, sourceRoot: String, roots: Roots, transport: Transport): Result[String, (Families.Provider.Stats, Float64)] \ IO = forM (
        documents <- Families.Embedding.documents(subject#world, sourceRoot);
        bound = Families.Protocol.projectedEmbeddingUsd(Families.Ledger.documentBytes(documents));
        _ <- if (bound <= Families.Protocol.envelopeUsd()) Ok(())
             else Err("embedding pass bound ${bound} USD exceeds the ${Families.Protocol.envelopeUsd()} USD envelope");
        (result, stats) = Families.Provider.serve(
            roots#embeddings, Families.Protocol.embeddings(), transport, Families.Protocol.envelopeUsd(),
            () -> embed(documents));
        observations <- result;
        reported = Families.Ledger.embeddings(documents, observations, Families.Protocol.envelopeUsd())#costUsd
    ) yield (stats, reported)

    /// Record one range without renumbering its seeds. At most 3,000 seeds
    /// make at most 24,000 decisions, conservatively bounded at $4.80.
    pub def prefillDecisions(subject: Subject, roots: Roots, start: Int32, count: Int32, transport: Transport): Result[String, (Families.Provider.Stats, Float64)] \ IO = {
        let total = Vector.length(Families.Navigation.seeds(subject#world));
        let admitted = Int32.min(count, total - start);
        let bound = Families.Protocol.projectedDecisionUsd(admitted);
        forM (
            _ <- if (start >= 0 and start < total and count > 0 and count <= Families.Protocol.boundedSeedsPerPass() and
                     bound <= Families.Protocol.envelopeUsd()) Ok(())
                 else Err("decision range or ${bound} USD bound exceeds the approved pass");
            context = {
                snapshotId = subject#identity#snapshotId,
                repository = subject#identity#repository,
                world = subject#world
            };
            (result, stats) = Families.Provider.serve(
                roots#decisions, Families.Protocol.decisions(), transport, Families.Protocol.envelopeUsd(),
                () -> Families.Navigation.navigateRange(context, start, count));
            outcomes <- result;
            observations = Vector.flatMap(outcome -> outcome#records, outcomes)
                |> Vector.map(record -> record#observation);
            reported = Families.Ledger.decisions(admitted, observations, Families.Protocol.envelopeUsd())#costUsd
        ) yield (stats, reported)
    }

    /// Build the same six whole-world typed tables from a fully recorded
    /// space. Any missing request fails before a table is retained.
    pub def materialize(subject: Subject, sourceRoot: String, roots: Roots): Result[String, Run] \ IO = forM (
        documents <- Families.Embedding.documents(subject#world, sourceRoot);
        passed <- derive(subject, documents, roots, Transport.Refuse);
        _ <- Vector.traverse(match (name, path, schema) ->
            Families.Rows.retain(path, schema, Map.getWithDefault(name, Vector.empty(), passed#tables)), layout(roots))
    ) yield passed

    /// Keyless replay over the recorded space: every recorded table is decoded
    /// under its schema, the recorded documents are verified against the world,
    /// and the pipeline is run with no transport at all.
    pub def replay(subject: Subject, roots: Roots): Result[String, Families.Replay.Proof] \ IO = {
        let snapshotId = subject#identity#snapshotId;
        let keyAbsent = Families.Provider.keyAbsent();
        let recorded = Vector.map(match (name, path, schema) -> (name, ScientificTable.read(path, schema)), layout(roots)) |> Vector.toMap;
        let table = name -> Map.getWithDefault(name, Vector.empty(), recorded);
        forM (
            _ <- if (keyAbsent) Ok(()) else Err("keyless replay found a provider key in the environment");
            documents <- Families.Embedding.Table.decodeDocuments(snapshotId, table("embedding-documents"));
            _ <- Families.Embedding.verify(subject#world, documents);
            _ <- Families.Embedding.Table.decodeBatches(snapshotId, table("embedding-batches"));
            embeddingLedger <- Families.Ledger.decode(snapshotId, table("embedding-ledger"));
            _ <- Families.Decision.Table.decodeDecisions(snapshotId, table("decisions"));
            _ <- Families.Decision.Table.decodeOutcomes(snapshotId, table("family-outcomes"));
            decisionLedger <- Families.Ledger.decode(snapshotId, table("decision-ledger"));
            envelope = embeddingLedger#envelopeUsd;
            _ <- if (envelope == decisionLedger#envelopeUsd and
                (envelope == Families.Protocol.envelopeUsd() or
                 (snapshotId == Families.Protocol.legacySnapshotId() and
                  envelope == Families.Protocol.legacyEnvelopeUsd())))
                Ok(()) else Err("recorded pass envelope is not the approved cap for this snapshot");
            passed <- deriveAt(subject, documents, roots, Transport.Refuse, envelope)
        ) yield {
            snapshotId = snapshotId,
            checks = Vector.map(match (name, _, schema) ->
                Families.Replay.check(name, schema, table(name), Map.getWithDefault(name, Vector.empty(), passed#tables)), layout(roots)),
            retained = Families.Evidence.retained(roots#embeddings) + Families.Evidence.retained(roots#decisions),
            served = passed#embedding#recorded + passed#decision#recorded,
            providerCalls = passed#embedding#acquired + passed#decision#acquired,
            keyAbsent = keyAbsent
        }
    }

    /// The shared pipeline: the six tables and the provider statistics of one
    /// pass over fixed documents under one transport.
    pub def derive(subject: Subject, documents: Vector[Families.Embedding.Document], roots: Roots, transport: Transport): Result[String, Run] \ IO = {
        deriveAt(subject, documents, roots, transport, Families.Protocol.envelopeUsd())
    }

    def deriveAt(subject: Subject, documents: Vector[Families.Embedding.Document], roots: Roots, transport: Transport, envelope: Float64): Result[String, Run] \ IO = {
        let (embedded, embedding) = Families.Provider.serve(
            roots#embeddings, Families.Protocol.embeddings(), transport, envelope, () -> embed(documents));
        match embedded {
            case Err(error) => Err(error)
            case Ok(observations) => {
                let context = {
                    snapshotId = subject#identity#snapshotId,
                    repository = subject#identity#repository,
                    world = subject#world
                };
                let (navigated, decision) = Families.Provider.serve(
                    roots#decisions, Families.Protocol.decisions(), transport, envelope - embedding#spentUsd,
                    () -> Families.Navigation.navigateAll(context));
                forM (
                    outcomes <- navigated;
                    tables0 <- tables(subject, documents, observations, outcomes, envelope)
                ) yield {tables = tables0, embedding = embedding, decision = decision}
            }
        }
    }

    def embed(documents: Vector[Families.Embedding.Document]): Result[String, Vector[Families.Embedding.Observation]] \ {Families.Provider.Provider, IO} =
        Vector.traverse(batch -> Families.Provider.exchange(batch#request) |> Result.flatMap(Families.Embedding.admit(batch)),
            Families.Embedding.batches(documents))

    def tables(
        subject: Subject,
        documents: Vector[Families.Embedding.Document],
        observations: Vector[Families.Embedding.Observation],
        outcomes: Vector[Families.Navigation.Outcome],
        envelope: Float64
    ): Result[String, Tables] \ IO = {
        let snapshotId = subject#identity#snapshotId;
        let entries = Vector.flatMap(Families.Decision.Table.entries, outcomes);
        Ok(Map#{
            "embedding-documents" => Vector.map(Families.Embedding.Table.documentRow(snapshotId), documents),
            "embedding-batches" => Vector.map(Families.Embedding.Table.batchRow(snapshotId), observations),
            "embedding-ledger" => Vector#{Families.Ledger.row(snapshotId, Families.Ledger.embeddings(documents, observations, envelope))},
            "decisions" => Vector.map(Families.Decision.Table.decisionRow(snapshotId), entries),
            "family-outcomes" => Vector.map(outcome ->
                Families.Decision.Table.outcomeRow(snapshotId, Families.Decision.Table.family(subject#world, outcome)), outcomes),
            "decision-ledger" => Vector#{Families.Ledger.row(snapshotId,
                Families.Ledger.decisions(Vector.length(outcomes), Vector.map(entry -> entry#observation, entries), envelope))}
        })
    }
}
