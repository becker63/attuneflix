/// Typed projections of the `atlas-families-v1` space for one world: the
/// families, their members at symbol grain, and the file and directory
/// rollups. Every member row carries the exact admitted symbol row it is
/// (snapshot, domain, entity id, path, name, span), so it joins the frozen
/// world entities table without any lookup key of its own.
pub mod Families.Cluster.Table {
    use ScientificTable.Value
    use ScientificTable.Columns.{boolean, float64, int32, optionalText, text, textList}

    pub def families(): ScientificTable.Schema = {
        format = "attune-atlas-families-v1",
        columns = Vector#{
            text("protocol"), text("snapshot_id"), int32("family"), text("family_id"), text("name"),
            text("name_kind"), boolean("named"), int32("seed"), optionalText("name_decision"),
            textList("seed_files"), textList("route"), text("state_id"), int32("members"), int32("files")
        }
    }

    pub def members(): ScientificTable.Schema = {
        format = "attune-atlas-families-members-v1",
        columns = Vector#{
            text("protocol"), text("snapshot_id"), int32("family"), text("family_id"), text("domain"),
            int32("entity_id"), text("path"), text("name"), int32("start_byte"), int32("end_byte"),
            int32("candidates"), float64("affinity"), float64("structural_affinity"), float64("semantic_affinity")
        }
    }

    pub def rollups(): ScientificTable.Schema = {
        format = "attune-atlas-families-rollups-v1",
        columns = Vector#{
            text("protocol"), text("snapshot_id"), text("level"), int32("location_id"), text("location"),
            int32("family"), text("family_id"), int32("members"), int32("location_members"), boolean("dominant")
        }
    }

    /// The entity domain of every member: families are defined over symbols.
    pub def memberDomain(): String = "symbol"

    /// Every table of one clustering: its name, file name, schema, and rows.
    pub def layout(value: Families.Cluster.Clustering): Vector[(String, String, ScientificTable.Schema, Vector[ScientificTable.Row])] = {
        let s = value#snapshotId;
        Vector#{
            ("families", "families.parquet", families(), Vector.map(familyRow(s), value#families)),
            ("members", "members.parquet", members(), Vector.map(memberRow(s), value#members)),
            ("rollups", "rollups.parquet", rollups(), Vector.map(rollupRow(s), value#rollups))
        }
    }

    /// The layout of an empty clustering: every table's name, file, and schema.
    pub def schemas(snapshotId: String): Vector[(String, String, ScientificTable.Schema, Vector[ScientificTable.Row])] =
        layout({snapshotId = snapshotId, families = Vector.empty(), members = Vector.empty(), rollups = Vector.empty()})

    pub def familyRow(snapshotId: String, value: Families.Cluster.Family): ScientificTable.Row =
        Map.union(Families.Rows.header(families(), snapshotId), Map#{
            "family" => Value.Int32(value#family),
            "family_id" => Value.Text(value#familyId),
            "name" => Value.Text(value#name),
            "name_kind" => Value.Text(value#nameKind),
            "named" => Value.Boolean(value#named),
            "seed" => Value.Int32(value#seed),
            "name_decision" => ScientificTable.optionalTextValue(value#nameDecision),
            "seed_files" => Value.TextList(value#seedFiles),
            "route" => Value.TextList(value#route),
            "state_id" => Value.Text(value#stateId),
            "members" => Value.Int32(value#members),
            "files" => Value.Int32(value#files)
        })

    pub def memberRow(snapshotId: String, value: Families.Cluster.Member): ScientificTable.Row =
        Map.union(Families.Rows.header(members(), snapshotId), Map#{
            "family" => Value.Int32(value#family),
            "family_id" => Value.Text(value#familyId),
            "domain" => Value.Text(memberDomain()),
            "entity_id" => Value.Int32(value#entityId),
            "path" => Value.Text(value#path),
            "name" => Value.Text(value#name),
            "start_byte" => Value.Int32(value#startByte),
            "end_byte" => Value.Int32(value#endByte),
            "candidates" => Value.Int32(value#candidates),
            "affinity" => Value.Float64(value#affinity),
            "structural_affinity" => Value.Float64(value#structural),
            "semantic_affinity" => Value.Float64(value#semantic)
        })

    pub def rollupRow(snapshotId: String, value: Families.Rollup.Rollup): ScientificTable.Row =
        Map.union(Families.Rows.header(rollups(), snapshotId), Map#{
            "level" => Value.Text(value#level),
            "location_id" => Value.Int32(value#locationId),
            "location" => Value.Text(value#location),
            "family" => Value.Int32(value#family),
            "family_id" => Value.Text(value#familyId),
            "members" => Value.Int32(value#members),
            "location_members" => Value.Int32(value#locationMembers),
            "dominant" => Value.Boolean(value#dominant)
        })

    /// The clustering stored in `files` (table name -> path).
    pub def read(snapshotId: String, files: Map[String, String]): Result[String, Families.Cluster.Clustering] \ IO = forM (
        tables <- Families.Rows.readLayout(schemas(snapshotId), files);
        rows = Families.Rows.rowsOf(tables);
        clustering <- decode(snapshotId, rows("families"), rows("members"), rows("rollups"))
    ) yield clustering

    /// The typed clustering of one world, from its three tables' rows.
    pub def decode(
        snapshotId: String,
        familyRows: Vector[ScientificTable.Row],
        memberRows: Vector[ScientificTable.Row],
        rollupRows: Vector[ScientificTable.Row]
    ): Result[String, Families.Cluster.Clustering] = forM (
        families0 <- Vector.traverse(decodeFamily(snapshotId), familyRows);
        _ <- if (Vector.map(value -> value#family, families0) == Vector.range(0, Vector.length(families0))) Ok(())
             else Err("families must be contiguous from family zero");
        members0 <- Vector.traverse(decodeMember(snapshotId), memberRows);
        rollups0 <- Vector.traverse(decodeRollup(snapshotId), rollupRows)
    ) yield {snapshotId = snapshotId, families = families0, members = members0, rollups = rollups0}

    def decodeFamily(snapshotId: String, row: ScientificTable.Row): Result[String, Families.Cluster.Family] = forM (
        _ <- Families.Rows.require(families(), snapshotId, row);
        family <- ScientificTable.int32(row, "family");
        familyId <- ScientificTable.text(row, "family_id");
        name <- ScientificTable.text(row, "name");
        nameKind <- ScientificTable.text(row, "name_kind");
        named <- ScientificTable.boolean(row, "named");
        seed <- ScientificTable.int32(row, "seed");
        nameDecision <- ScientificTable.optionalText(row, "name_decision");
        seedFiles <- Families.Rows.textList(row, "seed_files");
        route <- Families.Rows.textList(row, "route");
        stateId <- ScientificTable.text(row, "state_id");
        members0 <- ScientificTable.int32(row, "members");
        files <- ScientificTable.int32(row, "files")
    ) yield {
        family = family, familyId = familyId, name = name, nameKind = nameKind, named = named, seed = seed,
        nameDecision = nameDecision, seedFiles = seedFiles, route = route, stateId = stateId,
        members = members0, files = files
    }

    def decodeMember(snapshotId: String, row: ScientificTable.Row): Result[String, Families.Cluster.Member] = forM (
        _ <- Families.Rows.require(members(), snapshotId, row);
        _ <- ScientificTable.requireText("domain", memberDomain(), row, members()#format);
        family <- ScientificTable.int32(row, "family");
        familyId <- ScientificTable.text(row, "family_id");
        entityId <- ScientificTable.int32(row, "entity_id");
        path <- ScientificTable.text(row, "path");
        name <- ScientificTable.text(row, "name");
        startByte <- ScientificTable.int32(row, "start_byte");
        endByte <- ScientificTable.int32(row, "end_byte");
        candidates <- ScientificTable.int32(row, "candidates");
        affinity <- Families.Rows.float64(row, "affinity");
        structural <- Families.Rows.float64(row, "structural_affinity");
        semantic <- Families.Rows.float64(row, "semantic_affinity")
    ) yield {
        family = family, familyId = familyId, entityId = entityId, path = path, name = name,
        startByte = startByte, endByte = endByte, candidates = candidates,
        affinity = affinity, structural = structural, semantic = semantic
    }

    def decodeRollup(snapshotId: String, row: ScientificTable.Row): Result[String, Families.Rollup.Rollup] = forM (
        _ <- Families.Rows.require(rollups(), snapshotId, row);
        level <- ScientificTable.text(row, "level");
        _ <- if (level == Families.Rollup.fileLevel() or level == Families.Rollup.directoryLevel()) Ok(())
             else Err("unknown rollup level ${level}");
        locationId <- ScientificTable.int32(row, "location_id");
        location <- ScientificTable.text(row, "location");
        family <- ScientificTable.int32(row, "family");
        familyId <- ScientificTable.text(row, "family_id");
        members0 <- ScientificTable.int32(row, "members");
        locationMembers <- ScientificTable.int32(row, "location_members");
        dominant <- ScientificTable.boolean(row, "dominant")
    ) yield {
        level = level, locationId = locationId, location = location, family = family, familyId = familyId,
        members = members0, locationMembers = locationMembers, dominant = dominant
    }
}
