"""Derived, BuildBuddy-backed structural anchor experiment over frozen worlds."""

load("//build:attune.bzl", "AttuneWorldInfo")

def _anchor_experiment_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    anchors = ctx.actions.declare_file(ctx.attr.digest + "/anchors.parquet")
    scenarios = ctx.actions.declare_file(ctx.attr.digest + "/scenarios.parquet")
    report = ctx.actions.declare_file(ctx.attr.digest + "/report.md")
    args = ctx.actions.args()
    for key, value in [
        ("repository", world.repository),
        ("base_revision", world.base_revision),
        ("source_tree_identity", world.source_tree_identity),
        ("fact_identity", world.fact_identity),
        ("snapshot_id", world.snapshot_id),
        ("world_metadata", world.metadata.path),
        ("world_entities", world.entities.path),
        ("world_relations", world.relations.path),
        ("anchor_path", ctx.attr.anchor_path),
        ("baseline_commit", ctx.attr.baseline_commit),
        ("output_anchors", anchors.path),
        ("output_scenarios", scenarios.path),
        ("output_report", report.path),
    ]:
        args.add("--jvm_flag=-Dattune.%s=%s" % (key, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [world.metadata, world.entities, world.relations],
        outputs = [anchors, scenarios, report],
        execution_requirements = {"no-local": "1"},
        mnemonic = "AtlasAnchorCounterfactual",
        progress_message = "Measuring structural anchors %{label}",
    )
    return [DefaultInfo(files = depset([anchors, scenarios, report]))]

anchor_experiment = rule(
    implementation = _anchor_experiment_impl,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "anchor_path": attr.string(mandatory = True),
        "baseline_commit": attr.string(mandatory = True),
        "digest": attr.string(mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)
