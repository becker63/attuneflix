/// The candidate's logical identity map and move classification
/// (PREREGISTRATION.md §9, §10 O6; VAL-HC1-002).
///
/// Every control logical identity (the frozen `ControlIdentity` derivation) is
/// carried into a candidate revision by content identity, never by re-acquiring
/// facts (§11, S1):
///
///   * a control path still present at the same path is `stable`, or `modified`
///     when its bytes changed and the surface kept its §9 identity payload;
///   * a control path whose exact bytes reappear at exactly one new path with
///     the same §9 surface class is `moved`;
///   * a control path with no successor is `dropped` and is reported, never
///     silently forgotten.
///
/// Candidate paths with no control predecessor are `new` (the experiment's own
/// added law/build surfaces) and are listed separately: they are deliberately
/// NOT given a fabricated control identity.
mod RoundIdentity {
    use AcquisitionFacts.Source

    pub def protocol(): String = "attuneflix-round-identity-v1"

    /// One control logical identity carried into a candidate revision.
    pub type alias Entry = {
        logicalId     = String,
        controlPath   = String,
        currentPath   = String,
        controlRegion = String,
        currentRegion = String,
        controlCell   = String,
        ownershipCell = String,
        movement      = String
    }

    pub type alias Round = {
        entries    = Vector[Entry],
        newPaths   = Vector[String],
        collisions = Vector[String],
        dropped    = Vector[String]
    }

    type alias Motion = {path = String, movement = String}

    /// Classify every control identity against the candidate's admitted path
    /// list and content hashes (`roundHashes`: candidate path -> sha256).
    pub def round(
        controlSources: Vector[Source],
        controlFacts: Vector[AcquisitionFacts.FactRow],
        roundPaths: Vector[String],
        roundHashes: Map[String, String]
    ): Round \ IO = {
        let controlSet = Vector.toSet(Vector.map(source -> source#path, controlSources));
        let roundSet = Vector.toSet(roundPaths);
        let byHash = hashesToPaths(roundPaths, roundHashes);
        let entries = Vector.map(source ->
            entry(source, controlFacts, controlSet, roundSet, roundHashes, byHash), controlSources);
        let matched = Vector.toSet(Vector.filterMap(entry0 ->
            if (entry0#movement == "moved") Some(entry0#currentPath) else None, entries));
        let newPaths = Vector.filter(path ->
            not Set.memberOf(path, controlSet) and not Set.memberOf(path, matched), roundPaths);
        {
            entries = entries,
            newPaths = newPaths,
            collisions = collisions(controlSources, controlSet, byHash),
            dropped = Vector.filterMap(entry0 ->
                if (entry0#movement == "dropped") Some(entry0#controlPath) else None, entries)
        }
    }

    /// The control path -> candidate path translation for every surviving
    /// identity (dropped identities are absent).
    pub def mapping(round0: Round): Map[String, String] =
        Vector.foldLeft((acc, entry0) ->
            if (String.length(entry0#currentPath) == 0) acc
            else Map.insert(entry0#controlPath, entry0#currentPath, acc),
            Map.empty(), round0#entries)

    /// Movement counts, in fixed order.
    pub def counts(round0: Round): Vector[(String, Int32)] =
        Vector.map(movement -> (movement, Vector.count(entry0 -> entry0#movement == movement, round0#entries)),
            Vector#{"stable", "modified", "moved", "dropped"})

    def entry(
        source: Source,
        facts: Vector[AcquisitionFacts.FactRow],
        controlSet: Set[String],
        roundSet: Set[String],
        roundHashes: Map[String, String],
        byHash: Map[String, Vector[String]]
    ): Entry \ IO = {
        let base = ControlIdentity.entry(source, ControlIdentity.definitionsOf(facts, source#path));
        let motion = motionOf(source, controlSet, roundSet, roundHashes, byHash);
        let alive = String.length(motion#path) > 0;
        {
            logicalId = base#logicalId,
            controlPath = source#path,
            currentPath = motion#path,
            controlRegion = base#controlRegion,
            currentRegion = if (alive) ControlMap.regionOf(motion#path) else "",
            controlCell = base#ownershipCell,
            ownershipCell = if (alive) ControlMap.roundCellOf(motion#path) else "",
            movement = motion#movement
        }
    }

    def motionOf(
        source: Source,
        controlSet: Set[String],
        roundSet: Set[String],
        roundHashes: Map[String, String],
        byHash: Map[String, Vector[String]]
    ): Motion =
        if (Set.memberOf(source#path, roundSet))
            {path = source#path,
             movement = if (Map.getWithDefault(source#path, "", roundHashes) == source#sha256) "stable" else "modified"}
        else match movedTo(source, controlSet, byHash) {
            case Some(path) => {path = path, movement = "moved"}
            case None => {path = "", movement = "dropped"}
        }

    /// The unique candidate path carrying the control path's exact bytes under
    /// the same §9 surface class. Two matches are a collision, not a move.
    def movedTo(source: Source, controlSet: Set[String], byHash: Map[String, Vector[String]]): Option[String] = {
        let candidates = Vector.filter(path ->
            not Set.memberOf(path, controlSet)
                and ControlMap.surfaceClass(path) == ControlMap.surfaceClass(source#path),
            Map.getWithDefault(source#sha256, Vector.empty(), byHash));
        if (Vector.length(candidates) == 1) Some(Vector.get(0, candidates)) else None
    }

    def hashesToPaths(roundPaths: Vector[String], roundHashes: Map[String, String]): Map[String, Vector[String]] =
        Vector.foldLeft((acc, path) -> {
            let hash = Map.getWithDefault(path, "", roundHashes);
            if (String.length(hash) == 0) acc
            else Map.insert(hash, Vector.append(Map.getWithDefault(hash, Vector.empty(), acc), Vector#{path}), acc)
        }, Map.empty(), roundPaths)

    /// Content hashes claimed by more than one new candidate path: an ambiguous
    /// move that must be reported rather than resolved silently.
    def collisions(
        controlSources: Vector[Source],
        controlSet: Set[String],
        byHash: Map[String, Vector[String]]
    ): Vector[String] = {
        let hashes = Vector.toSet(Vector.map(source -> source#sha256, controlSources)) |> Set.toVector;
        Vector.filterMap(hash -> {
            let candidates = Vector.filter(path -> not Set.memberOf(path, controlSet),
                Map.getWithDefault(hash, Vector.empty(), byHash));
            if (Vector.length(candidates) > 1) Some("${hash}:${Vector.length(candidates)}")
            else None
        }, hashes)
    }
}
