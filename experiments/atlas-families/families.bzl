"""Per-world wiring for the Atlas Families experiment.

Starlark passes artifact paths and identity strings as JVM properties (action
transport, not scientific data); the Flix tool owns every derivation and typed
table. World labels come from the frozen census graph and are never re-declared.
"""

load("//build:attune.bzl", "AttuneWorldInfo")
load("//experiments/atlas-swe-explore/census:census.bzl", "ATLAS_WORLDS")
load(":acquired_worlds.bzl", "ACQUIRED_DIGESTS")

FamiliesInventoryInfo = provider(
    doc = "One typed families acquisition inventory for one admitted world.",
    fields = {
        "inventory": "inventory Parquet (attune-families-inventory-v1)",
        "snapshot_id": "complete semantic snapshot identity",
    },
)

# The representative frozen worlds, in report order: per repository, the
# snapshot with the fewest points (ties by snapshot id), the same rule Atlas
# Live uses for its default world. The web-generated synthetic stress fixture is
# not a frozen census world and is wired separately when the method needs it.
REPRESENTATIVE_WORLDS = [
    ("preact", "//.attune/repository-world-v1/6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9:world"),
    ("axios", "//.attune/repository-world-v1/1e44a1c45ec4a91bb7774dc6d37a2846a5f56262b6fa7ae5722bcbcc15ba10c7:world"),
    ("immutable_js", "//.attune/repository-world-v1/f0d3c13774ad53f40a97c6e74c61e2705718cdd2b215560b9ede898df79c22da:world"),
    ("nodebb", "//.attune/repository-world-v1/d13b9c7923b4753ff87cabfe722a0c6b928a50ed9dffebbda85ccb8d3641d9ed:world"),
    ("vue_core", "//.attune/repository-world-v1/96c87d8880052c38779278f3f6da6b143c57f5f8fc252f529321c73fdfb32510:world"),
    ("protonmail", "//.attune/repository-world-v1/d88ee1076ffd84be98861f5002bbc14c55d667dd31ac773911c490f8cd33d41d:world"),
    ("babel", "//.attune/repository-world-v1/002a462e6f58440bbf60071f1e945b38bb304fe46a38ca6fdfd578248693cf01:world"),
]

FamiliesAcquiredInfo = provider(
    doc = "One acquired world: its recorded ledgers and its keyless replay proof.",
    fields = {
        "repository": "repository name",
        "snapshot_id": "complete semantic snapshot identity",
        "proof": "replay proof Parquet (attune-families-replay-proof-v1)",
        "embedding_ledger": "recorded embedding ledger Parquet",
        "decision_ledger": "recorded decision ledger Parquet",
    },
)

# The two acquisition evidence spaces (charter: the acquisition-zone carve-out).
EMBEDDING_SPACE = "families-embeddings-v1"
DECISION_SPACE = "jev-families-raw-v1"

# The worlds whose six typed evidence tables have been sealed as declared
# Bazel inputs. The Preact key preserves the already-published target names.
# Each further digest uses a stable target key derived from its snapshot ID.
def _world_digest(world):
    return world.rpartition("/")[2].partition(":")[0]

_PREACT_DIGEST = _world_digest(REPRESENTATIVE_WORLDS[0][1])

def _acquired_worlds():
    if _PREACT_DIGEST not in ACQUIRED_DIGESTS:
        fail("the frozen Preact acquisition must remain declared")
    worlds = [("preact", REPRESENTATIVE_WORLDS[0][1])] + [
        ("snapshot_" + _world_digest(world), world)
        for world in ATLAS_WORLDS
        if _world_digest(world) != _PREACT_DIGEST and _world_digest(world) in ACQUIRED_DIGESTS
    ]
    if len(worlds) != len(ACQUIRED_DIGESTS):
        fail("acquired evidence names a snapshot outside the frozen census")
    return worlds

ACQUIRED_WORLDS = _acquired_worlds()

# The families export of every acquired world (`export_<key>`, a
# `<snapshot digest>/` tree of the tables Atlas Live ships), for the web
# projection to stage beside its locations tables.
FAMILY_EXPORTS = ["//experiments/atlas-families:export_" + key for key, _ in ACQUIRED_WORLDS]

def _jvm_property(name, value):
    return "--jvm_flag=-D%s=%s" % (name, value)

def _digest(snapshot_id):
    return snapshot_id.rpartition(":")[2]

def _world_properties(world, path):
    return [
        ("attune.repository", world.repository),
        ("attune.base_revision", world.base_revision),
        ("attune.source_tree_identity", world.source_tree_identity),
        ("attune.fact_identity", world.fact_identity),
        ("attune.snapshot_id", world.snapshot_id),
        ("attune.world_metadata", path(world.metadata)),
        ("attune.world_entities", path(world.entities)),
        ("attune.world_relations", path(world.relations)),
    ]

def _families_inventory_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    inventory = ctx.actions.declare_file(ctx.label.name + "/inventory.parquet")
    args = ctx.actions.args()
    for name, value in [("attune.command", "inventory")] + _world_properties(world, lambda file: file.path) + [
        ("attune.output_inventory", inventory.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [world.metadata, world.entities, world.relations],
        outputs = [inventory],
        mnemonic = "FamiliesInventory",
        progress_message = "Measuring families inventory %{label}",
    )
    return [
        DefaultInfo(files = depset([inventory])),
        FamiliesInventoryInfo(inventory = inventory, snapshot_id = world.snapshot_id),
    ]

families_inventory = rule(
    implementation = _families_inventory_impl,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _families_inventory_report_impl(ctx):
    inventories = [target[FamiliesInventoryInfo].inventory for target in ctx.attr.inventories]
    report = ctx.actions.declare_file(ctx.label.name + ".md")
    args = ctx.actions.args()
    args.add(_jvm_property("attune.command", "report"))
    args.add(_jvm_property("attune.inventory.count", str(len(inventories))))
    for index, inventory in enumerate(inventories):
        args.add(_jvm_property("attune.inventory.%d" % index, inventory.path))
    args.add(_jvm_property("attune.output_report", report.path))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = inventories,
        outputs = [report],
        mnemonic = "FamiliesInventoryReport",
        progress_message = "Projecting families inventory report %{label}",
    )
    return [DefaultInfo(files = depset([report]))]

families_inventory_report = rule(
    implementation = _families_inventory_report_impl,
    attrs = {
        "inventories": attr.label_list(providers = [FamiliesInventoryInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def families_inventories(name, tool):
    """Declares `inventory_<key>` per representative world and the report over them.

    Args:
      name: the Markdown inventory projection target (`<name>.md`).
      tool: the families experiment tool.

    Returns:
      The per-world inventory labels, in report order.
    """
    labels = []
    for key, world in REPRESENTATIVE_WORLDS:
        if world not in ATLAS_WORLDS:
            fail("representative world is not a frozen census world: " + world)
        inventory = "inventory_" + key
        families_inventory(
            name = inventory,
            tool = tool,
            world = world,
        )
        labels.append(":" + inventory)
    families_inventory_report(
        name = name,
        inventories = labels,
        tool = tool,
    )
    return labels

def _families_protocol_impl(ctx):
    report = ctx.actions.declare_file(ctx.label.name + ".md")
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [
            _jvm_property("attune.command", "protocol"),
            _jvm_property("attune.output_report", report.path),
        ],
        outputs = [report],
        mnemonic = "FamiliesProtocol",
        progress_message = "Rendering families protocol constants %{label}",
    )
    return [DefaultInfo(files = depset([report]))]

families_protocol = rule(
    implementation = _families_protocol_impl,
    attrs = {"tool": attr.label(executable = True, cfg = "exec", mandatory = True)},
)

_ACQUIRE_TEMPLATE = """#!/usr/bin/env bash
# Live families acquisition for one world. It is the only entry point that can
# reach a provider; the key comes from the caller's environment (never from an
# argument), and every exchange is retained under the workspace's evidence
# spaces before admission. Usage (from the repository root):
#   bazel run --script_path=/tmp/acquire <this target>
#   ATTUNE_WORKSPACE=$PWD /tmp/acquire <source-root> project   # bound only, no provider
#   ATTUNE_WORKSPACE=$PWD /tmp/acquire <source-root> acquire
#   ATTUNE_WORKSPACE=$PWD /tmp/acquire <source-root> prefill-decisions <start> <count>
set -euo pipefail
workspace="${{BUILD_WORKSPACE_DIRECTORY:-${{ATTUNE_WORKSPACE:-}}}}"
if [ -z "$workspace" ]; then echo "set ATTUNE_WORKSPACE to the repository root" >&2; exit 2; fi
source_root="${{1:?usage: acquire <retained source root of the world> [project|acquire]}}"
command="${{2:-project}}"
case "$command" in project|acquire|prefill-embeddings|prefill-decisions|materialize) ;;
  *) echo "unknown command: $command" >&2; exit 2 ;; esac
if [ -n "${{RUNFILES_DIR:-}}" ]; then runfiles="$RUNFILES_DIR"
elif [ -d "$0.runfiles" ]; then runfiles="$(cd "$0.runfiles" && pwd)"
else runfiles="$(cd "$(dirname "$0")" && pwd)"; runfiles="${{runfiles%/_main*}}"
fi
export JAVA_RUNFILES="$runfiles"
# The live launcher runs on the user's 15 GiB / no-swap desktop. Bound its
# heap and direct buffers so a failed large pass cannot evict Hyprland.
exec "$runfiles/_main/{tool}" \\
  "--jvm_flag=-Xmx2048m" "--jvm_flag=-XX:MaxDirectMemorySize=512m" \\
  "--jvm_flag=-XX:ActiveProcessorCount=2" \\
  "--jvm_flag=-Dattune.command=$command" {properties} \\
  "--jvm_flag=-Dattune.source_root=$source_root" \\
  "--jvm_flag=-Dattune.seed_start=${{3:-0}}" \\
  "--jvm_flag=-Dattune.seed_count=${{4:-0}}" \\
  "--jvm_flag=-Dattune.embeddings_root=$workspace/.attune/{embeddings}" \\
  "--jvm_flag=-Dattune.decisions_root=$workspace/.attune/{decisions}"
"""

def _families_acquisition_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    digest = _digest(world.snapshot_id)
    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    properties = _world_properties(
        world,
        lambda file: "$runfiles/_main/" + file.short_path,
    )
    ctx.actions.write(
        output = launcher,
        content = _ACQUIRE_TEMPLATE.format(
            tool = ctx.executable.tool.short_path,
            properties = " ".join(['"%s"' % _jvm_property(name, value) for name, value in properties]),
            embeddings = EMBEDDING_SPACE + "/" + digest,
            decisions = DECISION_SPACE + "/" + digest,
        ),
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [world.metadata, world.entities, world.relations])
    runfiles = runfiles.merge(ctx.attr.tool[DefaultInfo].default_runfiles)
    return [DefaultInfo(executable = launcher, runfiles = runfiles)]

families_acquisition = rule(
    implementation = _families_acquisition_impl,
    executable = True,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "target", mandatory = True),
    },
)

def _space_root(files, name):
    for file in files:
        if file.basename == name:
            return file.dirname
    fail("evidence space has no " + name)

def _space_file(files, name):
    for file in files:
        if file.basename == name:
            return file
    fail("evidence space has no " + name)

def _families_replay_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    embeddings = ctx.files.embeddings
    decisions = ctx.files.decisions
    proof = ctx.actions.declare_file(ctx.label.name + "/replay-proof.parquet")
    args = ctx.actions.args()
    for name, value in [("attune.command", "replay")] + _world_properties(world, lambda file: file.path) + [
        ("attune.embeddings_root", _space_root(embeddings, "documents.parquet")),
        ("attune.decisions_root", _space_root(decisions, "decisions.parquet")),
        ("attune.output_proof", proof.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [world.metadata, world.entities, world.relations] + embeddings + decisions,
        outputs = [proof],
        mnemonic = "FamiliesReplay",
        progress_message = "Replaying families evidence keylessly %{label}",
    )
    return [
        DefaultInfo(files = depset([proof])),
        FamiliesAcquiredInfo(
            repository = world.repository,
            snapshot_id = world.snapshot_id,
            proof = proof,
            embedding_ledger = _space_file(embeddings, "ledger.parquet"),
            decision_ledger = _space_file(decisions, "ledger.parquet"),
        ),
    ]

families_replay = rule(
    implementation = _families_replay_impl,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "embeddings": attr.label(allow_files = True, mandatory = True),
        "decisions": attr.label(allow_files = True, mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _families_acquisition_report_impl(ctx):
    acquired = [target[FamiliesAcquiredInfo] for target in ctx.attr.replays]
    report = ctx.actions.declare_file(ctx.label.name + ".md")
    args = ctx.actions.args()
    args.add(_jvm_property("attune.command", "acquisition-report"))
    args.add(_jvm_property("attune.acquisition.count", str(len(acquired))))
    inputs = []
    for index, value in enumerate(acquired):
        prefix = "attune.acquisition.%d." % index
        args.add(_jvm_property(prefix + "repository", value.repository))
        args.add(_jvm_property(prefix + "snapshot_id", value.snapshot_id))
        args.add(_jvm_property(prefix + "proof", value.proof.path))
        args.add(_jvm_property(prefix + "embedding_ledger", value.embedding_ledger.path))
        args.add(_jvm_property(prefix + "decision_ledger", value.decision_ledger.path))
        inputs += [value.proof, value.embedding_ledger, value.decision_ledger]
    args.add(_jvm_property("attune.output_report", report.path))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = inputs,
        outputs = [report],
        mnemonic = "FamiliesAcquisitionReport",
        progress_message = "Projecting families acquisition report %{label}",
    )
    return [DefaultInfo(files = depset([report]))]

families_acquisition_report = rule(
    implementation = _families_acquisition_report_impl,
    attrs = {
        "replays": attr.label_list(providers = [FamiliesAcquiredInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _evidence_labels(world):
    digest = world.rpartition("/")[2].partition(":")[0]
    return (
        "//.attune/%s/%s:evidence" % (EMBEDDING_SPACE, digest),
        "//.attune/%s/%s:evidence" % (DECISION_SPACE, digest),
    )

def families_acquisitions(name, tool):
    """Declares `acquire_<key>` launchers, `replay_<key>` proofs, and the report.

    Args:
      name: the Markdown acquisition projection target (`<name>.md`).
      tool: the families experiment tool.

    Returns:
      The labels of both evidence filegroups of every acquired world.
    """
    evidence = []
    replays = []
    for key, world in ACQUIRED_WORLDS:
        if world not in ATLAS_WORLDS:
            fail("acquired world is not a frozen census world: " + world)
        families_acquisition(
            name = "acquire_" + key,
            tool = tool,
            world = world,
        )
        embeddings, decisions = _evidence_labels(world)
        families_replay(
            name = "replay_" + key,
            decisions = decisions,
            embeddings = embeddings,
            tool = tool,
            world = world,
        )
        replays.append(":replay_" + key)
        evidence += [decisions, embeddings]
    families_acquisition_report(
        name = name,
        replays = replays,
        tool = tool,
    )
    return evidence

def families_issue_blindness_tests(name, evidence):
    """Run the source and retained-payload law once per sealed world.

    Each test receives only that world's raw envelopes. This keeps the
    complete source-and-payload law while allowing BuildBuddy to distribute
    the acquired population across workers.
    """
    if len(evidence) != 2 * len(ACQUIRED_WORLDS):
        fail("issue-blindness evidence and acquired worlds disagree")
    tests = []
    for index, (key, _) in enumerate(ACQUIRED_WORLDS):
        test = name + "_" + key
        native.sh_test(
            name = test,
            size = "large",
            srcs = ["issue_blindness_test.sh"],
            data = [
                "Main.flix",
                ":families_sources",
                "issue_blindness_payload.awk",
                "@bazel_tools//tools/bash/runfiles",
            ] + evidence[2 * index:2 * index + 2],
        )
        tests.append(":" + test)
    native.test_suite(
        name = name,
        tests = tests,
    )

def families_launchers(tool):
    """Issue-blind live launchers for every frozen census snapshot.

    A launcher is an opt-in bazel-run tool, not a cached live network action.
    Keyless replay and every derived table become Bazel actions only after the
    recorded evidence for that snapshot has been sealed as declared inputs.
    """
    for world in ATLAS_WORLDS:
        digest = world.rpartition("/")[2].partition(":")[0]
        families_acquisition(
            name = "acquire_world_" + digest,
            tool = tool,
            world = world,
        )

# The clustering method's output tables (space `atlas-families-v1`), one
# directory per built run.
CLUSTERING_TABLES = ["families", "members", "rollups"]

FamiliesClusteringInfo = provider(
    doc = "One built clustering run of one acquired world, with everything it was derived from.",
    fields = {
        "world": "the AttuneWorldInfo of the clustered world",
        "embeddings": "the recorded embedding evidence files",
        "decisions": "the recorded decision evidence files",
        "tables": "dict: table name -> built Parquet file",
    },
)

def _families_clustering_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    embeddings = ctx.files.embeddings
    decisions = ctx.files.decisions
    tables = {
        table: ctx.actions.declare_file("%s/%s.parquet" % (ctx.label.name, table))
        for table in CLUSTERING_TABLES
    }
    args = ctx.actions.args()
    for name, value in [("attune.command", "cluster")] + _world_properties(world, lambda file: file.path) + [
        ("attune.embeddings_root", _space_root(embeddings, "documents.parquet")),
        ("attune.decisions_root", _space_root(decisions, "decisions.parquet")),
        ("attune.output_clustering", tables["families"].dirname),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [world.metadata, world.entities, world.relations] + embeddings + decisions,
        outputs = tables.values(),
        mnemonic = "FamiliesCluster",
        progress_message = "Clustering families from recorded evidence %{label}",
    )
    return [
        DefaultInfo(files = depset(tables.values())),
        FamiliesClusteringInfo(world = world, embeddings = embeddings, decisions = decisions, tables = tables),
    ]

families_clustering = rule(
    implementation = _families_clustering_impl,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "embeddings": attr.label(allow_files = True, mandatory = True),
        "decisions": attr.label(allow_files = True, mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _clustered_properties(index, run, rerun, path):
    """The `attune.clustered.<index>.*` properties of one world's two runs."""
    prefix = "attune.clustered.%d" % index
    root = lambda files, name: path(_space_file(files, name)).rpartition("/")[0]
    properties = [(prefix + "." + name.partition(".")[2], value) for name, value in _world_properties(run.world, path)]
    properties += [
        (prefix + ".embeddings_root", root(run.embeddings, "documents.parquet")),
        (prefix + ".decisions_root", root(run.decisions, "decisions.parquet")),
    ]
    for label, value in [("run", run), ("rerun", rerun)]:
        properties += [("%s.%s.%s" % (prefix, label, table), path(value.tables[table])) for table in CLUSTERING_TABLES]
    return properties

def _clustered_inputs(runs):
    inputs = []
    for run in runs:
        world = run.world
        inputs += [world.metadata, world.entities, world.relations] + run.embeddings + run.decisions + run.tables.values()
    return inputs

def _clustered_pairs(ctx):
    runs = [target[FamiliesClusteringInfo] for target in ctx.attr.runs]
    reruns = [target[FamiliesClusteringInfo] for target in ctx.attr.reruns]
    if len(runs) != len(reruns):
        fail("every clustering run needs its rerun")
    for run, rerun in zip(runs, reruns):
        if run.world.snapshot_id != rerun.world.snapshot_id:
            fail("a rerun clusters another world than its run")
    return runs, reruns

_CLUSTERED_ATTRS = {
    "runs": attr.label_list(providers = [FamiliesClusteringInfo], mandatory = True),
    "reruns": attr.label_list(providers = [FamiliesClusteringInfo], mandatory = True),
    "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
}

def _families_clustering_report_impl(ctx):
    runs, reruns = _clustered_pairs(ctx)
    report = ctx.actions.declare_file(ctx.label.name + ".md")
    args = ctx.actions.args()
    properties = [("attune.command", "clustering-report"), ("attune.clustered.count", str(len(runs)))]
    for index in range(len(runs)):
        properties += _clustered_properties(index, runs[index], reruns[index], lambda file: file.path)
    for name, value in properties + [("attune.output_report", report.path)]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = _clustered_inputs(runs + reruns),
        outputs = [report],
        mnemonic = "FamiliesClusteringReport",
        progress_message = "Projecting families clustering report %{label}",
    )
    return [DefaultInfo(files = depset([report]))]

families_clustering_report = rule(
    implementation = _families_clustering_report_impl,
    attrs = _CLUSTERED_ATTRS,
)

def _families_clustering_report_merge_impl(ctx):
    reports = ctx.files.reports
    if not reports:
        fail("a clustering report requires at least one acquired world")
    output = ctx.actions.declare_file(ctx.label.name + ".md")
    args = ctx.actions.args()
    args.add_all(reports)
    args.add(output)
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = reports,
        outputs = [output],
        mnemonic = "FamiliesClusteringReportMerge",
        progress_message = "Joining parallel families clustering reports %{label}",
    )
    return [DefaultInfo(files = depset([output]))]

families_clustering_report_merge = rule(
    implementation = _families_clustering_report_merge_impl,
    attrs = {
        "reports": attr.label_list(allow_files = True, mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

_LAW_TEMPLATE = """#!/usr/bin/env bash
# A families clustering law over the built `atlas-families-v1` tables; the
# Flix law command exits non-zero when any law fails.
set -euo pipefail
if [ -n "${{TEST_SRCDIR:-}}" ]; then runfiles="$TEST_SRCDIR"
elif [ -n "${{RUNFILES_DIR:-}}" ]; then runfiles="$RUNFILES_DIR"
else runfiles="$(cd "$0.runfiles" && pwd)"
fi
export JAVA_RUNFILES="$runfiles"
exec "$runfiles/_main/{tool}" {properties}
"""

def _runfile(file):
    return "$runfiles/_main/" + file.short_path

def _law_launcher(ctx, properties, files):
    """A test launcher running the families tool with `properties` over `files`."""
    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = launcher,
        content = _LAW_TEMPLATE.format(
            tool = ctx.executable.tool.short_path,
            properties = " \\\n  ".join(['"%s"' % _jvm_property(name, value) for name, value in properties]),
        ),
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = files)
    runfiles = runfiles.merge(ctx.attr.tool[DefaultInfo].default_runfiles)
    return [DefaultInfo(executable = launcher, runfiles = runfiles)]

def _families_law_test_impl(ctx):
    runs, reruns = _clustered_pairs(ctx)
    properties = [("attune.command", ctx.attr.command), ("attune.clustered.count", str(len(runs)))]
    for index in range(len(runs)):
        properties += _clustered_properties(index, runs[index], reruns[index], _runfile)
    return _law_launcher(ctx, properties, _clustered_inputs(runs + reruns))

families_law_test = rule(
    implementation = _families_law_test_impl,
    test = True,
    attrs = dict(_CLUSTERED_ATTRS, **{
        "command": attr.string(values = ["table-law", "family-law"], mandatory = True),
        "tool": attr.label(executable = True, cfg = "target", mandatory = True),
    }),
)

def families_clusterings(name, tool, merge_tool):
    """Declares the clustering of every acquired world, twice, and its laws.

    Per acquired world `<key>`: `cluster_<key>` (the method's tables, a
    content-addressed action output) and `cluster_<key>_rerun` (the same
    derivation as an independent action, so the determinism law compares two
    real runs). Over all of them: the Markdown report `<name>.md`, and the
    table law `atlas_families_table_test` and families law
    `atlas_families_law_test`.

    Args:
      name: the Markdown clustering projection target (`<name>.md`).
      tool: the families experiment tool.

    Returns:
      The labels of both law tests.
    """
    runs = []
    reruns = []
    reports = []
    for key, world in ACQUIRED_WORLDS:
        # Recorded vectors are decoded and digest-checked against the retained
        # embedding response bodies; typed tables alone are insufficient.
        embeddings, decisions = _evidence_labels(world)
        for label, labels in [("cluster_" + key, runs), ("cluster_%s_rerun" % key, reruns)]:
            families_clustering(
                name = label,
                decisions = decisions,
                embeddings = embeddings,
                tool = tool,
                world = world,
            )
            labels.append(":" + label)
        report = "clustering_report_" + key
        families_clustering_report(
            name = report,
            reruns = [reruns[-1]],
            runs = [runs[-1]],
            tool = tool,
        )
        reports.append(":" + report)
    families_clustering_report_merge(
        name = name,
        reports = reports,
        tool = merge_tool,
    )
    tests = []
    for test, command in [("atlas_families_table_test", "table-law"), ("atlas_families_law_test", "family-law")]:
        world_tests = []
        for (key, _), run, rerun in zip(ACQUIRED_WORLDS, runs, reruns):
            label = test + "_" + key
            families_law_test(
                name = label,
                size = "large",
                command = command,
                reruns = [rerun],
                runs = [run],
                tool = tool,
            )
            world_tests.append(":" + label)
        native.test_suite(
            name = test,
            tests = world_tests,
        )
        tests.append(":" + test)
    return tests

def _families_method_impl(ctx):
    report = ctx.actions.declare_file(ctx.label.name + ".md")
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [
            _jvm_property("attune.command", "method"),
            _jvm_property("attune.output_report", report.path),
        ],
        outputs = [report],
        mnemonic = "FamiliesMethod",
        progress_message = "Rendering families method constants %{label}",
    )
    return [DefaultInfo(files = depset([report]))]

families_method = rule(
    implementation = _families_method_impl,
    attrs = {"tool": attr.label(executable = True, cfg = "exec", mandatory = True)},
)

# The family-edge tables (space `atlas-families-v1`), one directory per built
# aggregation.
EDGE_TABLES = ["edges", "contributions"]

FamiliesEdgesInfo = provider(
    doc = "One built family-edge aggregation of one clustered world.",
    fields = {
        "clustering": "the FamiliesClusteringInfo it aggregates",
        "tables": "dict: table name -> built Parquet file",
    },
)

FamiliesExportInfo = provider(
    doc = "One world's families export: the tree Atlas Live ships as data/<digest>/.",
    fields = {
        "edges": "the FamiliesEdgesInfo it exports",
        "directory": "the export tree artifact, named by the snapshot digest",
        "digest": "the snapshot digest",
    },
)

def _table_properties(prefix, stage, tables, path):
    return [("%s.%s.%s" % (prefix, stage, table), path(file)) for table, file in tables.items()]

def _world_inputs(world):
    return [world.metadata, world.entities, world.relations]

def _families_edges_impl(ctx):
    clustering = ctx.attr.clustering[FamiliesClusteringInfo]
    world = clustering.world
    tables = {
        table: ctx.actions.declare_file("%s/%s.parquet" % (ctx.label.name, table))
        for table in EDGE_TABLES
    }
    path = lambda file: file.path
    args = ctx.actions.args()
    for name, value in [("attune.command", "edges")] + _world_properties(world, path) + _table_properties("attune", "cluster", clustering.tables, path) + [
        ("attune.output_edges", tables["edges"].dirname),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = _world_inputs(world) + clustering.tables.values(),
        outputs = tables.values(),
        mnemonic = "FamiliesEdges",
        progress_message = "Aggregating family edges %{label}",
    )
    return [
        DefaultInfo(files = depset(tables.values())),
        FamiliesEdgesInfo(clustering = clustering, tables = tables),
    ]

families_edges = rule(
    implementation = _families_edges_impl,
    attrs = {
        "clustering": attr.label(providers = [FamiliesClusteringInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _families_export_impl(ctx):
    edges = ctx.attr.edges[FamiliesEdgesInfo]
    world = edges.clustering.world
    digest = _digest(world.snapshot_id)
    directory = ctx.actions.declare_directory(digest)
    path = lambda file: file.path
    args = ctx.actions.args()
    for name, value in [("attune.command", "export")] + _world_properties(world, path) + _table_properties("attune", "cluster", edges.clustering.tables, path) + _table_properties("attune", "edges", edges.tables, path) + [
        ("attune.output_export", directory.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = _world_inputs(world) + edges.clustering.tables.values() + edges.tables.values(),
        outputs = [directory],
        mnemonic = "FamiliesExport",
        progress_message = "Exporting families for Atlas Live %{label}",
    )
    return [
        DefaultInfo(files = depset([directory])),
        FamiliesExportInfo(edges = edges, directory = directory, digest = digest),
    ]

families_export = rule(
    implementation = _families_export_impl,
    attrs = {
        "edges": attr.label(providers = [FamiliesEdgesInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _exported_properties(index, export, path):
    """The `attune.exported.<index>.*` properties of one exported world."""
    prefix = "attune.exported.%d" % index
    edges = export.edges
    properties = [(prefix + "." + name.partition(".")[2], value) for name, value in _world_properties(edges.clustering.world, path)]
    properties += _table_properties(prefix, "cluster", edges.clustering.tables, path)
    properties += _table_properties(prefix, "edges", edges.tables, path)
    return properties + [(prefix + ".export", path(export.directory)), (prefix + ".digest", export.digest)]

def _exported(ctx, path):
    exports = [target[FamiliesExportInfo] for target in ctx.attr.exports]
    properties = [("attune.exported.count", str(len(exports)))]
    inputs = []
    for index, export in enumerate(exports):
        properties += _exported_properties(index, export, path)
        inputs += _world_inputs(export.edges.clustering.world) + export.edges.clustering.tables.values() + export.edges.tables.values() + [export.directory]
    return properties, inputs

def _families_export_report_impl(ctx):
    properties, inputs = _exported(ctx, lambda file: file.path)
    report = ctx.actions.declare_file(ctx.label.name + ".md")
    args = ctx.actions.args()
    for name, value in [("attune.command", "export-report")] + properties + [("attune.output_report", report.path)]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = inputs,
        outputs = [report],
        mnemonic = "FamiliesExportReport",
        progress_message = "Projecting families edge and export report %{label}",
    )
    return [DefaultInfo(files = depset([report]))]

families_export_report = rule(
    implementation = _families_export_report_impl,
    attrs = {
        "exports": attr.label_list(providers = [FamiliesExportInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _families_export_law_test_impl(ctx):
    properties, inputs = _exported(ctx, _runfile)
    staging = ctx.files.staging
    if (ctx.attr.command == "parity") != (len(staging) == 1):
        fail("the parity law, and only it, reads exactly one staging directory")
    for directory in staging:
        properties.append(("attune.staging_root", _runfile(directory)))
    return _law_launcher(ctx, [("attune.command", ctx.attr.command)] + properties, inputs + staging)

families_export_law_test = rule(
    implementation = _families_export_law_test_impl,
    test = True,
    attrs = {
        "command": attr.string(values = ["edge-table-law", "edge-law", "parity"], mandatory = True),
        "exports": attr.label_list(providers = [FamiliesExportInfo], mandatory = True),
        "staging": attr.label(allow_files = True),
        "tool": attr.label(executable = True, cfg = "target", mandatory = True),
    },
)

def families_exports(name, tool, staging):
    """Declares the family edges and the Atlas Live export of every clustered world.

    Per acquired world `<key>`: `edges_<key>` (the family-edge tables of
    `cluster_<key>`, a content-addressed action output) and `export_<key>`
    (the `<snapshot digest>/` tree Atlas Live ships, see FAMILY_EXPORTS). Over
    all of them: the Markdown report `<name>.md`, the table law
    `atlas_family_edges_table_test`, the edge law `atlas_family_edges_law_test`,
    and the cross-layer parity law `families_export_parity_test` against the
    web projection's staging of the exports.

    Args:
      name: the Markdown edge and export projection target (`<name>.md`).
      tool: the families experiment tool.
      staging: the web projection's staging directory of FAMILY_EXPORTS.

    Returns:
      The labels of the three law tests.
    """
    exports = []
    for key, _ in ACQUIRED_WORLDS:
        families_edges(
            name = "edges_" + key,
            clustering = ":cluster_" + key,
            tool = tool,
        )
        families_export(
            name = "export_" + key,
            edges = ":edges_" + key,
            tool = tool,
        )
        exports.append(":export_" + key)
    families_export_report(
        name = name,
        exports = exports,
        tool = tool,
    )
    tests = []
    for test, command in [
        ("atlas_family_edges_table_test", "edge-table-law"),
        ("atlas_family_edges_law_test", "edge-law"),
        ("families_export_parity_test", "parity"),
    ]:
        if command == "parity":
            families_export_law_test(
                name = test,
                size = "large",
                command = command,
                exports = exports,
                staging = staging,
                tool = tool,
            )
        else:
            world_tests = []
            for (key, _), export in zip(ACQUIRED_WORLDS, exports):
                label = test + "_" + key
                families_export_law_test(
                    name = label,
                    size = "large",
                    command = command,
                    exports = [export],
                    tool = tool,
                )
                world_tests.append(":" + label)
            native.test_suite(
                name = test,
                tests = world_tests,
            )
        tests.append(":" + test)
    return tests
