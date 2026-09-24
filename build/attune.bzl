AttuneWorldInfo = provider(
    doc = "One typed admitted repository world and its semantic identity.",
    fields = {
        "metadata": "world metadata Parquet",
        "entities": "world entity Parquet",
        "relations": "world basis-relation Parquet",
        "repository": "repository identity",
        "base_revision": "frozen base revision",
        "source_tree_identity": "implementation-independent source-tree identity",
        "fact_identity": "admitted fact identity",
        "snapshot_id": "complete snapshot identity",
    },
)

def _jvm_property(name, value):
    return "--jvm_flag=-D%s=%s" % (name, value)

def _world_info(ctx, metadata, entities, relations):
    return AttuneWorldInfo(
        metadata = metadata,
        entities = entities,
        relations = relations,
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

def _atlas_signature_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    observations = ctx.actions.declare_file(ctx.label.name + "/observations.parquet")
    physical = ctx.actions.declare_file(ctx.label.name + "/physical.parquet")
    snapshot = ctx.actions.declare_file(ctx.label.name + "/snapshot.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.command", "signature"),
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
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [world.metadata, world.entities, world.relations],
        outputs = [observations, physical, snapshot],
        mnemonic = "AtlasSignature",
        progress_message = "Measuring Atlas signature %{label}",
    )
    return [DefaultInfo(files = depset([observations, physical, snapshot]))]

attune_atlas_signature = rule(
    implementation = _atlas_signature_impl,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "manifest_case_count": attr.int(default = 1),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)
