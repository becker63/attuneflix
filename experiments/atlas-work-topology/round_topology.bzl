"""Bazel wiring for the Round 1 candidate measurement (PREREGISTRATION.md §9,
§10, §11; VAL-HC1-002, VAL-HC1-003).

The round instrument reuses the frozen control evidence, the ordinary
`Repository` admission seam and the frozen Atlas signature machinery unchanged;
these rules only pass the committed evidence (read-only inputs) and the
artifact paths (JVM properties). No grammar, atom, evaluator or fact
acquisition is added, and no source text is parsed by the measurement itself.
"""

load("//test/build:flix.bzl", "checked_test", "flix_check", "flix_fatjar")

_ROUND_SRCS = [
    "ControlIdentity.flix",
    "ControlMap.flix",
    "ControlSignature.flix",
    "ControlTopology.flix",
    "RoundIdentity.flix",
    "RoundJson.flix",
    "RoundOracle.flix",
    "RoundTopology.flix",
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

_ROUND_JAVA_DEPS = [
    "//src/native/identity:attune_identity",
    "//src/native/parquet:attune_parquet",
]

def attune_round_topology(name = "round_topology"):
    """The round measurement executable and its `bazel run` command of record."""
    flix_fatjar(
        name = name + "_flix",
        srcs = _ROUND_SRCS + ["RoundMeasure.flix", "RoundMeasureMain.flix"],
        java_deps = _ROUND_JAVA_DEPS,
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
        name = "measure_topology",
        srcs = ["round_measure.sh"],
        data = [
            ":" + name + "_bin",
            "@bazel_tools//tools/bash/runfiles",
        ],
    )

def attune_round_check(name = "round_check"):
    """Protocol and provenance law tests (synthetic worlds, no commit needed)."""
    flix_check(
        name = name,
        srcs = _ROUND_SRCS + ["RoundMeasure.flix", "RoundTest.flix"],
        command = "test",
        java_deps = _ROUND_JAVA_DEPS,
        threads = 2,
    )
    checked_test(
        name = "round_test",
        check = ":" + name,
    )

def attune_round_artifacts_test(name = "round1_artifacts_test"):
    """Re-derives the round identity map, topology and oracle from the committed
    evidence and compares them with the committed artifacts; a mismatch is a
    non-zero exit."""
    native.sh_test(
        name = name,
        size = "medium",
        srcs = ["round_artifacts_test.sh"],
        data = [
            ":round_topology_bin",
            ":control_files",
            ":round1_files",
            "@bazel_tools//tools/bash/runfiles",
        ],
    )
