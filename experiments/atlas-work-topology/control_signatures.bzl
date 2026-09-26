"""Bazel wiring for the control signature instrument (PREREGISTRATION.md §3, §9).

The instrument re-admits the committed control evidence and evaluates the
frozen depth-7 Atlas family in Flix; these rules only pass the committed
evidence (as read-only inputs) and the artifact paths (as JVM properties). It
reuses the frozen Atlas/Repository/ScientificTable machinery unchanged and
adds no grammar, atom or evaluator.
"""

load("//test/build:flix.bzl", "checked_test", "flix_check", "flix_fatjar")

# The one control world identity: the same seam the acquisition froze, read
# back through ordinary Repository admission at measurement time.
_SIGNATURE_SRCS = [
    "ControlIdentity.flix",
    "ControlMap.flix",
    "ControlSignature.flix",
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

_SIGNATURE_JAVA_DEPS = [
    "//src/native/identity:attune_identity",
    "//src/native/parquet:attune_parquet",
]

def attune_control_signatures(name = "control_signatures"):
    """The control signature executable and its `bazel run` command of record."""
    flix_fatjar(
        name = name + "_flix",
        srcs = _SIGNATURE_SRCS + ["ControlSignaturesMain.flix"],
        java_deps = _SIGNATURE_JAVA_DEPS,
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
        name = "compute_control_signatures",
        srcs = ["compute_signatures.sh"],
        data = [
            ":" + name + "_bin",
            "@bazel_tools//tools/bash/runfiles",
        ],
    )

def attune_control_signature_artifacts_test(name = "control_signature_artifacts_test"):
    """Re-derives the landmarks and identity map from the committed evidence and
    compares them with the committed artifacts; a mismatch is a non-zero exit."""
    native.sh_test(
        name = name,
        size = "medium",
        srcs = ["control_signature_artifacts_test.sh"],
        data = [
            ":control_signatures_bin",
            ":control_files",
            "@bazel_tools//tools/bash/runfiles",
        ],
    )

def attune_control_signature_check(name = "control_signature_check"):
    """Provenance and protocol law tests (synthetic worlds, no commit needed)."""
    flix_check(
        name = name,
        srcs = _SIGNATURE_SRCS + ["ControlSignatureTest.flix"],
        command = "test",
        java_deps = _SIGNATURE_JAVA_DEPS,
        threads = 2,
    )
    checked_test(
        name = "control_signature_test",
        check = ":" + name,
    )
