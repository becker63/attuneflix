"""Deterministic BuildBuddy artifacts for recorded Families acquisition evidence.

The archive action is hermetic: both evidence spaces are declared Bazel inputs,
the pinned Java tool normalizes entry order and timestamps, and BuildBuddy
stores the resulting ZIP as a content-addressed action output. Live provider
calls remain outside this action graph.
"""

load(":acquired_worlds.bzl", "ACQUIRED_DIGESTS")

def _evidence_archive_impl(ctx):
    files = sorted(ctx.files.embeddings + ctx.files.decisions, key = lambda file: file.short_path)
    output = ctx.actions.declare_file("evidence-archives/" + ctx.attr.digest + ".zip")
    args = ctx.actions.args()
    args.add(output.path)
    for file in files:
        if not file.short_path.startswith(".attune/"):
            fail("evidence input has an unexpected package path: " + file.short_path)
        args.add(file.short_path)
        args.add(file.path)
    args.use_param_file("@%s", use_always = True)
    args.set_param_file_format("multiline")
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = files,
        outputs = [output],
        execution_requirements = {"no-local": "1"},
        mnemonic = "FamiliesEvidenceArchive",
        progress_message = "Archiving recorded Families evidence %{label}",
    )
    return [DefaultInfo(files = depset([output]))]

families_evidence_archive = rule(
    implementation = _evidence_archive_impl,
    attrs = {
        "embeddings": attr.label(mandatory = True, allow_files = True),
        "decisions": attr.label(mandatory = True, allow_files = True),
        "digest": attr.string(mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _evidence_address_impl(ctx):
    archive = ctx.attr.archive[DefaultInfo].files.to_list()[0]
    output = ctx.actions.declare_file("evidence-addresses/" + ctx.attr.digest + "/evidence-address.json")
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = ["--describe", ctx.attr.digest, archive.path, output.path],
        inputs = [archive],
        outputs = [output],
        execution_requirements = {"no-local": "1"},
        mnemonic = "FamiliesEvidenceAddress",
        progress_message = "Addressing BuildBuddy evidence %{label}",
    )
    return [DefaultInfo(files = depset([output]))]

families_evidence_address = rule(
    implementation = _evidence_address_impl,
    attrs = {
        "archive": attr.label(mandatory = True, allow_files = True),
        "digest": attr.string(mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def _evidence_index_impl(ctx):
    if len(ctx.attr.digests) != len(ctx.attr.addresses):
        fail("evidence index digests and addresses disagree")
    files = [target[DefaultInfo].files.to_list()[0] for target in ctx.attr.addresses]
    output = ctx.actions.declare_file("evidence-cas-index.json")
    args = ctx.actions.args()
    args.add("--index")
    args.add(output.path)
    for index, digest in enumerate(ctx.attr.digests):
        args.add(digest)
        args.add(files[index].path)
    args.use_param_file("@%s", use_always = True)
    args.set_param_file_format("multiline")
    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = files,
        outputs = [output],
        execution_requirements = {"no-local": "1"},
        mnemonic = "FamiliesEvidenceIndex",
        progress_message = "Indexing BuildBuddy Families evidence %{label}",
    )
    return [DefaultInfo(files = depset([output]))]

families_evidence_index = rule(
    implementation = _evidence_index_impl,
    attrs = {
        "addresses": attr.label_list(mandatory = True),
        "digests": attr.string_list(mandatory = True),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
)

def families_evidence_archives(tool):
    """One archive target per sealed world, including the tracked Preact exemplar."""
    addresses = []
    for digest in sorted(ACQUIRED_DIGESTS):
        archive = "evidence_archive_" + digest
        address = "evidence_address_" + digest
        families_evidence_archive(
            name = archive,
            digest = digest,
            embeddings = "//.attune/families-embeddings-v1/%s:evidence" % digest,
            decisions = "//.attune/jev-families-raw-v1/%s:evidence" % digest,
            tool = tool,
            visibility = ["//visibility:public"],
        )
        families_evidence_address(
            name = address,
            digest = digest,
            archive = ":" + archive,
            tool = tool,
            visibility = ["//visibility:public"],
        )
        addresses.append(":" + address)
    native.filegroup(
        name = "evidence_addresses",
        srcs = addresses,
        visibility = ["//visibility:public"],
    )
    families_evidence_index(
        name = "evidence_cas_index",
        addresses = addresses,
        digests = sorted(ACQUIRED_DIGESTS),
        tool = tool,
        visibility = ["//visibility:public"],
    )
