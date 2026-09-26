/// The control specimen's co-change work graph (PREREGISTRATION.md §8).
///
/// Constructed from the VCS history reachable from the control revision,
/// excluding the experiment's own changes (they are descendants of the control
/// commit and therefore outside `git log <control>`), and restricted to the
/// admitted control file set.
///
/// Three models are reported side by side and never conflated:
///
///   raw           one unit per commit per unordered pair of admitted files it
///                 touches: a pair *frequency*.
///   normalized    `1 / C(|T|, 2)` per commit per pair, so every commit
///                 contributes unit total mass and large commits cannot
///                 dominate.
///   line-weighted `min(changed_lines(f), changed_lines(g))` per co-change.
///
/// The raw extract (`control.cochange_history.txt`, `git log --numstat
/// --no-renames`) is committed so the whole model is reproducible in-graph from
/// frozen evidence. The available history is small and single-author with
/// squashed changes, so this is a weak, honest proxy for real coordination; it
/// is reported as such and never used alone to justify a candidate.
mod ControlCoChange {
    import java.lang.Integer
    use Util.Json
    use Util.Json.Json.{JArray, JObject, JString}
    use Util.Json.ToJson

    pub def model(): String = "attuneflix-cochange-v1"
    pub def limitation(): String =
        "small single-author squashed history: a weak coordination proxy, never used alone to accept a candidate"
    pub def cutDepth(): Int32 = 8

    /// One commit and the changed lines it records per path (`0` for binary).
    pub type alias Commit = {hash = String, changed = Vector[(String, Int32)]}

    /// The three reported weights of one unordered file pair.
    pub type alias Weight = {raw = Int32, normalized = Float64, lineWeighted = Int32}

    // ---- Parsing the raw `git log --numstat` extract ----

    /// A commit marker is `C<TAB><hash>`; every other non-empty line is a
    /// `--numstat` row `added<TAB>deleted<TAB>path`.
    pub def parseHistory(text: String): Vector[Commit] = {
        let start: (Vector[Commit], Option[Commit]) = (Vector.empty(), None);
        let (done, open) = Vector.foldLeft((state, line) -> {
            let (finished, current) = state;
            if (String.startsWith(prefix = "C\t", line))
                (appendCommit(finished, current),
                    Some({hash = String.sliceRight(start = 2, line), changed = Vector.empty()}))
            else match changeOf(line) {
                case None => (finished, current)
                case Some(change) => match current {
                    case None => (finished, current)
                    case Some(entry) => (finished,
                        Some({hash = entry#hash, changed = Vector.append(entry#changed, Vector#{change})}))
                }
            }
        }, start, String.lines(text) |> List.toVector);
        appendCommit(done, open)
    }

    def appendCommit(finished: Vector[Commit], current: Option[Commit]): Vector[Commit] = match current {
        case None => finished
        case Some(commit) => Vector.append(finished, Vector#{commit})
    }

    def changeOf(line: String): Option[(String, Int32)] = match String.splitOn(substr = "\t", line) {
        case added :: deleted :: rest =>
            let path = String.flatten(List.intersperse("\t", rest));
            if (String.length(path) == 0 or String.length(added) == 0) None
            else Some((path, changedLines(added, deleted)))
        case _ => None
    }

    /// Binary rows carry `-`; every other row carries decimal line counts.
    def changedLines(added: String, deleted: String): Int32 =
        if (added == "-" or deleted == "-") 0
        else Integer.parseInt(added) + Integer.parseInt(deleted)

    // ---- The weighted pair graph ----

    pub def graph(commits: Vector[Commit], admitted: Set[String]): Map[(String, String), Weight] = {
        let start: Map[(String, String), Weight] = Map.empty();
        Vector.foldLeft((acc, commit) -> {
            let touched = Vector.filter(match (path, _) -> Set.memberOf(path, admitted), commit#changed);
            let count = Vector.length(touched);
            if (count < 2) acc
            else {
                let denominator = count * (count - 1) / 2;
                let pairs = Vector.flatMap(match (a, aLines) -> Vector.filterMap(match (b, bLines) ->
                    if (a < b) Some((a, b, aLines, bLines)) else None, touched), touched);
                Vector.foldLeft((step, pair) -> match pair {
                    case (a, b, aLines, bLines) => {
                        let previous = Map.getWithDefault((a, b), {raw = 0, normalized = 0.0, lineWeighted = 0}, step);
                        Map.insert((a, b), {
                            raw = previous#raw + 1,
                            normalized = previous#normalized + 1.0 / Int32.toFloat64(denominator),
                            lineWeighted = previous#lineWeighted + (if (aLines < bLines) aLines else bLines)
                        }, step)
                    }
                }, acc, pairs)
            }
        }, start, commits)
    }

    pub def commitsTouchingAdmitted(commits: Vector[Commit], admitted: Set[String]): Int32 =
        Vector.count(commit -> Vector.exists(match (path, _) -> Set.memberOf(path, admitted), commit#changed), commits)

    // ---- Aggregates over the pair graph ----

    pub def totalRaw(entries: Vector[((String, String), Weight)]): Int32 =
        Vector.foldLeft((acc, entry) -> match entry {
            case (_, weight) => acc + weight#raw
        }, 0, entries)

    pub def totalNormalized(entries: Vector[((String, String), Weight)]): Float64 =
        Vector.foldLeft((acc, entry) -> match entry {
            case (_, weight) => acc + weight#normalized
        }, 0.0, entries)

    pub def totalLineWeighted(entries: Vector[((String, String), Weight)]): Int32 =
        Vector.foldLeft((acc, entry) -> match entry {
            case (_, weight) => acc + weight#lineWeighted
        }, 0, entries)

    pub def regionInternalRaw(entries: Vector[((String, String), Weight)], region0: String): Int32 =
        Vector.foldLeft((acc, entry) -> match entry {
            case ((a, b), weight) =>
                if (ControlMap.regionOf(a) == region0 and ControlMap.regionOf(b) == region0) acc + weight#raw else acc
        }, 0, entries)

    /// The undirected co-change mass between region pairs, keyed by sorted names.
    pub def regionPairMass(entries: Vector[((String, String), Weight)]): Map[(String, String), Int32] = {
        let start: Map[(String, String), Int32] = Map.empty();
        Vector.foldLeft((acc, entry) -> match entry {
            case ((a, b), weight) => {
                let ra = ControlMap.regionOf(a);
                let rb = ControlMap.regionOf(b);
                let key = if (ra < rb) (ra, rb) else (rb, ra);
                Map.insert(key, Map.getWithDefault(key, 0, acc) + weight#raw, acc)
            }
        }, start, entries)
    }

    /// The regions appearing as a co-change endpoint, in fixed sorted order.
    def regionNames(entries: Vector[((String, String), Weight)]): Vector[String] =
        Vector.sort(Set.toVector(Vector.toSet(Vector.append(
            Vector.map(match ((a, _), _) -> ControlMap.regionOf(a), entries),
            Vector.map(match ((_, b), _) -> ControlMap.regionOf(b), entries)))))

    // ---- JSON ----

    def str(value: String): Json = JString(value)
    def int(value: Int32): Json = ToJson.toJson(value)
    def real(value: Float64): Json = ToJson.toJson(value)
    def arr(items: Vector[Json]): Json = JArray(items)
    def obj(fields: Vector[(String, Json)]): Json = JObject(Vector.toMap(fields))

    pub def json(revision: String, commits: Vector[Commit], admitted: Set[String],
                 world: Repository.World): String = {
        let entries = Map.toVector(graph(commits, admitted));
        let regionPairs = Map.toVector(regionPairMass(entries));
        let totalRaw0 = totalRaw(entries);
        let totalLine0 = totalLineWeighted(entries);
        let totalNormalized0 = totalNormalized(entries);
        let crossRaw = Vector.foldLeft((acc, entry) -> match entry {
            case ((a, b), weight) => if (ControlMap.regionOf(a) != ControlMap.regionOf(b)) acc + weight#raw else acc
        }, 0, entries);
        let crossLine = Vector.foldLeft((acc, entry) -> match entry {
            case ((a, b), weight) => if (ControlMap.regionOf(a) != ControlMap.regionOf(b)) acc + weight#lineWeighted else acc
        }, 0, entries);
        let crossNormalized = Vector.foldLeft((acc, entry) -> match entry {
            case ((a, b), weight) => if (ControlMap.regionOf(a) != ControlMap.regionOf(b)) acc + weight#normalized else acc
        }, 0.0, entries);
        let weightFn: (Set[String], Set[String]) -> Int32 = (left, right) -> Vector.foldLeft((acc, entry) -> match entry {
            case ((r1, r2), mass) =>
                if ((Set.memberOf(r1, left) and Set.memberOf(r2, right))
                    or (Set.memberOf(r1, right) and Set.memberOf(r2, left))) acc + mass else acc
        }, 0, regionPairs);
        let seeds = Vector.map(region0 -> (region0, Set#{region0}), ControlTopology.nonEmptyRegions(world));
        let groups = ControlTopology.mergeBy(weightFn, cutDepth(), Vector.sortBy(match (name, _) -> name, seeds));
        let cutMass = Vector.foldLeft((acc, entry) -> match entry {
            case ((r1, r2), mass) =>
                if (r1 == "other" or r2 == "other" or ControlTopology.crosses(groups, r1, r2)) acc + mass else acc
        }, 0, regionPairs);
        obj(Vector#{
            ("model", str(model())),
            ("revision", str(revision)),
            ("region_protocol", str(ControlTopology.regionProtocol())),
            ("commits_scanned", int(Vector.length(commits))),
            ("commits_touching_admitted", int(commitsTouchingAdmitted(commits, admitted))),
            ("pairs", int(Vector.length(entries))),
            ("total_mass", obj(Vector#{
                ("raw", int(totalRaw0)),
                ("normalized", real(totalNormalized0)),
                ("line_weighted", int(totalLine0))
            })),
            ("strongest_pairs", arr(Vector.map(match ((a, b), weight) -> obj(Vector#{
                ("left", str(a)),
                ("right", str(b)),
                ("left_region", str(ControlMap.regionOf(a))),
                ("right_region", str(ControlMap.regionOf(b))),
                ("cross_region", ToJson.toJson(ControlMap.regionOf(a) != ControlMap.regionOf(b))),
                ("raw", int(weight#raw)),
                ("normalized", real(weight#normalized)),
                ("line_weighted", int(weight#lineWeighted))
            }), Vector.take(20, Vector.sortBy(match ((a, b), weight) -> (0 - weight#raw, a, b), entries))))),
            ("region_internal_share", arr(Vector.map(region0 -> obj(Vector#{
                ("region", str(region0)),
                ("raw_mass", int(regionInternalRaw(entries, region0))),
                ("share", real(ScientificTable.ratio(regionInternalRaw(entries, region0), totalRaw0)))
            }), regionNames(entries)))),
            ("cross_region", obj(Vector#{
                ("raw_mass", int(crossRaw)),
                ("raw_ratio", real(ScientificTable.ratio(crossRaw, totalRaw0))),
                ("normalized_mass", real(crossNormalized)),
                ("normalized_ratio", real(if (totalNormalized0 == 0.0) 0.0 else crossNormalized / totalNormalized0)),
                ("line_weighted_mass", int(crossLine)),
                ("line_weighted_ratio", real(ScientificTable.ratio(crossLine, totalLine0)))
            })),
            ("cochange_cut_8", obj(Vector#{
                ("cross_mass_raw", int(cutMass)),
                ("total_mass_raw", int(totalRaw0)),
                ("fraction", real(ScientificTable.ratio(cutMass, totalRaw0))),
                ("groups", arr(Vector.map(match (name, members0) -> obj(Vector#{
                    ("name", str(name)),
                    ("regions", arr(Vector.map(str, Vector.sort(Set.toVector(members0)))))
                }), groups)))
            })),
            ("limitation", str(limitation()))
        }) |> Json.toCompactString
    }
}
