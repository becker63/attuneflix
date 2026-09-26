/// The control specimen's logical identity mapping (PREREGISTRATION.md §9).
///
/// Each admitted source file is assigned a `logical_id` whose payload is
/// `language \u0000 declared_identity \u0000 surface_class`: no path byte is
/// part of the payload, so identity survives a move or a rename while two files
/// that declare the same module in different surfaces stay distinct. The
/// accompanying `control_path` / `current_path` / `control_region` /
/// `ownership_cell` columns are the §4 region and §5 cell of the admitted path.
///
/// The mapping is written as `control.identity_map.json` and is exact: a fresh
/// derivation from the committed evidence must reproduce it byte for byte.
pub mod ControlIdentity {
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}

    pub type alias Entry = {
        logicalId     = String,
        controlPath   = String,
        currentPath   = String,
        controlRegion = String,
        ownershipCell = String
    }

    /// One entry per admitted source, in admitted-path order; `current_path`
    /// equals `control_path` at control.
    pub def entries(
        sources: Vector[AcquisitionFacts.Source],
        facts: Vector[AcquisitionFacts.FactRow]
    ): Vector[Entry] \ IO =
        Vector.map(source -> entry(source, definitionsOf(facts, source#path)),
            Vector.sortBy(source -> source#path, sources))

    /// The declared-identity payload of one file. Paths are absent from the
    /// payload by construction: the identity is the language, the declared
    /// name and the surface class, and nothing else.
    pub def entry(source: AcquisitionFacts.Source, definitions: Vector[(String, Int32, Int32)]): Entry \ IO = {
        let declared = ControlMap.declaredIdentity(source#path, source#language, definitions);
        let payload = "${source#language}\u0000${declared}\u0000${ControlMap.surfaceClass(source#path)}";
        {
            logicalId = ScientificIdentity.versioned("attuneflix-logical-v1", payload),
            controlPath = source#path,
            currentPath = source#path,
            controlRegion = ControlMap.regionOf(source#path),
            ownershipCell = ControlMap.cellOf(source#path)
        }
    }

    /// The admitted `defines` facts of one path as (value, startByte, endByte),
    /// in the canonical byte order `Repository.admit` uses.
    pub def definitionsOf(facts: Vector[AcquisitionFacts.FactRow], path: String): Vector[(String, Int32, Int32)] =
        Vector.filterMap(fact ->
            if (fact#program == "defines" and fact#path == path)
                Some((fact#value, fact#startByte, fact#endByte))
            else None,
            facts)

    /// The identity map as one JSON array of objects, deterministically ordered
    /// (entries are sorted by `control_path`).
    pub def json(entries: Vector[Entry]): String =
        JArray(Vector.map(entryJson, entries)) |> Json.toCompactString

    def entryJson(entry: Entry): Json = JObject(Map#{
        "logical_id" => JString(entry#logicalId),
        "control_path" => JString(entry#controlPath),
        "current_path" => JString(entry#currentPath),
        "control_region" => JString(entry#controlRegion),
        "ownership_cell" => JString(entry#ownershipCell)
    })

    /// Distinct `logical_id` count; §9 requires it to equal the file count, so
    /// a collision is a construction failure rather than a silent merge.
    pub def distinctIdentities(entries: Vector[Entry]): Int32 =
        Vector.map(entry -> entry#logicalId, entries) |> Vector.toSet |> Set.size
}
