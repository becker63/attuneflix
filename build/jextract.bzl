"""Small generated-source rule for Attune's C-to-Java FFM boundary."""

_PACKAGE_PATH = "attune/grit/ffi"

def _jextract_bindings_impl(ctx):
    tool = None
    for file in ctx.files.jextract:
        if file.path.endswith("/bin/jextract"):
            tool = file
            break
    if tool == None:
        fail("jextract tool filegroup does not contain bin/jextract")

    if len(ctx.files.clang_resource) != 1:
        fail("hermetic LLVM resource target must expose one resource directory")
    # rules_llvm deliberately exposes the installed lib/clang/<version>
    # source directory through DefaultInfo. Source directories are not tree
    # artifacts, so File.is_directory is false even though the path is a
    # directory in the action sandbox.
    clang_include = ctx.files.clang_resource[0].path + "/include"

    package_dir = ctx.label.name + "/" + _PACKAGE_PATH
    api = ctx.actions.declare_file(package_dir + "/AttuneGritAbi.java")
    shared = ctx.actions.declare_file(package_dir + "/AttuneGritAbi$shared.java")
    output_root = api.path[:-len("/" + _PACKAGE_PATH + "/AttuneGritAbi.java")]
    flags = ctx.actions.declare_file(ctx.label.name + ".work/compile_flags.txt")
    ctx.actions.write(flags, "-ffreestanding\n")

    ctx.actions.run_shell(
        inputs = [ctx.file.header, flags],
        tools = ctx.files.jextract + ctx.files.clang_resource,
        outputs = [api, shared],
        command = """
set -eu
root="$PWD"
cd "$root/{workdir}"
"$root/{tool}" \
  -I "$root/{clang_include}" \
  --target-package attune.grit.ffi \
  --header-class-name AttuneGritAbi \
  --include-function attune_grit_run \
  --include-function attune_grit_buffer_free \
  --library attune_grit_abi \
  --use-system-load-library \
  --output "$root/{output}" \
  "$root/{header}"
""".format(
            clang_include = clang_include,
            header = ctx.file.header.path,
            output = output_root,
            tool = tool.path,
            workdir = flags.dirname,
        ),
        mnemonic = "Jextract",
        progress_message = "Generating FFM bindings for %{label}",
    )

    return [DefaultInfo(files = depset([api, shared]))]

jextract_bindings = rule(
    implementation = _jextract_bindings_impl,
    attrs = {
        "clang_resource": attr.label(
            allow_files = True,
            cfg = "exec",
            default = Label("@llvm//:builtin_resource_dir"),
        ),
        "header": attr.label(allow_single_file = [".h"], mandatory = True),
        "jextract": attr.label(default = Label("@jextract//:tool")),
    },
)
