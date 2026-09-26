"""Bazel wiring for the work-topology & K4 experiment (PREREGISTRATION.md §2).

Control acquisition reuses the frozen polyglot acquisition seam
(`//experiments/atlas-parallelism:Acquisition*`): the one
`Repository.Grit.Fact` protocol and ordinary `Repository.admit` carry the
control world. The experiment owns only `ControlAcquisition.flix` (the
inclusion record + determinism check) and the thin `bazel run` / `bazel test`
launchers; no second parser, no lexical proxy.
"""

load("//test/build:flix.bzl", "flix_fatjar")

# The control revision is a declared protocol constant, never read from the
# ambient environment.
CONTROL_REVISION = "eca979f524661cbe400d22b90c7e3c305b32052e"

_CONTROL_ARTIFACTS = [
    "control/control.files.txt",
    "control/control.revision.txt",
    "control/control.sources.parquet",
    "control/control.facts.parquet",
]

def attune_control_acquisition(name = "acquire"):
    """The control acquisition executable and its `bazel run` command of record."""
    flix_fatjar(
        name = name + "_flix",
        srcs = [
            "ControlMain.flix",
            "ControlAcquisition.flix",
            "ControlMap.flix",
            "//experiments/atlas-parallelism:AcquisitionDriver.flix",
            "//experiments/atlas-parallelism:AcquisitionFacts.flix",
            "//src:Experiment.flix",
            "//src:Repository.flix",
            "//src:Repository/Acquire.flix",
            "//src:Repository/Grit.flix",
            "//src:Repository/Structure.flix",
            "//src:ScientificIdentity.flix",
            "//src:ScientificTable.flix",
            "//src:ScientificTable/Columns.flix",
        ],
        java_deps = [
            "//src/native/grit:attune_grit",
            "//src/native/identity:attune_identity",
            "//src/native/parquet:attune_parquet",
        ],
        threads = 2,
    )
    native.java_binary(
        name = name + "_bin",
        data = ["//src/native/grit:attune_grit_abi"],
        jvm_flags = [
            "--add-opens=java.base/java.nio=ALL-UNNAMED",
            "--enable-native-access=ALL-UNNAMED",
            "-Djava.library.path=$${JAVA_RUNFILES}/_main/src/native/grit",
        ],
        main_class = "Main",
        runtime_deps = [":" + name + "_flix"],
    )
    native.sh_binary(
        name = name,
        srcs = ["acquire.sh"],
        args = [CONTROL_REVISION],
        data = [
            ":" + name + "_bin",
            "@bazel_tools//tools/bash/runfiles",
        ],
    )

def attune_control_reproducibility_test(name = "control_reproducibility_test"):
    """Re-acquisition determinism (VAL-CONTROL-003): needs the isolated /tmp
    worktree and the native engine, so it runs locally unsandboxed while all
    comparison logic stays in Flix."""
    native.sh_test(
        name = name,
        size = "medium",
        srcs = ["control_reproducibility_test.sh"],
        args = [CONTROL_REVISION],
        data = [
            ":acquire_bin",
            ":control_world_artifacts",
            "@bazel_tools//tools/bash/runfiles",
        ],
        local = True,
        tags = ["no-sandbox"],
    )
