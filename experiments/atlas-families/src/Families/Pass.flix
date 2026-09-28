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
            _ <- Families.Ledger.decode(snapshotId, table("embedding-ledger"));
            _ <- Families.Decision.Table.decodeDecisions(snapshotId, table("decisions"));
            _ <- Families.Decision.Table.decodeOutcomes(snapshotId, table("family-outcomes"));
            _ <- Families.Ledger.decode(snapshotId, table("decision-ledger"));
            passed <- derive(subject, documents, roots, Transport.Refuse)
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
        let envelope = Families.Protocol.envelopeUsd();
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
                    tables0 <- tables(subject, documents, observations, outcomes)
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
        outcomes: Vector[Families.Navigation.Outcome]
    ): Result[String, Tables] \ IO = {
        let snapshotId = subject#identity#snapshotId;
        let entries = Vector.flatMap(Families.Decision.Table.entries, outcomes);
        Ok(Map#{
            "embedding-documents" => Vector.map(Families.Embedding.Table.documentRow(snapshotId), documents),
            "embedding-batches" => Vector.map(Families.Embedding.Table.batchRow(snapshotId), observations),
            "embedding-ledger" => Vector#{Families.Ledger.row(snapshotId, Families.Ledger.embeddings(documents, observations))},
            "decisions" => Vector.map(Families.Decision.Table.decisionRow(snapshotId), entries),
            "family-outcomes" => Vector.map(outcome ->
                Families.Decision.Table.outcomeRow(snapshotId, Families.Decision.Table.family(subject#world, outcome)), outcomes),
            "decision-ledger" => Vector#{Families.Ledger.row(snapshotId,
                Families.Ledger.decisions(Vector.length(outcomes), Vector.map(entry -> entry#observation, entries)))}
        })
    }
}
