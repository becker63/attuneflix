"""Bazel wiring for the self-signature parallelism experiment.

Mirrors the census pattern in //build:attune.bzl: deterministic JVM actions
over typed inputs. The instrument commands live in Parallelism.flix; these
rules only pass declared artifact paths as indexed JVM properties.
"""

def _jvm_property(name, value):
    return "--jvm_flag=-D%s=%s" % (name, value)

def _world_paths(world_files):
    """Map the world triple by basename: metadata/entities/relations."""
    paths = {}
    for file in world_files:
        paths[file.basename[:-len(".parquet")]] = file.path
    return paths

def _facts_impl(ctx):
    metadata = ctx.actions.declare_file(ctx.label.name + "/metadata.parquet")
    entities = ctx.actions.declare_file(ctx.label.name + "/entities.parquet")
    relations = ctx.actions.declare_file(ctx.label.name + "/relations.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.command", "facts"),
        ("attune.revision", ctx.attr.revision),
        ("attune.files", ctx.file.files.path),
        ("attune.modules", ctx.file.modules.path),
        ("attune.uses", ctx.file.uses.path),
        ("attune.world_metadata", metadata.path),
        ("attune.world_entities", entities.path),
        ("attune.world_relations", relations.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [ctx.file.files, ctx.file.modules, ctx.file.uses],
        outputs = [metadata, entities, relations],
        mnemonic = "AttuneParallelismFacts",
        progress_message = "Admitting self-world facts %{label}",
    )
    return [
        DefaultInfo(files = depset([metadata, entities, relations])),
        OutputGroupInfo(
            metadata = depset([metadata]),
            entities = depset([entities]),
            relations = depset([relations]),
        ),
    ]

attune_parallelism_facts = rule(
    implementation = _facts_impl,
    attrs = {
        "revision": attr.string(mandatory = True),
        "files": attr.label(allow_single_file = True, mandatory = True),
        "modules": attr.label(allow_single_file = True, mandatory = True),
        "uses": attr.label(allow_single_file = True, mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _region_impl(ctx):
    observations = ctx.actions.declare_file(ctx.label.name + "/observations.parquet")
    physical = ctx.actions.declare_file(ctx.label.name + "/physical.parquet")
    members = ctx.actions.declare_file(ctx.label.name + "/members.parquet")
    world = _world_paths(ctx.files.world)
    args = ctx.actions.args()
    for name, value in [
        ("attune.command", "region"),
        ("attune.region", ctx.attr.region),
        ("attune.world_metadata", world["metadata"]),
        ("attune.world_entities", world["entities"]),
        ("attune.world_relations", world["relations"]),
        ("attune.output_observations", observations.path),
        ("attune.output_physical", physical.path),
        ("attune.output_members", members.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = ctx.files.world,
        outputs = [observations, physical, members],
        mnemonic = "AttuneParallelismRegion",
        progress_message = "Measuring parallelism region %{label}",
    )
    return [DefaultInfo(files = depset([observations, physical, members]))]

attune_parallelism_region = rule(
    implementation = _region_impl,
    attrs = {
        "region": attr.string(mandatory = True),
        "world": attr.label(allow_files = [".parquet"], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

# The preregistered region names (attuneflix-regions-v1), in fixed order.
PARALLELISM_REGIONS = [
    "repository",
    "radii",
    "atlas",
    "localization",
    "tables",
    "population",
    "src-root",
    "tests",
    "build-src",
    "experiments",
]

def attune_parallelism_revision(name, revision, files, modules, uses, tool):
    """One revision's fact admission and per-region signature shards.

    The per-region shard actions are independent (BuildBuddy runs them
    concurrently, mirroring the census per-world fan-out). The region-pairs
    tables are produced by the compare action over both worlds.
    """
    attune_parallelism_facts(
        name = name + "_world",
        revision = revision,
        files = files,
        modules = modules,
        uses = uses,
        tool = tool,
    )
    for region in PARALLELISM_REGIONS:
        attune_parallelism_region(
            name = "%s_region_%s" % (name, region),
            region = region,
            world = ":%s_world" % name,
            tool = tool,
        )

def _grit_world_impl(ctx):
    metadata = ctx.actions.declare_file(ctx.label.name + "/metadata.parquet")
    entities = ctx.actions.declare_file(ctx.label.name + "/entities.parquet")
    relations = ctx.actions.declare_file(ctx.label.name + "/relations.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.command", "grit_facts"),
        ("attune.revision", ctx.attr.revision),
        ("attune.sources", ctx.file.sources.path),
        ("attune.facts", ctx.file.facts.path),
        ("attune.world_metadata", metadata.path),
        ("attune.world_entities", entities.path),
        ("attune.world_relations", relations.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [ctx.file.sources, ctx.file.facts],
        outputs = [metadata, entities, relations],
        mnemonic = "AttuneParallelismGritWorld",
        progress_message = "Admitting Grit-acquired self-world %{label}",
    )
    return [
        DefaultInfo(files = depset([metadata, entities, relations])),
        OutputGroupInfo(
            metadata = depset([metadata]),
            entities = depset([entities]),
            relations = depset([relations]),
        ),
    ]

attune_parallelism_grit_world = rule(
    implementation = _grit_world_impl,
    attrs = {
        "revision": attr.string(mandatory = True),
        "sources": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "facts": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def attune_parallelism_grit_revision(name, revision, sources, facts, tool):
    """One v2 revision: re-admit its committed Grit acquisition evidence and
    run the same independent per-region signature shards as v1."""
    attune_parallelism_grit_world(
        name = name + "_world",
        revision = revision,
        sources = sources,
        facts = facts,
        tool = tool,
    )
    for region in PARALLELISM_REGIONS:
        attune_parallelism_region(
            name = "%s_region_%s" % (name, region),
            region = region,
            world = ":%s_world" % name,
            tool = tool,
        )
