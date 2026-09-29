load("//build:attune.bzl", "AttuneWorldInfo")

def _all_seed_physical_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    output = ctx.actions.declare_file(ctx.label.name + "/physical.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.repository", world.repository),
        ("attune.base_revision", world.base_revision),
        ("attune.source_tree_identity", world.source_tree_identity),
        ("attune.fact_identity", world.fact_identity),
        ("attune.snapshot_id", world.snapshot_id),
        ("attune.world_metadata", world.metadata.path),
        ("attune.world_entities", world.entities.path),
        ("attune.world_relations", world.relations.path),
        ("attune.output_physical", output.path),
    ]:
        args.add("--jvm_flag=-D%s=%s" % (name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [world.metadata, world.entities, world.relations],
        outputs = [output],
        mnemonic = "AtlasLivePhysical",
        progress_message = "Measuring all Preact Atlas physical seeds",
    )
    return [DefaultInfo(files = depset([output]))]

all_seed_physical = rule(
    implementation = _all_seed_physical_impl,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)
