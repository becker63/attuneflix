"""Bazel wiring for the control work-topology measurement (PREREGISTRATION.md §6, §8).

The measurement re-admits the committed control evidence through the frozen
`ControlSignature.world` seam and evaluates the frozen depth-2 File-domain Atlas
family; these rules only pass the committed evidence and the artifact paths
(as JVM properties). No grammar, atom or evaluator is added, and no source text
is parsed here.
"""

load("//test/build:flix.bzl", "checked_test", "flix_check", "flix_fatjar")

_TOPOLOGY_SRCS = [
    "ControlCoChange.flix",
    "ControlIdentity.flix",
    "ControlMap.flix",
    "ControlMeasure.flix",
    "ControlSignature.flix",
    "ControlTopology.flix",
    "ControlTopologyJson.flix",
    "//experiments/atlas-parallelism:AcquisitionFacts.flix",
    "//src:Atlas.flix",
    "//src:Atlas/Signature.flix",
    "//src:Atlas/Signature/Summary.flix",
    "//src:Atlas/Signature/Table.flix",
    "//src:Experiment.flix",
    "//src:Radii.flix",
    "//src:Repository.flix",
    "//src:Repository/Grit.flix",
    "//src:Repository/Physical.flix",
    "//src:Repository/Structure.flix",
    "//src:Repository/Table.flix",
    "//src:ScientificIdentity.flix",
    "//src:ScientificTable.flix",
    "//src:ScientificTable/Columns.flix",
]

_TOPOLOGY_JAVA_DEPS = [
    "//src/native/identity:attune_identity",
    "//src/native/parquet:attune_parquet",
]

def attune_control_topology(name = "control_topology"):
    """The measurement executable and its `bazel run` command of record."""
    flix_fatjar(
        name = name + "_flix",
        srcs = _TOPOLOGY_SRCS + ["ControlMeasureMain.flix"],
        java_deps = _TOPOLOGY_JAVA_DEPS,
        threads = 2,
    )
    native.java_binary(
        name = name + "_bin",
        jvm_flags = [
            "--add-opens=java.base/java.nio=ALL-UNNAMED",
            "--enable-native-access=ALL-UNNAMED",
        ],
        main_class = "Main",
        runtime_deps = [":" + name + "_flix"],
    )
    native.sh_binary(
        name = "measure_control_topology",
        srcs = ["measure_topology.sh"],
        data = [
            ":" + name + "_bin",
            "@bazel_tools//tools/bash/runfiles",
        ],
    )

def attune_control_topology_check(name = "control_topology_check"):
    """Provenance and protocol law tests (synthetic worlds, no commit needed)."""
    flix_check(
        name = name,
        srcs = _TOPOLOGY_SRCS + ["ControlTopologyTest.flix"],
        command = "test",
        java_deps = _TOPOLOGY_JAVA_DEPS,
        threads = 2,
    )
    checked_test(
        name = "control_topology_test",
        check = ":" + name,
    )

def attune_control_topology_artifacts_test(name = "control_topology_artifacts_test"):
    """Re-derives the topology document and the co-change graph from the
    committed evidence and compares them with the committed artifacts. Reads the
    world boundary and the topology stage's document boundary only."""
    native.sh_test(
        name = name,
        size = "medium",
        srcs = ["control_topology_artifacts_test.sh"],
        data = [
            ":control_topology_artifacts",
            ":control_topology_bin",
            ":control_world_artifacts",
            "@bazel_tools//tools/bash/runfiles",
        ],
    )
