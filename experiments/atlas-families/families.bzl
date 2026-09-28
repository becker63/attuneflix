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

def _jvm_property(name, value):
    return "--jvm_flag=-D%s=%s" % (name, value)

def _families_inventory_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    inventory = ctx.actions.declare_file(ctx.label.name + "/inventory.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.command", "inventory"),
        ("attune.repository", world.repository),
        ("attune.base_revision", world.base_revision),
        ("attune.source_tree_identity", world.source_tree_identity),
        ("attune.fact_identity", world.fact_identity),
        ("attune.snapshot_id", world.snapshot_id),
        ("attune.world_metadata", world.metadata.path),
        ("attune.world_entities", world.entities.path),
        ("attune.world_relations", world.relations.path),
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
