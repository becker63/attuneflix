mod DecideTest {
    use Fs.FileSystem

    @Test
    def requestIdentityIncludesExactModelVisibleChoice(): Unit \ Assert = {
        let a = request("first issue", Vector#{callsAlternative()});
        let b = request("first issue", Vector#{callsAlternative()});
        let c = request("different issue", Vector#{callsAlternative()});
        Assert.assertEq(expected = a#decision, b#decision);
        Assert.assertTrue(a#decision != c#decision);
        Assert.assertTrue(not String.isSubmatch(regex = "OPENROUTER_API_KEY", a#payload));
        Assert.assertEq(expected = "typesafe/jev-1.13", Decide.model())
    }

    @Test
    def fixtureAndReplayEliminateChoice(): Unit \ Assert = {
        let request0 = request("issue", Vector#{callsAlternative()});
        let acquired = Decide.runWithFake(0, () -> Decide.policy(request0));
        match acquired {
            case Err(error) => Assert.fail(ToString.toString(error))
            case Ok(observation) => {
                let replayed = Decide.runWithFixture(
                    Map#{request0#decision => observation},
                    () -> Decide.policy(request0)
                );
                match replayed {
                    case Err(error) => Assert.fail(ToString.toString(error))
                    case Ok(value) => Assert.assertEq(expected = observation#choiceIndex, value#choiceIndex)
                }
            }
        }
    }

    @Test
    def replayMissIsExplicit(): Unit \ Assert = {
        let request0 = request("issue", Vector#{callsAlternative()});
        match Decide.runWithReplay(Map.empty(), () -> Decide.policy(request0)) {
            case Err(Decide.Error.MissingReplay(id)) => Assert.assertEq(expected = request0#decision, id)
            case _ => Assert.fail("decision replay miss was not explicit")
        }
    }

    @Test
    def providerResponseAdmissionIsTyped(): Unit \ Assert = {
        let request0 = request("issue", Vector#{callsAlternative(), stopAlternative()});
        let response = "{" +
            "\"answers\":{\"next_action\":{\"type\":\"choice\",\"choice\":\"calls\"," +
            "\"confidence\":0.75,\"probabilities\":{\"calls\":0.75,\"stop\":0.25}}}," +
            "\"id\":\"decision-1\",\"model\":\"typesafe/jev-1.13-20260917\"," +
            "\"provider\":\"openrouter\",\"usage\":{\"cost\":0.001,\"input_tokens\":20,\"output_tokens\":5}}";
        match Decide.decode(request0, Decide.Wire.Wire(response)) {
            case Err(error) => Assert.fail(ToString.toString(error))
            case Ok(observation) => {
                Assert.assertEq(expected = 0, observation#choiceIndex);
                Assert.assertEq(expected = Decide.Action.Follow(Radii.Atom.Calls), observation#choice);
                Assert.assertEq(expected = Some(20), observation#usage#inputTokens)
            }
        }
    }

    @Test
    def malformedAndUnknownProviderChoicesStayTyped(): Unit \ Assert = {
        let request0 = request("issue", Vector#{callsAlternative()});
        match Decide.decode(request0, Decide.Wire.Wire("not json")) {
            case Err(Decide.Error.Wire(_)) => ()
            case _ => Assert.fail("malformed decision response was admitted")
        };
        let response = "{" +
            "\"answers\":{\"next_action\":{\"type\":\"choice\",\"choice\":\"imports\"," +
            "\"confidence\":1.0,\"probabilities\":{\"calls\":1.0}}}," +
            "\"id\":\"decision-1\",\"model\":\"typesafe/jev-1.13\",\"provider\":\"openrouter\"}";
        match Decide.decode(request0, Decide.Wire.Wire(response)) {
            case Err(Decide.Error.UnknownAction("imports")) => ()
            case _ => Assert.fail("unknown decision choice was admitted")
        }
    }

    @Test
    def retainedDecisionReplaysWithoutNativeCapability(): Unit \ {Assert, FileSystem} = run {
        let request0 = request("issue", Vector#{callsAlternative()});
        let response = "{" +
            "\"answers\":{\"next_action\":{\"type\":\"choice\",\"choice\":\"calls\"," +
            "\"confidence\":1.0,\"probabilities\":{\"calls\":1.0}}}," +
            "\"id\":\"decision-1\",\"model\":\"typesafe/jev-1.13\",\"provider\":\"openrouter\"}";
        let Radii.Evaluate.DecisionId.DecisionId(identity) = request0#decision;
        let retained = "{\"version\":1,\"provider\":\"openrouter\"," +
            "\"model\":\"typesafe/jev-1.13\",\"decision_id\":" + jsonString(identity) +
            ",\"response\":" + jsonString(response) + "}";
        match FileSystem.write(str = retained, "/decisions/raw/decision-0.json") {
            case Err(error) => Assert.fail(ToString.toString(error))
            case Ok(()) => match Decide.runWithStoreReplay("/decisions", () -> Decide.policy(request0)) {
                case Err(error) => Assert.fail(ToString.toString(error))
                case Ok(observation) => Assert.assertEq(expected = 0, observation#choiceIndex)
            }
        }
    } with FileSystem.withMemoryOverlay

    @Test
    def retainedStoreIsLoadedOnceBeforeReplayBody(): Unit \ {Assert, FileSystem} = run {
        let request0 = request("issue", Vector#{callsAlternative()});
        let response = "{" +
            "\"answers\":{\"next_action\":{\"type\":\"choice\",\"choice\":\"calls\"," +
            "\"confidence\":1.0,\"probabilities\":{\"calls\":1.0}}}," +
            "\"id\":\"decision-1\",\"model\":\"typesafe/jev-1.13\",\"provider\":\"openrouter\"}";
        let Radii.Evaluate.DecisionId.DecisionId(identity) = request0#decision;
        let retained = "{\"version\":1,\"provider\":\"openrouter\"," +
            "\"model\":\"typesafe/jev-1.13\",\"decision_id\":" + jsonString(identity) +
            ",\"response\":" + jsonString(response) + "}";
        match FileSystem.write(str = retained, "/decisions/raw/decision-0.json") {
            case Err(error) => Assert.fail(ToString.toString(error))
            case Ok(()) => match Decide.runWithStoreReplay("/decisions", () -> {
                // A store mutation after handler construction must not change
                // the immutable replay view used by any decision in this run.
                match FileSystem.write(str = "not json", "/decisions/raw/decision-1.json") {
                    case Err(error) => Err(Decide.Error.ObservationStore(ToString.toString(error)))
                    case Ok(()) => forM (
                        first <- Decide.policy(request0);
                        second <- Decide.policy(request0)
                    ) yield (first, second)
                }
            }) {
                case Err(error) => Assert.fail(ToString.toString(error))
                case Ok((first, second)) => {
                    Assert.assertEq(expected = 0, first#choiceIndex);
                    Assert.assertEq(expected = first#choiceIndex, second#choiceIndex)
                }
            }
        }
    } with FileSystem.withMemoryOverlay

    def request(issue: String, alternatives: Vector[Decide.Alternative]): Decide.Request =
        match Decide.request(stateId(), "issue: ${issue}", alternatives) {
            case Err(_error) => unreachable!()
            case Ok(value) => value
        }

    def stateId(): Radii.Evaluate.StateId =
        Radii.Evaluate.stateId(Radii.Evaluate.State.Symbols(Set#{Repository.Structure.SymbolId.SymbolId(0)}))

    def callsAlternative(): Decide.Alternative = {
        action = Decide.Action.Follow(Radii.Atom.Calls),
        expression = Some(Radii.Evaluate.exprId(Radii.Expr.Atom(Radii.Atom.Calls))),
        state = stateId(),
        criterion = "Follow outgoing calls."
    }

    def stopAlternative(): Decide.Alternative = {
        action = Decide.Action.Stop,
        expression = None,
        state = stateId(),
        criterion = "Keep the current symbol frontier."
    }

    def jsonString(value: String): String =
        Util.Json.toCompactString(Util.Json.Json.JString(value))
}
