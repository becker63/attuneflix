"""Sharded, reproducible physical measurement of every frozen census world.

Each shard measures the complete frozen Atlas grammar over a bounded range
of file and symbol seeds. It shares the immutable repository index across
seeds and collapses equal exact frontiers within each seed. The Engine law
checks its counters against the original per-route evaluator. The final
typed Parquet is a BuildBuddy-backed Bazel action output. Static counts only
schedule work: the Flix action checks them against the admitted world.
"""

load("//build:attune.bzl", "AttuneWorldInfo")
load("//experiments/atlas-swe-explore/census:census.bzl", "ATLAS_WORLDS")
load(":seed_counts.bzl", "SEED_COUNTS")

SHARD_SIZE = 256

def _digest(world):
    return world.rpartition("/")[2].partition(":")[0]

PHYSICAL_EXPORTS = [
    "//experiments/atlas-live-physical:physical_" + _digest(world)
    for world in ATLAS_WORLDS
]

def _world_properties(world):
    return [
        ("attune.repository", world.repository),
        ("attune.base_revision", world.base_revision),
        ("attune.source_tree_identity", world.source_tree_identity),
        ("attune.fact_identity", world.fact_identity),
        ("attune.snapshot_id", world.snapshot_id),
        ("attune.world_metadata", world.metadata.path),
        ("attune.world_entities", world.entities.path),
        ("attune.world_relations", world.relations.path),
    ]

def _shard_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    output = ctx.actions.declare_file(ctx.label.name + "/physical.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.command", "measure"),
        ("attune.expected_seeds", str(ctx.attr.expected_seeds)),
        ("attune.seed_start", str(ctx.attr.seed_start)),
        ("attune.seed_end", str(ctx.attr.seed_end)),
    ] + _world_properties(world) + [("attune.output_physical", output.path)]:
        args.add("--jvm_flag=-D%s=%s" % (name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [world.metadata, world.entities, world.relations],
        outputs = [output],
        # Full-world inputs plus a JVM can exhaust this 15 GiB workstation.
        # Fail closed when RBE is absent; never fall back to local execution.
        execution_requirements = {"no-local": "1"},
        mnemonic = "AtlasLivePhysicalShard",
        progress_message = "Measuring Atlas physical seeds %{label}",
    )
    return [DefaultInfo(files = depset([output]))]

physical_shard = rule(
    implementation = _shard_impl,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
        "expected_seeds": attr.int(mandatory = True),
        "seed_start": attr.int(mandatory = True),
        "seed_end": attr.int(mandatory = True),
    },
)

def _merge_impl(ctx):
    inputs = [target[DefaultInfo].files.to_list()[0] for target in ctx.attr.shards]
    output = ctx.actions.declare_file(ctx.attr.digest + "/physical.parquet")
    args = ctx.actions.args()
    args.add("--jvm_flag=-Dattune.command=merge")
    args.add("--jvm_flag=-Dattune.expected_seeds=%d" % ctx.attr.expected_seeds)
    args.add("--jvm_flag=-Dattune.shard.count=%d" % len(inputs))
    for index, file in enumerate(inputs):
        args.add("--jvm_flag=-Dattune.shard.%d=%s" % (index, file.path))
    args.add("--jvm_flag=-Dattune.output_physical=%s" % output.path)
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        execution_requirements = {"no-local": "1"},
        mnemonic = "AtlasLivePhysicalMerge",
        progress_message = "Merging Atlas physical shards %{label}",
    )
    return [DefaultInfo(files = depset([output]))]

physical_merge = rule(
    implementation = _merge_impl,
    attrs = {
        "shards": attr.label_list(mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
        "digest": attr.string(mandatory = True),
        "expected_seeds": attr.int(mandatory = True),
    },
)

def all_world_physical(tool):
    if len(SEED_COUNTS) != len(ATLAS_WORLDS):
        fail("physical seed counts do not cover the census")
    for world in ATLAS_WORLDS:
        digest = _digest(world)
        count = SEED_COUNTS.get(digest)
        if count == None or count <= 0:
            fail("missing physical seed count for " + digest)
        shards = []
        for index in range((count + SHARD_SIZE - 1) // SHARD_SIZE):
            name = "physical_shard_%s_%d" % (digest, index)
            physical_shard(
                name = name,
                expected_seeds = count,
                seed_start = index * SHARD_SIZE,
                seed_end = min((index + 1) * SHARD_SIZE, count),
                tool = tool,
                world = world,
            )
            shards.append(":" + name)
        physical_merge(
            name = "physical_" + digest,
            digest = digest,
            expected_seeds = count,
            shards = shards,
            tool = tool,
            visibility = ["//visibility:public"],
        )
