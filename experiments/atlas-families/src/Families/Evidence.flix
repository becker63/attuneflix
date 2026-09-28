/// The content-addressed raw evidence store of one families space and world.
///
/// Every provider exchange is retained exactly once, before local admission,
/// at `<root>/raw/<sha256>.json`, where the digest is the request identity's
/// digest. The file carries the exact provider-visible request and the
/// unchanged provider body, so replay and inspection never need the provider.
/// Retained files are never rewritten.
pub mod Families.Evidence {
    import java.nio.file.{Files, Paths, StandardCopyOption}
    import java.lang.Exception

    use Util.Json
    use Util.Json.Json.{JObject, JString}
    use Util.Json.ToJson

    pub type alias Exchange = {
        identity = String,
        request  = String,
        response = String
    }

    pub def version(): Int32 = 1

    /// The request identity: a versioned digest over length-prefixed parts,
    /// so no two part sequences share a canonical payload. The credential is
    /// transport-only and never a part.
    pub def identity(protocol: String, parts: Vector[String]): String \ IO =
        ScientificIdentity.versioned(protocol,
            Vector.foldLeft((text, part) -> text + "${String.length(part)}:${part}", "", Vector.append(Vector#{protocol}, parts)))

    /// `protocol:hex` identities address `raw/hex.json`.
    pub def path(root: String, identity: String): String = {
        let digest = match String.indexOfRight(substr = ":", identity) {
            case None => identity
            case Some(index) => String.sliceRight(start = index + 1, identity)
        };
        "${root}/raw/${digest}.json"
    }

    pub def encode(protocol: String, exchange: Exchange): String =
        Json.toCompactString(JObject(Map#{
            "version" => ToJson.toJson(version()),
            "protocol" => JString(protocol),
            "identity" => JString(exchange#identity),
            "request" => JString(exchange#request),
            "response" => JString(exchange#response)
        }))

    pub def decode(protocol: String, payload: String): Result[String, Exchange] = match Json.parse(payload) {
        case Err(error) => Err("retained exchange: ${ToString.toString(error)}")
        case Ok(JObject(fields)) => forM (
            recordedVersion <- Families.Wire.int32("version", fields);
            _ <- if (recordedVersion == version()) Ok(()) else Err("retained exchange version ${recordedVersion}");
            recordedProtocol <- Families.Wire.text("protocol", fields);
            _ <- if (recordedProtocol == protocol) Ok(()) else Err("retained exchange protocol ${recordedProtocol}");
            identity <- Families.Wire.text("identity", fields);
            request <- Families.Wire.text("request", fields);
            response <- Families.Wire.text("response", fields)
        ) yield {identity = identity, request = request, response = response}
        case Ok(_) => Err("retained exchange must be an object")
    }

    /// The retained exchange for an identity, if one exists. A retained file
    /// whose recorded identity differs from its address is corrupt evidence.
    pub def read(root: String, protocol: String, identity: String): Result[String, Option[Exchange]] \ IO = {
        let file = Paths.get(path(root, identity));
        if (not Files.exists(file)) Ok(None)
        else decode(protocol, Files.readString(file)) |> Result.flatMap(exchange ->
            if (exchange#identity == identity) Ok(Some(exchange))
            else Err("retained exchange at ${path(root, identity)} carries identity ${exchange#identity}"))
    }

    /// The number of exchanges retained under `root`.
    pub def retained(root: String): Int32 \ IO = {
        let directory = Paths.get("${root}/raw").toFile();
        if (not directory.isDirectory()) 0
        else Array.count(name -> String.endsWith(suffix = ".json", name), directory.list())
    }

    /// Retains a new exchange atomically. Existing evidence is never replaced.
    pub def write(root: String, protocol: String, exchange: Exchange): Result[String, Unit] \ IO = {
        let target = Paths.get(path(root, exchange#identity));
        if (Files.exists(target)) Err("refusing to overwrite retained evidence ${path(root, exchange#identity)}")
        else try {
            let _ = Files.createDirectories(target.getParent());
            let staging = Paths.get(path(root, exchange#identity) + ".partial");
            let _ = Files.writeString(staging, encode(protocol, exchange));
            let _ = Files.move(staging, target, StandardCopyOption.ATOMIC_MOVE);
            Ok(())
        } catch {
            case error: Exception => Err("cannot retain evidence: ${error.getMessage()}")
        }
    }
}
