"""Declared typed-artifact stage boundaries (K4 Hill-Climb Round 4).

PREREGISTRATION.md §7 and §14 bind four `bazel run` commands of record; this
file adds the *build-graph* boundary for the two expensive scientific stages
among them:

  signatures : the depth 1..7 Atlas signature derivation
               (`ControlSignature.compute`, `attune.command=compute`) over the
               frozen world, writing the typed observation and summary tables
               plus the logical identity map.
  topology   : the static work-topology and co-change measurement
               (`ControlMeasure.measure`, `attune.command=measure`) over the
               frozen world and the frozen co-change history extract, writing
               the two topology documents.

Both stages are pure deterministic functions of the frozen typed Parquet
evidence: nothing in them reads the ambient environment, the VCS state or any
source text. They are therefore declared here as ordinary Bazel actions whose
declared inputs are exactly that evidence and whose declared outputs are the
typed artifacts. Consequences the round is after:

- **Independent rebuilds.** The action's input set is the stage's typed
  evidence and the stage's own Flix sources (through the tool's runfiles), and
  nothing else in the repository: editing a law, an application module or
  another experiment's wiring cannot invalidate either stage.
- **Cache reuse for downstream consumers.** A consumer that reads a declared
  output (`//experiments/atlas-work-topology:control_signature_tables`,
  `:control_topology_documents`, or one of their `OutputGroupInfo` groups) gets
  the typed artifact from the action cache instead of re-deriving it.
  `bazel build <stage> --config=buildbuddy-rbe` twice reports the second run as
  a cache hit; `//experiments/atlas-work-topology:artifact_boundary_test` is
  the in-graph consumer that checks the declared artifacts against the frozen
  committed evidence.

The `bazel run` commands of record stay unchanged: they write the committed
artifacts under `control/` (PREREGISTRATION.md §14), and the actions declared
here re-derive the same bytes as declared build outputs. No grammar, atom,
evaluator or typed schema is added or changed; nothing under `src/` moves.
"""

# The frozen world boundary is declared as ordinary `filegroup`s by the
# package, so the mapping from an input file to the JVM property the stage
# reads is keyed by basename.
_INPUT_PROPERTIES = {
    "control.sources.parquet": "attune.sources",
    "control.facts.parquet": "attune.facts",
    "control.revision.txt": "attune.revision",
    "control.files.txt": "attune.files",
    "control.cochange_history.txt": "attune.cochange_history",
}

# stage -> struct(command, mnemonic, progress, outputs)
# outputs: (declared basename, JVM property the stage writes, output group)
_STAGES = {
    "signatures": struct(
        command = "compute",
        mnemonic = "AttuneControlSignatures",
        progress = "Deriving the typed depth 1..7 signature artifacts",
        outputs = [
            ("control.signatures.parquet", "attune.output_signatures", "signatures"),
            ("control.summaries.parquet", "attune.output_summaries", "summaries"),
            ("control.identity_map.json", "attune.output_identity", "identity_map"),
        ],
    ),
    "topology": struct(
        command = "measure",
        mnemonic = "AttuneControlTopology",
        progress = "Deriving the typed work-topology and co-change documents",
        outputs = [
            ("control.topology.json", "attune.output_topology", "topology"),
            ("control.cochange.json", "attune.output_cochange", "cochange"),
        ],
    ),
}

def _stage_impl(ctx):
    stage = _STAGES[ctx.attr.stage]
    args = ctx.actions.args()
    args.add("--jvm_flag=-Dattune.command=%s" % stage.command)
    for evidence in ctx.files.evidence:
        property_name = _INPUT_PROPERTIES.get(evidence.basename)
        if property_name == None:
            fail("no JVM property is declared for stage input %s" % evidence.basename)
        args.add("--jvm_flag=-D%s=%s" % (property_name, evidence.path))
    declared = []
    groups = {}
    for basename, property_name, group in stage.outputs:
        artifact = ctx.actions.declare_file(ctx.label.name + "/" + basename)
        args.add("--jvm_flag=-D%s=%s" % (property_name, artifact.path))
        declared.append(artifact)
        groups[group] = depset([artifact])
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = ctx.files.evidence,
        outputs = declared,
        mnemonic = stage.mnemonic,
        progress_message = stage.progress + " %{label}",
    )
    return [
        DefaultInfo(files = depset(declared)),
        OutputGroupInfo(**groups),
    ]

attune_control_stage = rule(
    implementation = _stage_impl,
    doc = """One expensive scientific stage as a declared, cacheable action.

`evidence` is the stage's complete typed input boundary; `tool` is the stage's
`java_binary` (it carries the stage's Flix sources in its runfiles, so a source
change invalidates exactly this action). The stage's own `attune.command`
selects the measurement, and every artifact path is a declared output.""",
    attrs = {
        "stage": attr.string(mandatory = True, values = _STAGES.keys()),
        "evidence": attr.label_list(allow_files = True, mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def attune_artifact_boundary_test(name = "artifact_boundary_test"):
    """The downstream consumer of the declared stage artifacts.

    Reads the declared outputs of `//...:control_signature_tables` and
    `//...:control_topology_documents` and checks each one against the frozen
    committed evidence under `control/`, so reusing a cached artifact is only
    sound when the stage re-derives the frozen bytes. It never re-runs a stage
    itself and never reads the ambient environment: the derivation is the
    cached action's, the comparison is `cmp`."""
    native.sh_test(
        name = name,
        size = "medium",
        srcs = ["artifact_boundary_test.sh"],
        data = [
            ":control_signature_artifacts",
            ":control_signature_tables",
            ":control_topology_artifacts",
            ":control_topology_documents",
            ":control_world_artifacts",
            "@bazel_tools//tools/bash/runfiles",
        ],
    )
