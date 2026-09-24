AttuneWorldInfo = provider(
    doc = "One typed admitted repository world and its semantic identity.",
    fields = {
        "metadata": "world metadata Parquet",
        "entities": "world entity Parquet",
        "relations": "world basis-relation Parquet",
        "identity": "canonical JSON identity emitted with the world, or None",
        "repository": "repository identity",
        "base_revision": "frozen base revision",
        "source_tree_identity": "implementation-independent source-tree identity",
        "fact_identity": "admitted fact identity",
        "snapshot_id": "complete snapshot identity",
    },
)

AttuneSignatureInfo = provider(
    doc = "One exact Atlas signature shard for one admitted snapshot.",
    fields = {
        "observations": "logical route observations Parquet",
        "physical": "physical execution counters Parquet",
        "snapshot": "snapshot summary Parquet",
        "repository": "repository identity",
        "base_revision": "frozen base revision",
        "source_tree_identity": "implementation-independent source-tree identity",
        "fact_identity": "admitted fact identity",
        "snapshot_id": "complete semantic snapshot identity",
    },
)

AttuneSignatureSummaryInfo = provider(
    doc = "One compact, regenerable summary of an immutable Atlas signature shard.",
    fields = {
        "summary": "typed long-form signature summary Parquet",
        "snapshot": "typed snapshot row copied from the signature provider",
        "physical": "typed physical rows copied from the signature provider",
    },
)

AttuneAtlasAggregateInfo = provider(
    doc = "Canonical aggregate tables over compact Atlas signature shards.",
    fields = {
        "summaries": "all long-form signature summary rows",
        "snapshots": "one typed row per frozen snapshot",
        "physical": "all per-seed physical rows",
    },
)

AttuneDecisionBundleInfo = provider(
    doc = "One typed keyless replay bundle.",
    fields = {"bundle": "decision bundle Parquet"},
)

AttunePriorInfo = provider(
    doc = "One typed frozen semantic prior.",
    fields = {
        "metadata": "provider/protocol/case metadata Parquet",
        "documents": "exact ranked document corpus Parquet",
        "ranking": "ordered semantic-prior ranking Parquet",
    },
)

AttuneIssueInfo = provider(
    doc = "One typed admitted localization issue.",
    fields = {"issue": "single-row issue Parquet"},
)

AttunePredictionInfo = provider(
    doc = "One typed frozen localization prediction.",
    fields = {
        "summary": "case/path/physical-work summary Parquet",
        "ranking": "ordered predicted semantic identities Parquet",
        "decisions": "ordered admitted decision observations Parquet",
        "probabilities": "per-decision alternative probabilities Parquet",
    },
)

def _localization_case_impl(ctx):
    files = [
        ctx.file.issue,
        ctx.file.prior_metadata,
        ctx.file.prior_documents,
        ctx.file.prior_ranking,
        ctx.file.prediction_summary,
        ctx.file.prediction_ranking,
        ctx.file.prediction_decisions,
        ctx.file.prediction_probabilities,
        ctx.file.decision_bundle,
    ]
    return [
        DefaultInfo(files = depset(files)),
        AttuneIssueInfo(issue = ctx.file.issue),
        AttunePriorInfo(
            metadata = ctx.file.prior_metadata,
            documents = ctx.file.prior_documents,
            ranking = ctx.file.prior_ranking,
        ),
        AttunePredictionInfo(
            summary = ctx.file.prediction_summary,
            ranking = ctx.file.prediction_ranking,
            decisions = ctx.file.prediction_decisions,
            probabilities = ctx.file.prediction_probabilities,
        ),
        AttuneDecisionBundleInfo(bundle = ctx.file.decision_bundle),
    ]

attune_localization_case = rule(
    implementation = _localization_case_impl,
    attrs = {
        "issue": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "prior_metadata": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "prior_documents": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "prior_ranking": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "prediction_summary": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "prediction_ranking": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "prediction_decisions": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "prediction_probabilities": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "decision_bundle": attr.label(allow_single_file = [".parquet"], mandatory = True),
    },
)

AttuneLocalizationReplayInfo = provider(
    doc = "One exact keyless localization replay result.",
    fields = {
        "summary": "typed replayed prediction summary Parquet",
        "ranking": "typed replayed prediction ranking Parquet",
        "decisions": "typed replayed prediction decisions Parquet",
        "probabilities": "typed replayed prediction probabilities Parquet",
        "proof": "typed exact-equality and execution telemetry Parquet",
    },
)

AttuneLocalizationReplaysInfo = provider(
    doc = "Aggregate exact-equality proof for every admissible localization case.",
    fields = {"proof": "61-row typed replay proof Parquet"},
)

AttuneLocalizationEvaluationInfo = provider(
    doc = "One official SWE-Explore case evaluation with frozen-result parity proof.",
    fields = {
        "metrics": "three condition metric rows",
        "regions": "ordered top-five regions for every condition",
        "telemetry": "oracle recurrence/compression counters",
        "proof": "exact-discrete and tolerant-floating parity proof",
    },
)

AttuneLocalizationEvaluationsInfo = provider(
    doc = "Canonical aggregate official evaluation tables and parity proof.",
    fields = {
        "metrics": "all three-condition metric rows",
        "regions": "all ordered top-five region rows",
        "telemetry": "one oracle compression row per case",
        "proof": "one exact parity row per case",
    },
)

AttuneAtlasLocalizationInfo = provider(
    doc = "Post-hoc typed join of two independently frozen experiments.",
    fields = {
        "cases": "one typed row per completed localization case",
        "report": "plain-language post-hoc analysis report",
    },
)

def _jvm_property(name, value):
    return "--jvm_flag=-D%s=%s" % (name, value)

def _add_indexed(args, prefix, files):
    args.add(_jvm_property(prefix + ".count", str(len(files))))
    for index, file in enumerate(files):
        args.add(_jvm_property("%s.%d" % (prefix, index), file.path))

def _world_info(ctx, metadata, entities, relations, identity = None):
    return AttuneWorldInfo(
        metadata = metadata,
        entities = entities,
        relations = relations,
        identity = identity,
        repository = ctx.attr.repository,
        base_revision = ctx.attr.base_revision,
        source_tree_identity = ctx.attr.source_tree_identity,
        fact_identity = ctx.attr.fact_identity,
        snapshot_id = ctx.attr.snapshot_id,
    )

def _world_fixture_impl(ctx):
    metadata = ctx.actions.declare_file(ctx.label.name + "/metadata.parquet")
    entities = ctx.actions.declare_file(ctx.label.name + "/entities.parquet")
    relations = ctx.actions.declare_file(ctx.label.name + "/relations.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.command", "fixture"),
        ("attune.repository", ctx.attr.repository),
        ("attune.base_revision", ctx.attr.base_revision),
        ("attune.source_tree_identity", ctx.attr.source_tree_identity),
        ("attune.fact_identity", ctx.attr.fact_identity),
        ("attune.snapshot_id", ctx.attr.snapshot_id),
        ("attune.world_metadata", metadata.path),
        ("attune.world_entities", entities.path),
        ("attune.world_relations", relations.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        outputs = [metadata, entities, relations],
        mnemonic = "AttuneWorldFixture",
        progress_message = "Writing typed repository fixture %{label}",
    )
    return [
        DefaultInfo(files = depset([metadata, entities, relations])),
        _world_info(ctx, metadata, entities, relations),
    ]

def _world_files_impl(ctx):
    return [
        DefaultInfo(files = depset([
            ctx.file.metadata,
            ctx.file.entities,
            ctx.file.relations,
            ctx.file.identity,
        ])),
        _world_info(
            ctx,
            ctx.file.metadata,
            ctx.file.entities,
            ctx.file.relations,
            ctx.file.identity,
        ),
    ]

attune_world_files = rule(
    implementation = _world_files_impl,
    attrs = {
        "metadata": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "entities": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "relations": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "identity": attr.label(allow_single_file = [".json"], mandatory = True),
        "repository": attr.string(mandatory = True),
        "base_revision": attr.string(mandatory = True),
        "source_tree_identity": attr.string(mandatory = True),
        "fact_identity": attr.string(mandatory = True),
        "snapshot_id": attr.string(mandatory = True),
    },
)

attune_world_fixture = rule(
    implementation = _world_fixture_impl,
    attrs = {
        "repository": attr.string(mandatory = True),
        "base_revision": attr.string(mandatory = True),
        "source_tree_identity": attr.string(mandatory = True),
        "fact_identity": attr.string(mandatory = True),
        "snapshot_id": attr.string(mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _atlas_signature_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    observations = ctx.actions.declare_file(ctx.label.name + "/observations.parquet")
    physical = ctx.actions.declare_file(ctx.label.name + "/physical.parquet")
    snapshot = ctx.actions.declare_file(ctx.label.name + "/snapshot.parquet")
    args = ctx.actions.args()
    command = "signature-dynamic" if world.identity else "signature"
    for name, value in [
        ("attune.command", command),
        ("attune.repository", world.repository),
        ("attune.base_revision", world.base_revision),
        ("attune.source_tree_identity", world.source_tree_identity),
        ("attune.fact_identity", world.fact_identity),
        ("attune.snapshot_id", world.snapshot_id),
        ("attune.world_metadata", world.metadata.path),
        ("attune.world_entities", world.entities.path),
        ("attune.world_relations", world.relations.path),
        ("attune.output_observations", observations.path),
        ("attune.output_physical", physical.path),
        ("attune.output_snapshot", snapshot.path),
        ("attune.manifest_case_count", str(ctx.attr.manifest_case_count)),
    ]:
        args.add(_jvm_property(name, value))
    inputs = [world.metadata, world.entities, world.relations]
    if world.identity:
        args.add(_jvm_property("attune.world_identity", world.identity.path))
        inputs.append(world.identity)
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = inputs,
        outputs = [observations, physical, snapshot],
        mnemonic = "AtlasSignature",
        progress_message = "Measuring Atlas signature %{label}",
    )
    return [
        DefaultInfo(files = depset([observations, physical, snapshot])),
        AttuneSignatureInfo(
            observations = observations,
            physical = physical,
            snapshot = snapshot,
            repository = world.repository,
            base_revision = world.base_revision,
            source_tree_identity = world.source_tree_identity,
            fact_identity = world.fact_identity,
            snapshot_id = world.snapshot_id,
        ),
    ]

attune_atlas_signature = rule(
    implementation = _atlas_signature_impl,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "manifest_case_count": attr.int(default = 1),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _atlas_signature_summary_impl(ctx):
    signature = ctx.attr.signature[AttuneSignatureInfo]
    summary = ctx.actions.declare_file(ctx.label.name + "/summary.parquet")
    args = ctx.actions.args()
    args.add(_jvm_property("attune.input_observations", signature.observations.path))
    args.add(_jvm_property("attune.output_summary", summary.path))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [signature.observations],
        outputs = [summary],
        mnemonic = "AtlasSignatureSummary",
        progress_message = "Summarizing Atlas signature %{label}",
    )
    return [
        DefaultInfo(files = depset([summary, signature.snapshot, signature.physical])),
        AttuneSignatureSummaryInfo(
            summary = summary,
            snapshot = signature.snapshot,
            physical = signature.physical,
        ),
    ]

attune_atlas_signature_summary = rule(
    implementation = _atlas_signature_summary_impl,
    attrs = {
        "signature": attr.label(providers = [AttuneSignatureInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _atlas_signatures_impl(ctx):
    signatures = [target[AttuneSignatureInfo] for target in ctx.attr.signatures]
    observations = [signature.observations for signature in signatures]
    physical = [signature.physical for signature in signatures]
    snapshots = [signature.snapshot for signature in signatures]
    return [
        DefaultInfo(files = depset(observations + physical + snapshots)),
        OutputGroupInfo(
            observations = depset(observations),
            physical = depset(physical),
            snapshots = depset(snapshots),
        ),
    ]

attune_atlas_signatures = rule(
    implementation = _atlas_signatures_impl,
    attrs = {
        "signatures": attr.label_list(providers = [AttuneSignatureInfo]),
    },
)

def _atlas_signature_summaries_impl(ctx):
    summaries = [target[AttuneSignatureSummaryInfo] for target in ctx.attr.summaries]
    files = [summary.summary for summary in summaries]
    snapshots = [summary.snapshot for summary in summaries]
    physical = [summary.physical for summary in summaries]
    return [
        DefaultInfo(files = depset(files + snapshots + physical)),
        OutputGroupInfo(
            summaries = depset(files),
            snapshots = depset(snapshots),
            physical = depset(physical),
        ),
    ]

attune_atlas_signature_summaries = rule(
    implementation = _atlas_signature_summaries_impl,
    attrs = {
        "summaries": attr.label_list(providers = [AttuneSignatureSummaryInfo]),
    },
)

def _atlas_aggregate_impl(ctx):
    summaries = [target[AttuneSignatureSummaryInfo] for target in ctx.attr.summaries]
    aggregate_summaries = ctx.actions.declare_file(ctx.label.name + "/summaries.parquet")
    aggregate_snapshots = ctx.actions.declare_file(ctx.label.name + "/snapshots.parquet")
    aggregate_physical = ctx.actions.declare_file(ctx.label.name + "/physical.parquet")
    args = ctx.actions.args()
    _add_indexed(args, "attune.input_summaries", [summary.summary for summary in summaries])
    _add_indexed(args, "attune.input_snapshots", [summary.snapshot for summary in summaries])
    _add_indexed(args, "attune.input_physical", [summary.physical for summary in summaries])
    for name, value in [
        ("attune.output_summaries", aggregate_summaries.path),
        ("attune.output_snapshots", aggregate_snapshots.path),
        ("attune.output_physical", aggregate_physical.path),
    ]:
        args.add(_jvm_property(name, value))
    inputs = []
    for summary in summaries:
        inputs.extend([summary.summary, summary.snapshot, summary.physical])
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = inputs,
        outputs = [aggregate_summaries, aggregate_snapshots, aggregate_physical],
        mnemonic = "AtlasAggregate",
        progress_message = "Aggregating typed Atlas census %{label}",
    )
    return [
        DefaultInfo(files = depset([aggregate_summaries, aggregate_snapshots, aggregate_physical])),
        AttuneAtlasAggregateInfo(
            summaries = aggregate_summaries,
            snapshots = aggregate_snapshots,
            physical = aggregate_physical,
        ),
    ]

attune_atlas_aggregate = rule(
    implementation = _atlas_aggregate_impl,
    attrs = {
        "summaries": attr.label_list(providers = [AttuneSignatureSummaryInfo]),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _atlas_report_impl(ctx):
    aggregate = ctx.attr.aggregate[AttuneAtlasAggregateInfo]
    report = ctx.actions.declare_file(ctx.label.name + "/REPORT.md")
    repositories = ctx.actions.declare_file(ctx.label.name + "/repositories.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.input_summaries", aggregate.summaries.path),
        ("attune.input_snapshots", aggregate.snapshots.path),
        ("attune.input_physical", aggregate.physical.path),
        ("attune.output_report", report.path),
        ("attune.output_repository_summaries", repositories.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [aggregate.summaries, aggregate.snapshots, aggregate.physical],
        outputs = [report, repositories],
        mnemonic = "AtlasReport",
        progress_message = "Writing frozen Atlas census report %{label}",
    )
    return [DefaultInfo(files = depset([report, repositories]))]

attune_atlas_report = rule(
    implementation = _atlas_report_impl,
    attrs = {
        "aggregate": attr.label(providers = [AttuneAtlasAggregateInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _localization_replay_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    decisions = ctx.attr.decisions[AttuneDecisionBundleInfo]
    prior = ctx.attr.data[AttunePriorInfo]
    expected = ctx.attr.data[AttunePredictionInfo]
    issue = ctx.attr.data[AttuneIssueInfo]
    if not world.identity:
        fail("localization replay requires the canonical migrated world identity")
    summary = ctx.actions.declare_file(ctx.label.name + "/prediction-summary.parquet")
    ranking = ctx.actions.declare_file(ctx.label.name + "/prediction-ranking.parquet")
    prediction_decisions = ctx.actions.declare_file(ctx.label.name + "/prediction-decisions.parquet")
    probabilities = ctx.actions.declare_file(ctx.label.name + "/prediction-probabilities.parquet")
    proof = ctx.actions.declare_file(ctx.label.name + "/proof.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.world_identity", world.identity.path),
        ("attune.world_metadata", world.metadata.path),
        ("attune.world_entities", world.entities.path),
        ("attune.world_relations", world.relations.path),
        ("attune.issue", issue.issue.path),
        ("attune.instance_id", ctx.attr.instance_id),
        ("attune.prior_metadata", prior.metadata.path),
        ("attune.prior_documents", prior.documents.path),
        ("attune.prior_ranking", prior.ranking.path),
        ("attune.decisions", decisions.bundle.path),
        ("attune.expected_summary", expected.summary.path),
        ("attune.expected_ranking", expected.ranking.path),
        ("attune.expected_decisions", expected.decisions.path),
        ("attune.expected_probabilities", expected.probabilities.path),
        ("attune.output_prediction_summary", summary.path),
        ("attune.output_prediction_ranking", ranking.path),
        ("attune.output_prediction_decisions", prediction_decisions.path),
        ("attune.output_prediction_probabilities", probabilities.path),
        ("attune.output_proof", proof.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [
            world.identity,
            world.metadata,
            world.entities,
            world.relations,
            issue.issue,
            prior.metadata,
            prior.documents,
            prior.ranking,
            decisions.bundle,
            expected.summary,
            expected.ranking,
            expected.decisions,
            expected.probabilities,
        ],
        outputs = [summary, ranking, prediction_decisions, probabilities, proof],
        mnemonic = "AttuneLocalizationReplay",
        progress_message = "Replaying frozen localization case %{label}",
    )
    return [
        DefaultInfo(files = depset([summary, ranking, prediction_decisions, probabilities, proof])),
        AttuneLocalizationReplayInfo(
            summary = summary,
            ranking = ranking,
            decisions = prediction_decisions,
            probabilities = probabilities,
            proof = proof,
        ),
    ]

attune_localization_replay = rule(
    implementation = _localization_replay_impl,
    attrs = {
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "decisions": attr.label(providers = [AttuneDecisionBundleInfo], mandatory = True),
        "instance_id": attr.string(mandatory = True),
        "data": attr.label(providers = [AttuneIssueInfo, AttunePriorInfo, AttunePredictionInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _localization_replays_impl(ctx):
    replays = [target[AttuneLocalizationReplayInfo] for target in ctx.attr.replays]
    proof = ctx.actions.declare_file(ctx.label.name + "/proof.parquet")
    args = ctx.actions.args()
    _add_indexed(args, "attune.input_proofs", [replay.proof for replay in replays])
    args.add(_jvm_property("attune.output_proof", proof.path))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [replay.proof for replay in replays],
        outputs = [proof],
        mnemonic = "AttuneLocalizationReplayAggregate",
        progress_message = "Checking exact localization replay across %{label}",
    )
    return [
        DefaultInfo(files = depset([proof])),
        AttuneLocalizationReplaysInfo(proof = proof),
    ]

attune_localization_replays = rule(
    implementation = _localization_replays_impl,
    attrs = {
        "replays": attr.label_list(providers = [AttuneLocalizationReplayInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _localization_evaluation_impl(ctx):
    world = ctx.attr.world[AttuneWorldInfo]
    replay = ctx.attr.replay[AttuneLocalizationReplayInfo]
    prior = ctx.attr.data[AttunePriorInfo]
    issue = ctx.attr.data[AttuneIssueInfo]
    metrics = ctx.actions.declare_file(ctx.label.name + "/metrics.parquet")
    regions = ctx.actions.declare_file(ctx.label.name + "/regions.parquet")
    telemetry = ctx.actions.declare_file(ctx.label.name + "/telemetry.parquet")
    proof = ctx.actions.declare_file(ctx.label.name + "/proof.parquet")
    args = ctx.actions.args()
    for name, value in [
        ("attune.instance_id", ctx.attr.instance_id),
        ("attune.issue", issue.issue.path),
        ("attune.prior_metadata", prior.metadata.path),
        ("attune.prior_documents", prior.documents.path),
        ("attune.prior_ranking", prior.ranking.path),
        ("attune.prediction_summary", replay.summary.path),
        ("attune.prediction_ranking", replay.ranking.path),
        ("attune.prediction_decisions", replay.decisions.path),
        ("attune.prediction_probabilities", replay.probabilities.path),
        ("attune.gold", ctx.file.gold.path),
        ("attune.geometry", ctx.file.geometry.path),
        ("attune.expected_metrics", ctx.file.expected_metrics.path),
        ("attune.expected_regions", ctx.file.expected_regions.path),
        ("attune.world_identity", world.identity.path),
        ("attune.world_metadata", world.metadata.path),
        ("attune.world_entities", world.entities.path),
        ("attune.world_relations", world.relations.path),
        ("attune.output_metrics", metrics.path),
        ("attune.output_regions", regions.path),
        ("attune.output_telemetry", telemetry.path),
        ("attune.output_proof", proof.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [
            issue.issue,
            prior.metadata,
            prior.documents,
            prior.ranking,
            replay.summary,
            replay.ranking,
            replay.decisions,
            replay.probabilities,
            ctx.file.gold,
            ctx.file.geometry,
            ctx.file.expected_metrics,
            ctx.file.expected_regions,
            world.identity,
            world.metadata,
            world.entities,
            world.relations,
        ],
        outputs = [metrics, regions, telemetry, proof],
        mnemonic = "AttuneLocalizationEvaluation",
        progress_message = "Evaluating frozen localization case %{label}",
    )
    return [
        DefaultInfo(files = depset([metrics, regions, telemetry, proof])),
        AttuneLocalizationEvaluationInfo(
            metrics = metrics,
            regions = regions,
            telemetry = telemetry,
            proof = proof,
        ),
    ]

attune_localization_evaluation = rule(
    implementation = _localization_evaluation_impl,
    attrs = {
        "instance_id": attr.string(mandatory = True),
        "data": attr.label(providers = [AttuneIssueInfo, AttunePriorInfo, AttunePredictionInfo], mandatory = True),
        "replay": attr.label(providers = [AttuneLocalizationReplayInfo], mandatory = True),
        "gold": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "geometry": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "expected_metrics": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "expected_regions": attr.label(allow_single_file = [".parquet"], mandatory = True),
        "world": attr.label(providers = [AttuneWorldInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _localization_evaluations_impl(ctx):
    evaluations = [target[AttuneLocalizationEvaluationInfo] for target in ctx.attr.evaluations]
    metrics = ctx.actions.declare_file(ctx.label.name + "/metrics.parquet")
    regions = ctx.actions.declare_file(ctx.label.name + "/regions.parquet")
    telemetry = ctx.actions.declare_file(ctx.label.name + "/telemetry.parquet")
    proof = ctx.actions.declare_file(ctx.label.name + "/proof.parquet")
    args = ctx.actions.args()
    _add_indexed(args, "attune.input_metrics", [evaluation.metrics for evaluation in evaluations])
    _add_indexed(args, "attune.input_regions", [evaluation.regions for evaluation in evaluations])
    _add_indexed(args, "attune.input_telemetry", [evaluation.telemetry for evaluation in evaluations])
    _add_indexed(args, "attune.input_proofs", [evaluation.proof for evaluation in evaluations])
    for name, value in [
        ("attune.output_metrics", metrics.path),
        ("attune.output_regions", regions.path),
        ("attune.output_telemetry", telemetry.path),
        ("attune.output_proof", proof.path),
    ]:
        args.add(_jvm_property(name, value))
    inputs = []
    for evaluation in evaluations:
        inputs.extend([
            evaluation.metrics,
            evaluation.regions,
            evaluation.telemetry,
            evaluation.proof,
        ])
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = inputs,
        outputs = [metrics, regions, telemetry, proof],
        mnemonic = "AttuneLocalizationEvaluationAggregate",
        progress_message = "Aggregating official localization evaluation %{label}",
    )
    return [
        DefaultInfo(files = depset([metrics, regions, telemetry, proof])),
        AttuneLocalizationEvaluationsInfo(
            metrics = metrics,
            regions = regions,
            telemetry = telemetry,
            proof = proof,
        ),
    ]

attune_localization_evaluations = rule(
    implementation = _localization_evaluations_impl,
    attrs = {
        "evaluations": attr.label_list(providers = [AttuneLocalizationEvaluationInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _atlas_localization_analysis_impl(ctx):
    atlas = ctx.attr.atlas[AttuneAtlasAggregateInfo]
    localization = ctx.attr.localization[AttuneLocalizationEvaluationsInfo]
    cases = ctx.actions.declare_file(ctx.label.name + "/cases.parquet")
    report = ctx.actions.declare_file(ctx.label.name + "/REPORT.md")
    args = ctx.actions.args()
    for name, value in [
        ("attune.atlas_summaries", atlas.summaries.path),
        ("attune.atlas_physical", atlas.physical.path),
        ("attune.localization_metrics", localization.metrics.path),
        ("attune.localization_telemetry", localization.telemetry.path),
        ("attune.output_cases", cases.path),
        ("attune.output_report", report.path),
    ]:
        args.add(_jvm_property(name, value))
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = [
            atlas.summaries,
            atlas.physical,
            localization.metrics,
            localization.telemetry,
        ],
        outputs = [cases, report],
        mnemonic = "AttuneAtlasLocalizationAnalysis",
        progress_message = "Joining frozen Atlas and localization results %{label}",
    )
    return [
        DefaultInfo(files = depset([cases, report])),
        AttuneAtlasLocalizationInfo(cases = cases, report = report),
    ]

attune_atlas_localization_analysis = rule(
    implementation = _atlas_localization_analysis_impl,
    attrs = {
        "atlas": attr.label(providers = [AttuneAtlasAggregateInfo], mandatory = True),
        "localization": attr.label(providers = [AttuneLocalizationEvaluationsInfo], mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)
