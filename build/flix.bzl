def _flix_check_impl(ctx):
    marker = ctx.actions.declare_file(ctx.label.name + ".checked")
    sources = ["\"$execroot/%s\"" % source.path for source in ctx.files.srcs]

    ctx.actions.run_shell(
        inputs = ctx.files.srcs,
        outputs = [marker],
        tools = [ctx.executable._flix],
        command = """
set -eu
execroot=$PWD
"$execroot/{flix}" {command} {sources} --threads {threads}
printf 'checked\n' > "$execroot/{marker}"
""".format(
            command = ctx.attr.command,
            flix = ctx.executable._flix.path,
            marker = marker.path,
            sources = " ".join(sources),
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
