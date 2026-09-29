"""One pinned self-world's frozen Atlas summary; no census population changes."""

load("//build:attune.bzl", "AttuneSignatureSummaryInfo")
load("//experiments/atlas-live-physical:physical.bzl", "physical_merge", "physical_shard")

SELF_DIGEST = "6bae5cbc218b494824fd4dbdd23e62cdad23301dc9243ee7040a32728daef59a"
SELF_WORLD = "//.attune/atlas-live-self-v1/%s:world" % SELF_DIGEST

def self_physical(world, digest, seeds):
    """The same all-seed remote measurement as the 78 census worlds."""
    shards = []
    for start in range(0, seeds, 256):
        name = "physical_shard_%d" % (start // 256)
        physical_shard(
            name = name,
            world = world,
            tool = "//experiments/atlas-live-physical:physical_tool",
            expected_seeds = seeds,
            seed_start = start,
            seed_end = min(start + 256, seeds),
        )
        shards.append(":" + name)
    physical_merge(
        name = "physical",
        shards = shards,
        tool = "//experiments/atlas-live-physical:physical_tool",
        digest = digest,
        expected_seeds = seeds,
        visibility = ["//visibility:public"],
    )

def _single_report_impl(ctx):
    summary = ctx.attr.summary[AttuneSignatureSummaryInfo]
    report = ctx.actions.declare_file(ctx.label.name + "/REPORT.md")
    repositories = ctx.actions.declare_file(ctx.label.name + "/repositories.parquet")
    args = ctx.actions.args()
    for key, file in [
        ("attune.input_summaries", summary.summary),
        ("attune.input_snapshots", summary.snapshot),
        ("attune.input_physical", summary.physical),
        ("attune.output_report", report),
        ("attune.output_repository_summaries", repositories),
    ]:
        args.add("--jvm_flag=-D%s=%s" % (key, file.path))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [summary.summary, summary.snapshot, summary.physical],
        outputs = [report, repositories],
        execution_requirements = {"no-local": "1"},
        mnemonic = "AtlasReport",
        progress_message = "Writing pinned AttuneFlix signature %{label}",
    )
    return [DefaultInfo(files = depset([report, repositories]))]

single_report = rule(
    implementation = _single_report_impl,
    attrs = {
        "summary": attr.label(providers = [AttuneSignatureSummaryInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)
