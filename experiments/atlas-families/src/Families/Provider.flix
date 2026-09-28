/// The provider boundary of the families acquisition. Everything above it is
/// a pure function of the protocol, one admitted world, and the provider
/// bodies this effect returns; the handlers decide where those bodies come
/// from. Every handler resolves a request from the content-addressed store
/// first, so an unchanged request is acquired exactly once.
pub mod Families.Provider {
    import attune.inference.{AttuneDecision, AttuneOpenRouter}
    import dev.langchain4j.model.openai.internal.embedding.EmbeddingRequest
    import java.lang.Exception

    pub eff Provider {
        def exchange(request: Request): Result[String, String]
    }

    pub enum Kind with Eq, ToString {
        case EmbeddingBatch
        case Decision
    }

    /// One provider request: its content-derived identity, the exact
    /// provider-visible body, and (for embeddings) the ordered inputs.
    pub type alias Request = {
        kind     = Kind,
        identity = String,
        payload  = String,
        inputs   = Vector[String]
    }

    /// How a store miss is served: `Live` acquires through the in-tree
    /// client and retains the body before admission; `Refuse` is keyless
    /// replay, where a miss is an error and no transport exists; `Simulated`
    /// is an in-process stand-in provider for law tests.
    pub enum Transport {
        case Live
        case Refuse
        case Simulated(Request -> String)
    }

    pub type alias Stats = {
        recorded = Int32,
        acquired = Int32,
        spentUsd = Float64
    }

    /// Runs `f` against the store at `root`. Live acquisition stops before a
    /// call once the pass has spent `limitUsd`.
    pub def serve(
        root: String,
        protocol: String,
        transport: Transport,
        limitUsd: Float64,
        f: Unit -> a \ ef
    ): (a, Stats) \ (ef - Provider) + IO = region rc {
        let recorded = Ref.fresh(rc, 0);
        let acquired = Ref.fresh(rc, 0);
        let spent = Ref.fresh(rc, 0.0);
        let result = run { f() } with handler Provider {
            def exchange(request, resume) = {
                let resolved = match Families.Evidence.read(root, protocol, request#identity) {
                    case Err(error) => Err(error)
                    case Ok(Some(exchange0)) =>
                        if (exchange0#request != request#payload)
                            Err("retained request differs from ${request#identity}")
                        else {
                            Ref.transform(count -> count + 1, recorded);
                            Ok(exchange0#response)
                        }
                    case Ok(None) => match transport {
                        case Transport.Refuse => Err("keyless replay has no retained exchange for ${request#identity}")
                        case _ => if (Ref.get(spent) >= limitUsd)
                            Err("acquisition stopped at the ${limitUsd} USD pass envelope")
                        else acquire(root, protocol, transport, request) |> Result.map(match (body, cost) -> {
                            Ref.transform(count -> count + 1, acquired);
                            Ref.transform(total -> total + cost, spent);
                            if (Int32.remainder(Ref.get(acquired), 50) == 0)
                                println("${protocol}: acquired ${Ref.get(acquired)} exchanges, ${Ref.get(spent)} USD")
                            else ();
                            body
                        })
                    }
                };
                resume(resolved)
            }
        };
        (result, {recorded = Ref.get(recorded), acquired = Ref.get(acquired), spentUsd = Ref.get(spent)})
    }

    /// True exactly when the seam's only credential reader finds no key.
    pub def keyAbsent(): Bool \ IO = try {
        let _ = AttuneOpenRouter.live();
        false
    } catch {
        case _: Exception => true
    }

    /// The SDK request for one embedding batch under the pinned recipe.
    pub def embeddingRequest(inputs: Vector[String]): EmbeddingRequest \ IO =
        EmbeddingRequest.builder().model(Families.Protocol.embeddingModel()).input(Adaptor.toList(inputs)).encodingFormat(Families.Protocol.encodingFormat()).build()

    /// A provider body is retained before admission unless it is a provider
    /// or transport error, which is never an observation.
    def acquire(root: String, protocol: String, transport: Transport, request: Request): Result[String, (String, Float64)] \ IO = forM (
        body <- match transport {
            case Transport.Simulated(provider) => Ok(provider(request))
            case _ => fetch(request)
        };
        fields <- Families.Wire.body(body);
        usage <- Families.Wire.usage(fields);
        cost <- Families.Wire.optionalFloat64("cost", usage);
        _ <- Families.Evidence.write(root, protocol, {identity = request#identity, request = request#payload, response = body})
    ) yield (body, Option.getWithDefault(0.0, cost))

    def fetch(request: Request): Result[String, String] \ IO = match request#kind {
        case Kind.Decision => Ok(AttuneDecision.decide(request#payload))
        case Kind.EmbeddingBatch => try {
            Ok(AttuneOpenRouter.embed(AttuneOpenRouter.live(), embeddingRequest(request#inputs)).rawHttpResponse().body())
        } catch {
            case error: Exception => Err(AttuneOpenRouter.describe(error))
        }
    }
}
