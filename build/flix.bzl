def _flix_project(ctx, description):
    runtime_jars = depset(transitive = [
        dependency[JavaInfo].transitive_runtime_jars
        for dependency in ctx.attr.java_deps
    ])
    jars = runtime_jars.to_list()
    jar_manifest = "\n".join([
        '"%s.jar" = "url:file:lib/external/%s.jar"' % (index, index)
        for index in range(len(jars))
    ])

    project = ctx.label.name + ".project"
    package_name = ctx.label.name.replace("_", "-")
    manifest = ctx.actions.declare_file(project + "/flix.toml")
    ctx.actions.write(
        manifest,
        """[package]
name = "%s"
description = "%s"
version = "0.0.0"
flix = "0.76.0"
authors = ["Attune"]

[jar-dependencies]
%s
""" % (package_name, description, jar_manifest),
    )

    project_inputs = [manifest]
    for source in ctx.files.srcs:
        source_path = source.short_path
        if source_path.startswith("src/"):
            relative = source_path[len("src/"):]
        elif "/src/" in source_path:
            relative = source_path.split("/src/", 1)[1]
        else:
            relative = source.basename
        link = ctx.actions.declare_file(project + "/src/" + relative)
        ctx.actions.symlink(output = link, target_file = source)
        project_inputs.append(link)
    for index, dependency_jar in enumerate(jars):
        link = ctx.actions.declare_file(project + "/lib/external/%s.jar" % index)
        ctx.actions.symlink(output = link, target_file = dependency_jar)
        project_inputs.append(link)
    return struct(
        inputs = project_inputs,
        manifest = manifest,
        name = project,
    )

def _flix_check_impl(ctx):
    marker = ctx.actions.declare_file(ctx.label.name + ".checked")
    project = _flix_project(ctx, "Bazel-owned Flix check")

    ctx.actions.run_shell(
        inputs = project.inputs,
        outputs = [marker],
        tools = [ctx.executable._flix],
        command = """
set -eu
execroot=$PWD
cd "$execroot/{project}"
"$execroot/{flix}" {command} --threads {threads}
printf 'checked\n' > "$execroot/{marker}"
""".format(
            command = ctx.attr.command,
            flix = ctx.executable._flix.path,
            marker = marker.path,
            project = project.manifest.dirname,
            threads = ctx.attr.threads,
        ),
        mnemonic = "FlixCheck",
        progress_message = "Checking Flix target %{label}",
    )
    return [DefaultInfo(files = depset([marker]))]

flix_check = rule(
    implementation = _flix_check_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".flix"]),
        "command": attr.string(default = "check", values = ["check", "test"]),
        "java_deps": attr.label_list(providers = [JavaInfo]),
        "threads": attr.int(default = 2),
        "_flix": attr.label(
            default = Label("//:flix"),
            executable = True,
            cfg = "exec",
        ),
    },
)

def _checked_test_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name)
    marker = ctx.file.check
    ctx.actions.write(
        executable,
        "#!/bin/sh\nset -eu\ntest -f \"$TEST_SRCDIR/_main/%s\"\n" % marker.short_path,
        is_executable = True,
    )
    return [DefaultInfo(
        executable = executable,
        runfiles = ctx.runfiles(files = [marker]),
    )]

checked_test = rule(
    implementation = _checked_test_impl,
    test = True,
    attrs = {
        "check": attr.label(allow_single_file = True, mandatory = True),
    },
)

def _flix_fatjar_impl(ctx):
    project = _flix_project(ctx, "Bazel-owned Flix executable")

    output_jar = ctx.actions.declare_file(
        project.name + "/artifact/" + project.name + ".jar",
    )
    ctx.actions.run_shell(
        inputs = project.inputs,
        outputs = [output_jar],
        tools = [ctx.executable._flix],
        command = """
set -eu
execroot=$PWD
cd "$execroot/{project}"
"$execroot/{flix}" build-fatjar --threads {threads}
if ! test -f "$execroot/{output}"; then
    echo "Flix did not create declared fat JAR; artifact directory contains:" >&2
    find artifact -maxdepth 2 -type f -print >&2 || true
    exit 1
fi
""".format(
            flix = ctx.executable._flix.path,
            output = output_jar.path,
            project = project.manifest.dirname,
            threads = ctx.attr.threads,
        ),
        mnemonic = "FlixFatJar",
        progress_message = "Compiling Flix executable %{label}",
    )
    return [
        DefaultInfo(files = depset([output_jar])),
        JavaInfo(output_jar = output_jar, compile_jar = output_jar),
    ]

flix_fatjar = rule(
    implementation = _flix_fatjar_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".flix"]),
        "java_deps": attr.label_list(providers = [JavaInfo]),
        "threads": attr.int(default = 2),
        "_flix": attr.label(
            default = Label("//:flix"),
            executable = True,
            cfg = "exec",
        ),
    },
)
