/// Law tests for the families acquisition protocol, run against an in-process
/// simulated provider so no law needs a key or a network: acquire once, then
/// serve from content-addressed evidence; keyless replay reproduces every
/// table exactly; every provider payload is issue-blind structure or an exact
/// document; every typed table round-trips exactly.
mod FamiliesAcquisitionTest {
    import java.nio.{ByteBuffer, ByteOrder}
    import java.nio.file.{Files, Path, Paths}
    import java.util.Base64

    use Families.Provider.Transport
    use ScientificTable.Value
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.ToJson

    def snapshot(): String = "repository-snapshot-v1:abcdef0123456789"

    def subject(): Families.Pass.Subject = {
        identity = FamiliesTest.identity(snapshot(), "owner/nested"),
        world = FamiliesTest.nestedWorld(FamiliesTest.fullCalls())
    }

    /// Source bytes whose spans are exactly the nested world's callables.
    def sourceRoot(): String \ IO = {
        let root = Files.createTempDirectory("families-source");
        let put = (path, text) -> {
            let file = root.resolve(path);
            let _ = Files.createDirectories(file.getParent());
            let _ = Files.writeString(file, text);
            ()
        };
        put("index.ts", "main();\n");
        put("src/a.ts", "alpha() {}");
        put("src/lib/b.ts", "/* */beta = () => 1 + 22;\n");
        root.toString()
    }

    def roots(): Families.Pass.Roots \ IO = {
        let root = Files.createTempDirectory("families-evidence").toString();
        {embeddings = "${root}/embeddings", decisions = "${root}/decisions"}
    }

    def documents(): Vector[Families.Embedding.Document] \ IO =
        Families.Embedding.documents(subject()#world, sourceRoot()) |> Result.getWithDefault(Vector.empty())

    /// One base64 little-endian float32 vector per ordinal, as the provider sends it.
    def vector(ordinal: Int32): String \ IO = {
        let buffer = ByteBuffer.allocate(4 * Families.Protocol.dimension()).order(ByteOrder.LITTLE_ENDIAN);
        let _ = buffer.putFloat(0, Int32.toFloat32(ordinal + 1));
        Base64.getEncoder().encodeToString(buffer.array())
    }

    def usage(tokens: Int32, cost: Float64): Json = JObject(Map#{
        "prompt_tokens" => ToJson.toJson(tokens), "input_tokens" => ToJson.toJson(tokens),
        "output_tokens" => ToJson.toJson(1), "total_tokens" => ToJson.toJson(tokens), "cost" => ToJson.toJson(cost)
    })

    /// A deterministic stand-in for both providers: embeddings return one
    /// vector per input; Jev grows through `defines` then `calls`, stops
    /// otherwise, and always takes the first name. On the nested world that
    /// is 4 + 1, 3 + 1, and 2 + 1 decisions for the three seeds.
    def simulated(): Transport \ IO = {
        let vectors = Vector.map(vector, Vector.range(0, Families.Protocol.batchSize()));
        Transport.Simulated(request -> match request#kind {
            case Families.Provider.Kind.EmbeddingBatch => Json.toCompactString(JObject(Map#{
                "object" => JString("list"), "model" => JString("Qwen/Qwen3-Embedding-8B"), "provider" => JString("DeepInfra"),
                "id" => JString("gen-emb-simulated"), "usage" => usage(Vector.length(request#inputs) * 7, 0.000001),
                "data" => JArray(Vector.mapWithIndex((index, _) -> JObject(Map#{
                    "object" => JString("embedding"), "index" => ToJson.toJson(index),
                    "embedding" => JString(Vector.get(index, vectors))
                }), request#inputs))
            }))
            case Families.Provider.Kind.Decision => jev(request#payload)
        })
    }

    def jev(payload: String): String = {
        let (question, keys) = offered(payload);
        let choice = if (Vector.memberOf("defines", keys)) "defines"
            else if (Vector.memberOf("calls", keys)) "calls"
            else if (Vector.memberOf("stop", keys)) "stop"
            else Vector.head(keys) |> Option.getWithDefault("stop");
        let choice0 = if (Vector.memberOf("name_0", keys)) "name_0" else choice;
        Json.toCompactString(JObject(Map#{
            "model" => JString("typesafe/jev-1.13-20260917"), "provider" => JString("TypeSafe"),
            "id" => JString("gen-dec-simulated-${String.length(payload)}"), "usage" => usage(100, 0.00005),
            "answers" => JObject(Map#{question => JObject(Map#{
                "type" => JString("choice"), "choice" => JString(choice0), "confidence" => ToJson.toJson(0.75),
                "probabilities" => JObject(Vector.map(key ->
                    (key, ToJson.toJson(if (key == choice0) 0.75 else 0.25)), keys) |> Vector.toMap)
            })})
        }))
    }

    /// The question key and the alternative keys of a decision payload.
    def offered(payload: String): (String, Vector[String]) = match Json.parse(payload) {
        case Ok(JObject(fields)) => match Map.get("questions", fields) {
            case Some(JObject(questions)) => match Map.toVector(questions) |> Vector.head {
                case Some((question, JObject(body))) => match Map.get("criteria", body) {
                    case Some(JObject(criteria)) => (question, Map.keysOf(criteria) |> Set.toVector)
                    case _ => (question, Vector.empty())
                }
                case _ => ("", Vector.empty())
            }
            case _ => ("", Vector.empty())
        }
        case _ => ("", Vector.empty())
    }

    def retainedRequests(root: String): Vector[String] \ IO = {
        let directory = Paths.get("${root}/raw").toFile();
        Array.toVector(directory.listFiles()) |> Vector.map(file ->
            Families.Evidence.decode(Families.Protocol.decisions(), Files.readString(file.toPath()))
                |> Result.map(exchange -> exchange#request) |> Result.getWithDefault(""))
    }

    /// (embedding acquisitions, decision acquisitions, store hits) of one pass.
    def calls(result: Result[String, Families.Pass.Run]): Result[String, (Int32, Int32, Int32)] =
        Result.map(value -> (value#embedding#acquired, value#decision#acquired, value#embedding#recorded + value#decision#recorded), result)

    def tablesOf(result: Result[String, Families.Pass.Run]): Result[String, Families.Pass.Tables] =
        Result.map(value -> value#tables, result)

    @Test
    def documentsFollowTheFrozenRecipeWithNoQuerySide(): Unit \ {Assert, IO} = {
        let values = documents();
        Assert.assertEq(expected = Vector#{"index.ts:main\nmain", "src/a.ts:alpha\nalpha() {}", "src/lib/b.ts:beta\nbeta = () => 1 + 22;"},
            Vector.map(value -> value#text, values));
        Assert.assertEq(expected = Ok(()), Families.Embedding.verify(subject()#world, values));
        let batch = Families.Embedding.batches(values);
        Assert.assertEq(expected = 1, Vector.length(batch));
        Assert.assertEq(expected = Ok(JObject(Map#{
            "model" => JString("qwen/qwen3-embedding-8b"),
            "input" => JArray(Vector.map(value -> JString(value#text), values)),
            "encoding_format" => JString("base64")
        })), Json.parse(Vector.get(0, batch)#request#payload) |> Result.mapErr(ToString.toString))
    }

    @Test
    def documentsAreCutAtTheFrozenCodePointLimit(): Unit \ {Assert, IO} = {
        let (text, truncated) = Families.Embedding.text("a.ts:f", String.repeat(50000, "\uD83D\uDE00"));
        Assert.assertTrue(truncated);
        Assert.assertEq(expected = Families.Protocol.textLimit(), text.codePointCount(0, String.length(text)));
        Assert.assertEq(expected = ("a.ts:f\nbody", false), Families.Embedding.text("a.ts:f", "body"))
    }

    @Test
    def aSpanOutsideTheSourceRootIsRejected(): Unit \ {Assert, IO} = {
        let world = subject()#world;
        let moved = {symbols = Vector.map(symbol -> {endByte = symbol#endByte + 1000 | symbol}, world#symbols) | world};
        Assert.assertTrue(Result.isErr(Families.Embedding.documents(moved, sourceRoot())))
    }

    @Test
    def navigationOffersOnlyTheFrontierDomainsAtoms(): Unit \ Assert = {
        let world = subject()#world;
        let seed = Atlas.State.Files(Set#{FamiliesTest.file(0)});
        let fromFile = Families.Navigation.children(world, seed) |> Result.getWithDefault(Vector.empty());
        Assert.assertEq(expected = Vector#{Atlas.Atom.Defines, Atlas.Atom.Imports}, Vector.map(fst, fromFile));
        let fromSymbol = Families.Navigation.children(world, Atlas.State.Symbols(Set#{FamiliesTest.symbol(0)}))
            |> Result.getWithDefault(Vector.empty());
        Assert.assertEq(expected = Vector#{Atlas.Atom.DefinedIn, Atlas.Atom.Calls}, Vector.map(fst, fromSymbol))
    }

    @Test
    def acquisitionHappensOnceThenEveryRequestIsServedFromEvidence(): Unit \ {Assert, IO} = {
        let values = documents();
        let evidence = roots();
        let first = Families.Pass.derive(subject(), values, evidence, simulated());
        let second = Families.Pass.derive(subject(), values, evidence, simulated());
        let replayed = Families.Pass.derive(subject(), values, evidence, Transport.Refuse);
        Assert.assertEq(expected = Ok((1, 12, 0)), calls(first));
        Assert.assertEq(expected = Ok((0, 0, 13)), calls(second));
        Assert.assertEq(expected = Ok((0, 0, 13)), calls(replayed));
        Assert.assertEq(expected = 13, Families.Evidence.retained(evidence#embeddings) + Families.Evidence.retained(evidence#decisions));
        Assert.assertEq(expected = tablesOf(first), tablesOf(replayed));
        Assert.assertEq(expected = tablesOf(first), tablesOf(second))
    }

    @Test
    def keylessReplayRefusesAMissAndTheEnvelopeStopsLiveCalls(): Unit \ {Assert, IO} = {
        let values = documents();
        Assert.assertTrue(Families.Provider.keyAbsent());
        Assert.assertTrue(Result.isErr(Families.Pass.derive(subject(), values, roots(), Transport.Refuse)));
        let batch = Vector.get(0, Families.Embedding.batches(values));
        let (stopped, stats) = Families.Provider.serve(roots()#embeddings, Families.Protocol.embeddings(), simulated(), 0.0,
            () -> Families.Provider.exchange(batch#request));
        Assert.assertTrue(Result.isErr(stopped));
        Assert.assertEq(expected = 0, stats#acquired)
    }

    @Test
    def retainedEvidenceIsContentAddressedAndNeverReplaced(): Unit \ {Assert, IO} = {
        let evidence = roots();
        let identity = Families.Evidence.identity("p", Vector#{"a", "bc"});
        Assert.assertTrue(identity != Families.Evidence.identity("p", Vector#{"ab", "c"}));
        Assert.assertEq(expected = identity, Families.Evidence.identity("p", Vector#{"a", "bc"}));
        let digest = String.sliceRight(start = 2, identity);
        Assert.assertEq(expected = "${evidence#decisions}/raw/${digest}.json", Families.Evidence.path(evidence#decisions, identity));
        let exchange = {identity = identity, request = "{}", response = "{\"ok\":true}"};
        Assert.assertEq(expected = Ok(()), Families.Evidence.write(evidence#decisions, "p", exchange));
        Assert.assertTrue(Result.isErr(Families.Evidence.write(evidence#decisions, "p", {response = "{}" | exchange})));
        Assert.assertEq(expected = Ok(Some("{\"ok\":true}")),
            Families.Evidence.read(evidence#decisions, "p", identity) |> Result.map(Option.map(value -> value#response)))
    }

    @Test
    def aRetainedExchangeForADifferentRequestIsRejected(): Unit \ {Assert, IO} = {
        let values = documents();
        let evidence = roots();
        let batch = Vector.get(0, Families.Embedding.batches(values));
        let forged = {identity = batch#request#identity, request = "{\"input\":[\"issue text\"]}", response = "{}"};
        let _ = Families.Evidence.write(evidence#embeddings, Families.Protocol.embeddings(), forged);
        let (served, _) = Families.Provider.serve(evidence#embeddings, Families.Protocol.embeddings(), Transport.Refuse, 0.0,
            () -> Families.Provider.exchange(batch#request));
        Assert.assertTrue(Result.isErr(served))
    }

    /// Every retained decision request is exactly {model, state, questions};
    /// the state is the fixed seven-line structure and names only paths,
    /// callables, domains, and cardinalities.
    @Test
    def everyDecisionPayloadIsIssueBlindStructure(): Unit \ {Assert, IO} = {
        let evidence = roots();
        let _ = Families.Pass.derive(subject(), documents(), evidence, simulated());
        let requests = retainedRequests(evidence#decisions);
        Assert.assertEq(expected = 12, Vector.length(requests));
        let prefixes = Vector#{"ATTUNE_FAMILIES_STATE_V1", "objective: family-formation", "repository: owner/nested",
            "seed: domain=file", "depth: ", "path: ", "current: domain="};
        Vector.forEach(request -> match Json.parse(request) {
            case Ok(JObject(fields)) => {
                Assert.assertEq(expected = Set#{"model", "state", "questions"}, Map.keysOf(fields));
                match Map.get("state", fields) {
                    case Some(JString(state)) => {
                        let lines = String.split(regex = "\n", state) |> List.toVector;
                        Assert.assertEq(expected = Vector.length(prefixes), Vector.length(lines));
                        Vector.forEach(match (prefix, line) -> Assert.assertTrue(String.startsWith(prefix = prefix, line)),
                            Vector.zip(prefixes, lines))
                    }
                    case _ => Assert.fail("decision state must be text")
                }
            }
            case _ => Assert.fail("decision payload must be an object")
        }, requests);
        Vector.forEach(request -> Vector.forEach(marker ->
            Assert.assertFalse(String.contains(substr = marker, String.toLowerCase(request))),
            Vector#{"issue", "problem_statement", "gold", "instance_id", "hints_text", "fail_to_pass", "alpha() {}"}), requests)
    }

    @Test
    def everyTypedTableRoundTripsExactlyAndRejectsAForeignWorld(): Unit \ {Assert, IO} = {
        let tables = tablesOf(Families.Pass.derive(subject(), documents(), roots(), simulated())) |> Result.getWithDefault(Map.empty());
        let table = name -> Map.getWithDefault(name, Vector.empty(), tables);
        let s = snapshot();
        Assert.assertEq(expected = Ok(table("embedding-documents")), Families.Embedding.Table.decodeDocuments(s, table("embedding-documents"))
            |> Result.map(Vector.map(Families.Embedding.Table.documentRow(s))));
        Assert.assertEq(expected = Ok(table("embedding-batches")), Families.Embedding.Table.decodeBatches(s, table("embedding-batches"))
            |> Result.map(Vector.map(Families.Embedding.Table.batchRow(s))));
        Assert.assertEq(expected = Ok(table("decisions")), Families.Decision.Table.decodeDecisions(s, table("decisions"))
            |> Result.map(Vector.map(Families.Decision.Table.decisionRow(s))));
        Assert.assertEq(expected = Ok(table("family-outcomes")), Families.Decision.Table.decodeOutcomes(s, table("family-outcomes"))
            |> Result.map(Vector.map(Families.Decision.Table.outcomeRow(s))));
        Vector.forEach(name -> Assert.assertEq(expected = Ok(table(name)),
            Families.Ledger.decode(s, table(name)) |> Result.map(entry -> Vector#{Families.Ledger.row(s, entry)})),
            Vector#{"embedding-ledger", "decision-ledger"});
        Vector.forEach(match (name, _, schema) -> {
            Assert.assertEq(expected = Vector.map(column -> column#name, schema#columns) |> Vector.toSet,
                Vector.head(table(name)) |> Option.map(Map.keysOf) |> Option.getWithDefault(Set.empty()));
            Assert.assertTrue(Vector.forAll(row -> Map.get("protocol", row) == Some(Value.Text(schema#format)), table(name)))
        }, Families.Pass.layout({embeddings = "e", decisions = "d"}));
        Assert.assertTrue(Result.isErr(Families.Embedding.Table.decodeDocuments("repository-snapshot-v1:other", table("embedding-documents"))));
        Assert.assertTrue(Result.isErr(Families.Ledger.decode(s, Vector.append(table("decision-ledger"), table("decision-ledger")))))
    }

    @Test
    def theLedgerSumsTheProviderReportedUsage(): Unit \ {Assert, IO} = {
        let tables = tablesOf(Families.Pass.derive(subject(), documents(), roots(), simulated())) |> Result.getWithDefault(Map.empty());
        let decisions = Families.Ledger.decode(snapshot(), Map.getWithDefault("decision-ledger", Vector.empty(), tables));
        Assert.assertEq(expected = Ok((12, 12, 1200i64, 12i64)),
            decisions |> Result.map(entry -> (entry#requests, entry#reported, entry#inputTokens, entry#outputTokens)));
        Assert.assertTrue(decisions |> Result.map(entry -> Float64.abs(entry#costUsd - 0.0006) < 1.0e-12) |> Result.getWithDefault(false));
        Assert.assertEq(expected = Ok(Families.Protocol.projectedDecisionUsd(3)),
            decisions |> Result.map(entry -> entry#projectedUsd))
    }

    @Test
    def theReplayProofIsExactOnlyWhenEveryTableMatchesKeylessly(): Unit \ {Assert, IO} = {
        let check = Families.Replay.check("t", Families.Ledger.schema(), Vector.empty(), Vector.empty());
        let proof = {snapshotId = snapshot(), checks = Vector#{check}, retained = 2, served = 2, providerCalls = 0, keyAbsent = true};
        Assert.assertTrue(Families.Replay.exact(proof));
        Assert.assertFalse(Families.Replay.exact({providerCalls = 1 | proof}));
        Assert.assertFalse(Families.Replay.exact({keyAbsent = false | proof}));
        Assert.assertFalse(Families.Replay.exact({served = 1 | proof}));
        Assert.assertFalse(Families.Replay.exact({checks = Vector#{{replayed = "other" | check}} | proof}));
        Assert.assertEq(expected = Ok(Families.Replay.rows(proof)),
            Families.Replay.decode(snapshot(), Families.Replay.rows(proof)) |> Result.map(Families.Replay.rows))
    }
}
