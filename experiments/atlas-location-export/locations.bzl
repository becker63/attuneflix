"""One typed locations table per frozen world, expanded into the caller's package.

`location_exports` returns the created target labels so the caller can stage all
of them in one content-addressed directory (the projection `:data` target and the
World parity law both do this).
"""

load("//build:attune.bzl", "attune_location_labels")
load("//experiments/atlas-swe-explore/census:census.bzl", "ATLAS_WORLDS")

def location_exports(tool):
    """Declares `location_<key>` per ATLAS_WORLD; returns their labels."""
    labels = []
    for index, world in enumerate(ATLAS_WORLDS):
        key = ("0" if index < 10 else "") + str(index)
        name = "location_" + key
        attune_location_labels(
            name = name,
            tool = tool,
            world = world,
        )
        labels.append(":" + name)
    return labels
