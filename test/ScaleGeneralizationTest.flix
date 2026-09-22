mod ScaleGeneralizationTest {
    import java.lang.System

    use Fs.FileSystem
    use Sys.Env
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.ToJson

    enum Error with ToString {
        case File(String),
        case Nix(Repository.Nix.Error),
        case Prepare(Localization.Error),
        case Tree(Localization.Tree.Error),
        case Policy(JevPolicyHillclimb.Error),
        case Replay(String)
    }

    type alias Totals = {
        cases = Int32,
        calls = Int32,
        precomputeNanos = Int64
    }

    /// Gold-sealed Phase B gate. Predictions are fully retained before the
    /// independent evaluator capability is ever introduced.
    @Test
    def frozenGeneralizationGate(): Unit \ {Assert, Env, FileSystem, IO} =
        match Env.getVar("ATTUNE_SCALE_GENERALIZATION_MODE") {
            case None => ()
            case Some("prepare") => require(executeGeneralization(false, false))
            case Some("acquire") => require(executeGeneralization(true, true))
            case Some("replay") => require(executeGeneralization(true, false))
            case Some(mode) => Assert.fail(
                "unknown ATTUNE_SCALE_GENERALIZATION_MODE: ${mode}")
        }

    def executeGeneralization(execute: Bool, acquire: Bool): Result[Error, Unit] \ {FileSystem, IO} = {
        let tree = Localization.Tree.compile();
        println("SCALE_013_TREE routes=${Localization.Tree.routeCount(tree)}" +
            " symbol_routes=${Localization.Tree.symbolRouteCount(tree)}" +
            " nodes=${Radii.Compiled.nodeCount(tree#program)}");
        Repository.Grit.runWithNative(() -> Repository.Nix.runWithNative(() -> forM (
            issues <- Repository.Nix.scaleIssues() |> Result.mapErr(Error.Nix);
            issuePayload <- Repository.Nix.Acquire.readSource(
                Repository.Nix.path(issues#issueFixture)) |> Result.mapErr(Error.Nix);
            totals <- runAt(issuePayload, tree, execute, acquire, 0,
                {cases = 0, calls = 0, precomputeNanos = 0i64})
        ) yield println("SCALE_013 mode=${if (execute) (if (acquire) "acquire" else "replay") else "prepare"}" +
            " cases=${totals#cases} calls=${totals#calls}" +
            " precompute_nanos=${totals#precomputeNanos}")))
    }

    def runAt(
        issuePayload: String,
        tree: Localization.Tree.Tree,
        execute: Bool,
        acquire: Bool,
        index: Int32,
        totals: Totals
    ): Result[Error, Totals] \ {FileSystem, IO, Repository.Grit.Eval, Repository.Nix.Acquire} =
        if (index >= 78) Ok(totals)
        else forM (
            case0 <- Repository.Nix.scaleCase(index) |> Result.mapErr(Error.Nix);
            next <- if (case0#population == "historical-development") Ok(totals)
                else forM (
                    prepared <- Localization.prepareScaleRetained(
                        ".attune/repository-facts-js-ts-scale-v1",
                        case0,
                        issuePayload
                    ) |> Result.mapErr(Error.Prepare);
                    priorPayload <- FileSystem.read(
                        ".attune/semantic-prior-js-ts-scale-v1/rankings/${case0#baseRevision}.json")
                        |> Result.mapErr(error -> Error.File(ToString.toString(error)));
                    prior <- Localization.Tree.decodePrior(prepared#instanceId, priorPayload)
                        |> Result.mapErr(Error.Tree);
                    started = System.nanoTime();
                    computed <- Localization.Tree.compute(prepared, prior, tree)
                        |> Result.mapErr(Error.Tree);
                    elapsed = System.nanoTime() - started;
                    result <- if (not execute) Ok({
                        cases = totals#cases + 1,
                        calls = totals#calls,
                        precomputeNanos = totals#precomputeNanos + elapsed
                    }) else forM (
                        outcome <- JevPolicyHillclimb.frozen013(
                            prepared, prior, computed, acquire) |> Result.mapErr(Error.Policy);
                        payload = encodeOutcome(prepared, outcome);
                        output = ".attune/experiments/swe-explore-js-ts-scale/013-predictions/${case0#baseRevision}.json";
                        _ <- writeOrVerify(output, payload, acquire)
                    ) yield {
                        cases = totals#cases + 1,
                        calls = totals#calls + Vector.length(outcome#decisions),
                        precomputeNanos = totals#precomputeNanos + elapsed
                    };
                    _ = println("SCALE_013_CASE case=${case0#instanceId}" +
                        " mode=${if (execute) (if (acquire) "acquire" else "replay") else "prepare"}" +
                        " states=${computed#evaluation#metrics#statesInterned}" +
                        " memo_entries=${computed#evaluation#metrics#memoEntries}" +
                        " precompute_nanos=${elapsed}");
                    value = result
                ) yield value;
            result <- runAt(issuePayload, tree, execute, acquire, index + 1, next)
        ) yield result

    def encodeOutcome(
        prepared: Localization.Prepared,
        outcome: Localization.Tree.Outcome
    ): String = Json.toCompactString(JObject(Map#{
        "version" => ToJson.toJson(1),
        "condition" => JString("frozen-iteration-013"),
        "instance_id" => JString(prepared#instanceId),
        "repository" => JString(prepared#repository),
        "base_revision" => JString(prepared#baseCommit),
        "path" => JArray(Vector.map(atom ->
            JString(Decide.actionKey(Decide.Action.Follow(atom))), outcome#path)),
        "decision_count" => ToJson.toJson(Vector.length(outcome#decisions)),
        "decisions" => JArray(Vector.map(decisionJson, outcome#decisions)),
        "ranking" => JArray(Vector.map(item -> JString(item#identity), outcome#ranking)),
        "structural_work" => JObject(Map#{
            "states_interned" => ToJson.toJson(outcome#metrics#statesInterned),
            "memo_entries" => ToJson.toJson(outcome#metrics#memoEntries),
            "memo_slots" => ToJson.toJson(outcome#metrics#memoSlots)
        })
    }))

    def decisionJson(observation: Decide.Observation): Json = JObject(Map#{
        "choice" => JString(Decide.actionKey(observation#choice)),
        "choice_index" => ToJson.toJson(observation#choiceIndex),
        "probabilities" => JObject(Map.toVector(observation#probabilities)
            |> Vector.map(match (action, probability) ->
                (Decide.actionKey(action), ToJson.toJson(probability)))
            |> Vector.toMap),
        "confidence" => ToJson.toJson(observation#confidence),
        "provider" => JString(observation#provider),
        "actual_model" => JString(observation#actualModel),
        "response_id" => JString(observation#responseId),
        "input_tokens" => ToJson.toJson(observation#usage#inputTokens),
        "output_tokens" => ToJson.toJson(observation#usage#outputTokens),
        "cost" => ToJson.toJson(observation#usage#cost)
    })

    def writeOrVerify(path: String, payload: String, acquire: Bool): Result[Error, Unit] \ FileSystem =
        if (acquire) {
            let written = run { FileSystem.write(str = payload, path) }
                with FileSystem.withMkParentDirs
                with FileSystem.withAtomicWrite;
            Result.mapErr(error -> Error.File(ToString.toString(error)), written)
        } else FileSystem.read(path)
            |> Result.mapErr(error -> Error.File(ToString.toString(error)))
            |> Result.flatMap(expected -> if (expected == payload) Ok(())
                else Err(Error.Replay(path)))

    def require(result: Result[Error, Unit]): Unit \ Assert = match result {
        case Ok(()) => ()
        case Err(error) => Assert.fail(ToString.toString(error))
    }
}
