/// The recorded families evidence of one world, as the clustering method
/// reads it: the typed decision and embedding tables of both acquisition
/// spaces, and the recorded vectors decoded from the retained raw batch bodies.
/// Nothing here can reach a provider; a missing exchange is an error.
pub mod Families.Recorded {
    /// Every typed table the method reads, decoded under its schema, with the
    /// recorded documents verified against the world.
    pub def read(subject: Families.Pass.Subject, roots: Families.Pass.Roots): Result[String, Families.Cluster.Evidence] \ IO = {
        let snapshotId = subject#identity#snapshotId;
        let table = name -> Vector.find(match (known, _, _) -> known == name, Families.Pass.layout(roots))
            |> Option.map(match (_, path, schema) -> ScientificTable.read(path, schema))
            |> Option.getWithDefault(Vector.empty());
        forM (
            documents <- Families.Embedding.Table.decodeDocuments(snapshotId, table("embedding-documents"));
            observations <- Families.Embedding.Table.decodeBatches(snapshotId, table("embedding-batches"));
            decisions <- Families.Decision.Table.decodeDecisions(snapshotId, table("decisions"));
            outcomes <- Families.Decision.Table.decodeOutcomes(snapshotId, table("family-outcomes"));
            evidence0 <- evidence(subject#world, roots#embeddings, documents, observations, outcomes, decisions)
        ) yield evidence0
    }

    pub def evidence(
        world: Repository.World,
        embeddingsRoot: String,
        documents: Vector[Families.Embedding.Document],
        observations: Vector[Families.Embedding.Observation],
        outcomes: Vector[Families.Decision.Table.Family],
        decisions: Vector[Families.Decision.Table.Entry]
    ): Result[String, Families.Cluster.Evidence] \ IO = forM (
        _ <- Families.Embedding.verify(world, documents);
        vectors0 <- vectors(embeddingsRoot, documents, observations)
    ) yield {outcomes = outcomes, decisions = decisions, vectors = vectors0}

    /// One recorded vector per document, in document (symbol) order. Each
    /// batch must be the recorded request for its documents, and each decoded
    /// vector must carry the digest the batch table admitted for it.
    pub def vectors(
        root: String,
        documents: Vector[Families.Embedding.Document],
        observations: Vector[Families.Embedding.Observation]
    ): Result[String, Vector[Vector[Float32]]] \ IO = {
        let batches = Families.Embedding.batches(documents);
        if (Vector.length(batches) != Vector.length(observations))
            Err("${Vector.length(batches)} document batches but ${Vector.length(observations)} recorded batch rows")
        else Vector.traverse(match (batch, observation) -> forM (
            _ <- if (batch#request#identity == observation#identity) Ok(())
                 else Err("batch ${batch#ordinal} is not the recorded request ${observation#identity}");
            retained <- Families.Evidence.read(root, Families.Protocol.embeddings(), observation#identity);
            exchange <- Option.toOk("batch ${batch#ordinal} has no retained exchange", retained);
            _ <- if (exchange#request == batch#request#payload) Ok(())
                 else Err("retained batch ${batch#ordinal} request differs from its documents");
            decoded <- Families.Embedding.vectors(batch, exchange#response);
            _ <- if (Vector.map(Families.Embedding.digest, decoded) == observation#vectors) Ok(())
                 else Err("batch ${batch#ordinal} vectors differ from their admitted digests")
        ) yield decoded, Vector.zip(batches, observations)) |> Result.map(Vector.flatten)
    }
}
