"""Per-world wiring for the Atlas Families experiment.

Starlark passes artifact paths and identity strings as JVM properties (action
transport, not scientific data); the Flix tool owns every derivation and typed
table. World labels come from the frozen census graph and are never re-declared.
"""

load("//build:attune.bzl", "AttuneWorldInfo")
load("//experiments/atlas-swe-explore/census:census.bzl", "ATLAS_WORLDS")

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

# The worlds acquired so far, in report order. Each world's evidence lives at
# `.attune/<space>/<snapshot digest>/` and is exported by that directory's
# `:evidence` filegroup. Scaling to further representative worlds happens only
# after the milestone-1 review of protocol, cost, and storage.
ACQUIRED_WORLDS = [
    ("preact", REPRESENTATIVE_WORLDS[0][1]),
]

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
set -euo pipefail
workspace="${{BUILD_WORKSPACE_DIRECTORY:-${{ATTUNE_WORKSPACE:-}}}}"
if [ -z "$workspace" ]; then echo "set ATTUNE_WORKSPACE to the repository root" >&2; exit 2; fi
source_root="${{1:?usage: acquire <retained source root of the world> [project|acquire]}}"
command="${{2:-project}}"
case "$command" in project|acquire) ;; *) echo "unknown command: $command" >&2; exit 2 ;; esac
if [ -n "${{RUNFILES_DIR:-}}" ]; then runfiles="$RUNFILES_DIR"
elif [ -d "$0.runfiles" ]; then runfiles="$(cd "$0.runfiles" && pwd)"
else runfiles="$(cd "$(dirname "$0")" && pwd)"; runfiles="${{runfiles%/_main*}}"
fi
export JAVA_RUNFILES="$runfiles"
exec "$runfiles/_main/{tool}" "--jvm_flag=-Dattune.command=$command" {properties} \\
  "--jvm_flag=-Dattune.source_root=$source_root" \\
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
        digest = world.rpartition("/")[2].partition(":")[0]
        decisions = "//.attune/%s/%s:evidence" % (DECISION_SPACE, digest)
        embeddings = "//.attune/%s/%s:evidence" % (EMBEDDING_SPACE, digest)
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
