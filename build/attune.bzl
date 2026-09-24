AttuneWorldInfo = provider(
    doc = "One typed admitted repository world and its semantic identity.",
    fields = {
        "metadata": "world metadata Parquet",
        "entities": "world entity Parquet",
        "relations": "world basis-relation Parquet",
        "identity": "canonical JSON identity emitted with the world, or None",
        "repository": "repository identity",
        "base_revision": "frozen base revision",
        "source_tree_identity": "implementation-independent source-tree identity",
        "fact_identity": "admitted fact identity",
        "snapshot_id": "complete snapshot identity",
    },
)

AttuneSignatureInfo = provider(
    doc = "One exact Atlas signature shard for one admitted snapshot.",
    fields = {
        "observations": "logical route observations Parquet",
        "physical": "physical execution counters Parquet",
        "snapshot": "snapshot summary Parquet",
        "repository": "repository identity",
        "base_revision": "frozen base revision",
        "source_tree_identity": "implementation-independent source-tree identity",
        "fact_identity": "admitted fact identity",
        "snapshot_id": "complete semantic snapshot identity",
    },
)

AttuneSignatureSummaryInfo = provider(
    doc = "One compact, regenerable summary of an immutable Atlas signature shard.",
    fields = {
        "summary": "typed long-form signature summary Parquet",
        "snapshot": "typed snapshot row copied from the signature provider",
        "physical": "typed physical rows copied from the signature provider",
    },
)

AttuneAtlasAggregateInfo = provider(
    doc = "Canonical aggregate tables over compact Atlas signature shards.",
    fields = {
        "summaries": "all long-form signature summary rows",
        "snapshots": "one typed row per frozen snapshot",
        "physical": "all per-seed physical rows",
    },
)

def _jvm_property(name, value):
    return "--jvm_flag=-D%s=%s" % (name, value)

def _world_info(ctx, metadata, entities, relations, identity = None):
    return AttuneWorldInfo(
        metadata = metadata,
        entities = entities,
        relations = relations,
        identity = identity,
        repository = ctx.attr.repository,
        base_revision = ctx.attr.base_revision,
        source_tree_identity = ctx.attr.source_tree_identity,
        fact_identity = ctx.attr.fact_identity,
        snapshot_id = ctx.attr.snapshot_id,
    )

def _world_fixture_impl(ctx):
    metadata = ctx.actions.declare_file(ctx.label.name + "/metadata.parquet")
    entities = ctx.actions.declare_file(ctx.label.name + "/entities.parquet")
    relations = ctx.actions.declare_file(ctx.label.name + "/relations.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.command", "fixture"),
        ("attune.repository", ctx.attr.repository),
        ("attune.base_revision", ctx.attr.base_revision),
        ("attune.source_tree_identity", ctx.attr.source_tree_identity),
        ("attune.fact_identity", ctx.attr.fact_identity),
        ("attune.snapshot_id", ctx.attr.snapshot_id),
        ("attune.world_metadata", metadata.path),
        ("attune.world_entities", entities.path),
        ("attune.world_relations", relations.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        outputs = [metadata, entities, relations],
        mnemonic = "AttuneWorldFixture",
        progress_message = "Writing typed repository fixture %{label}",
    )
    return [
        DefaultInfo(files = depset([metadata, entities, relations])),
        _world_info(ctx, metadata, entities, relations),
    ]

def _world_migration_impl(ctx):
    metadata = ctx.actions.declare_file(ctx.label.name + "/metadata.parquet")
    entities = ctx.actions.declare_file(ctx.label.name + "/entities.parquet")
    relations = ctx.actions.declare_file(ctx.label.name + "/relations.parquet")
    identity = ctx.actions.declare_file(ctx.label.name + "/identity.json")
    args = ctx.actions.args()
    for name, value in [
        ("attune.oracle", ctx.file.oracle.path),
        ("attune.retained_observations", ctx.file.retained_observations.path),
        ("attune.world_metadata", metadata.path),
        ("attune.world_entities", entities.path),
        ("attune.world_relations", relations.path),
        ("attune.world_identity", identity.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [ctx.file.oracle, ctx.file.retained_observations],
        outputs = [metadata, entities, relations, identity],
        mnemonic = "AttuneWorldMigration",
        progress_message = "Migrating retained repository world %{label}",
    )
    return [
        DefaultInfo(files = depset([metadata, entities, relations, identity])),
        _world_info(ctx, metadata, entities, relations, identity),
    ]

def _world_files_impl(ctx):
    return [
        DefaultInfo(files = depset([
            ctx.file.metadata,
            ctx.file.entities,
            ctx.file.relations,
        ])),
        _world_info(
            ctx,
            ctx.file.metadata,
            ctx.file.entities,
            ctx.file.relations,
        ),
    ]

attune_world_files = rule(
    implementation = _world_files_impl,
    attrs = {
        "metadata": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "entities": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "relations": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "repository": attr.string(mandatory = True),
        "base_revision": attr.string(mandatory = True),
        "source_tree_identity": attr.string(mandatory = True),
        "fact_identity": attr.string(mandatory = True),
        "snapshot_id": attr.string(mandatory = True),
    },
)

attune_world_fixture = rule(
    implementation = _world_fixture_impl,
    attrs = {
        "repository": attr.string(mandatory = True),
        "base_revision": attr.string(mandatory = True),
        "source_tree_identity": attr.string(mandatory = True),
        "fact_identity": attr.string(mandatory = True),
        "snapshot_id": attr.string(mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

attune_world_migration = rule(
    implementation = _world_migration_impl,
    attrs = {
        "oracle": attr.label(allow_single_file = [".json"], mandatory = True),
        "retained_observations": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "repository": attr.string(mandatory = True),
        "base_revision": attr.string(mandatory = True),
        "source_tree_identity": attr.string(mandatory = True),
        # These identities are outputs of semantic admission. The canonical
        # identity file, not these empty analysis-time fields, is authoritative.
        "fact_identity": attr.string(default = ""),
        "snapshot_id": attr.string(default = ""),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _atlas_signature_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    observations = ctx.actions.declare_file(ctx.label.name + "/observations.parquet")
    physical = ctx.actions.declare_file(ctx.label.name + "/physical.parquet")
    snapshot = ctx.actions.declare_file(ctx.label.name + "/snapshot.parquet")
    args = ctx.actions.args()
    command = "signature-dynamic" if world.identity else "signature"
    for name, value in [
        ("attune.command", command),
        ("attune.repository", world.repository),
        ("attune.base_revision", world.base_revision),
        ("attune.source_tree_identity", world.source_tree_identity),
        ("attune.fact_identity", world.fact_identity),
        ("attune.snapshot_id", world.snapshot_id),
        ("attune.world_metadata", world.metadata.path),
        ("attune.world_entities", world.entities.path),
        ("attune.world_relations", world.relations.path),
        ("attune.output_observations", observations.path),
        ("attune.output_physical", physical.path),
        ("attune.output_snapshot", snapshot.path),
        ("attune.manifest_case_count", str(ctx.attr.manifest_case_count)),
    ]:
        args.add(_jvm_property(name, value))
    inputs = [world.metadata, world.entities, world.relations]
    if world.identity:
        args.add(_jvm_property("attune.world_identity", world.identity.path))
        inputs.append(world.identity)
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = inputs,
        outputs = [observations, physical, snapshot],
        mnemonic = "AtlasSignature",
        progress_message = "Measuring Atlas signature %{label}",
    )
    return [
        DefaultInfo(files = depset([observations, physical, snapshot])),
        AttuneSignatureInfo(
            observations = observations,
            physical = physical,
            snapshot = snapshot,
            repository = world.repository,
            base_revision = world.base_revision,
            source_tree_identity = world.source_tree_identity,
            fact_identity = world.fact_identity,
            snapshot_id = world.snapshot_id,
        ),
    ]

attune_atlas_signature = rule(
    implementation = _atlas_signature_impl,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "manifest_case_count": attr.int(default = 1),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _atlas_signature_summary_impl(ctx):
    signature = ctx.attr.signature[AttuneSignatureInfo]
    summary = ctx.actions.declare_file(ctx.label.name + "/summary.parquet")
    args = ctx.actions.args()
    args.add(_jvm_property("attune.input_observations", signature.observations.path))
    args.add(_jvm_property("attune.output_summary", summary.path))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [signature.observations],
        outputs = [summary],
        mnemonic = "AtlasSignatureSummary",
        progress_message = "Summarizing Atlas signature %{label}",
    )
    return [
        DefaultInfo(files = depset([summary, signature.snapshot, signature.physical])),
        AttuneSignatureSummaryInfo(
            summary = summary,
            snapshot = signature.snapshot,
            physical = signature.physical,
        ),
    ]

attune_atlas_signature_summary = rule(
    implementation = _atlas_signature_summary_impl,
    attrs = {
        "signature": attr.label(providers = [AttuneSignatureInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _atlas_signatures_impl(ctx):
    signatures = [target[AttuneSignatureInfo] for target in ctx.attr.signatures]
    observations = [signature.observations for signature in signatures]
    physical = [signature.physical for signature in signatures]
    snapshots = [signature.snapshot for signature in signatures]
    catalog = ctx.actions.declare_file(ctx.label.name + ".snapshots.tsv")
    ctx.actions.write(
        output = catalog,
        content = "repository\tbase_revision\tsource_tree_identity\tfact_identity\tsnapshot_id\n" +
            "\n".join([
                "\t".join([
                    signature.repository,
                    signature.base_revision,
                    signature.source_tree_identity,
                    signature.fact_identity,
                    signature.snapshot_id,
                ])
                for signature in signatures
            ]) + "\n",
    )
    return [
        DefaultInfo(files = depset(observations + physical + snapshots + [catalog])),
        OutputGroupInfo(
            observations = depset(observations),
            physical = depset(physical),
            snapshots = depset(snapshots),
            snapshot_catalog = depset([catalog]),
        ),
    ]

attune_atlas_signatures = rule(
    implementation = _atlas_signatures_impl,
    attrs = {
        "signatures": attr.label_list(providers = [AttuneSignatureInfo]),
    },
)

def _atlas_signature_summaries_impl(ctx):
    summaries = [target[AttuneSignatureSummaryInfo] for target in ctx.attr.summaries]
    files = [summary.summary for summary in summaries]
    snapshots = [summary.snapshot for summary in summaries]
    physical = [summary.physical for summary in summaries]
    return [
        DefaultInfo(files = depset(files + snapshots + physical)),
        OutputGroupInfo(
            summaries = depset(files),
            snapshots = depset(snapshots),
            physical = depset(physical),
        ),
    ]

attune_atlas_signature_summaries = rule(
    implementation = _atlas_signature_summaries_impl,
    attrs = {
        "summaries": attr.label_list(providers = [AttuneSignatureSummaryInfo]),
    },
)

def _atlas_aggregate_impl(ctx):
    summaries = [target[AttuneSignatureSummaryInfo] for target in ctx.attr.summaries]
    manifest = ctx.actions.declare_file(ctx.label.name + "/inputs.tsv")
    aggregate_summaries = ctx.actions.declare_file(ctx.label.name + "/summaries.parquet")
    aggregate_snapshots = ctx.actions.declare_file(ctx.label.name + "/snapshots.parquet")
    aggregate_physical = ctx.actions.declare_file(ctx.label.name + "/physical.parquet")
    ctx.actions.write(
        output = manifest,
        content = "".join([
            "%s\t%s\t%s\n" % (summary.summary.path, summary.snapshot.path, summary.physical.path)
            for summary in summaries
        ]),
    )
    args = ctx.actions.args()
    for name, value in [
        ("attune.input_manifest", manifest.path),
        ("attune.output_summaries", aggregate_summaries.path),
        ("attune.output_snapshots", aggregate_snapshots.path),
        ("attune.output_physical", aggregate_physical.path),
    ]:
        args.add(_jvm_property(name, value))
    inputs = [manifest]
    for summary in summaries:
        inputs.extend([summary.summary, summary.snapshot, summary.physical])
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = inputs,
        outputs = [aggregate_summaries, aggregate_snapshots, aggregate_physical],
        mnemonic = "AtlasAggregate",
        progress_message = "Aggregating typed Atlas census %{label}",
    )
    return [
        DefaultInfo(files = depset([aggregate_summaries, aggregate_snapshots, aggregate_physical])),
        AttuneAtlasAggregateInfo(
            summaries = aggregate_summaries,
            snapshots = aggregate_snapshots,
            physical = aggregate_physical,
        ),
    ]

attune_atlas_aggregate = rule(
    implementation = _atlas_aggregate_impl,
    attrs = {
        "summaries": attr.label_list(providers = [AttuneSignatureSummaryInfo]),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _atlas_report_impl(ctx):
    aggregate = ctx.attr.aggregate[AttuneAtlasAggregateInfo]
    report = ctx.actions.declare_file(ctx.label.name + "/REPORT.md")
    repositories = ctx.actions.declare_file(ctx.label.name + "/repositories.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.input_summaries", aggregate.summaries.path),
        ("attune.input_snapshots", aggregate.snapshots.path),
        ("attune.input_physical", aggregate.physical.path),
        ("attune.output_report", report.path),
        ("attune.output_repository_summaries", repositories.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [aggregate.summaries, aggregate.snapshots, aggregate.physical],
        outputs = [report, repositories],
        mnemonic = "AtlasReport",
        progress_message = "Writing frozen Atlas census report %{label}",
    )
    return [DefaultInfo(files = depset([report, repositories]))]

attune_atlas_report = rule(
    implementation = _atlas_report_impl,
    attrs = {
        "aggregate": attr.label(providers = [AttuneAtlasAggregateInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)
