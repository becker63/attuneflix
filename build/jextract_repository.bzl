"""Pinned OpenJDK jextract distribution for Linux Bazel execution hosts."""

_JEXTRACT_VERSION = "25"
_JEXTRACT_BUILD = "2-4"
_ARCHIVES = {
    "aarch64": struct(
        arch = "aarch64",
        sha256 = "0e25e6f6efa042f8758eaec65a873887fd2247fcf2e3e22dcfd7e4179fc8b0ae",
    ),
    "amd64": struct(
        arch = "x64",
        sha256 = "d0cc481abc1adb16fb9514e1c5e0bfc08d38c29228bece667fb5054ceaffaa42",
    ),
    "x86_64": struct(
        arch = "x64",
        sha256 = "d0cc481abc1adb16fb9514e1c5e0bfc08d38c29228bece667fb5054ceaffaa42",
    ),
}

def _jextract_repository_impl(repository_ctx):
    archive = _ARCHIVES.get(repository_ctx.os.arch)
    if archive == None:
        fail("jextract is not pinned for execution architecture %s" % repository_ctx.os.arch)

    repository_ctx.download_and_extract(
        url = "https://download.java.net/java/early_access/jextract/%s/2/openjdk-%s-jextract+%s_linux-%s_bin.tar.gz" % (
            _JEXTRACT_VERSION,
            _JEXTRACT_VERSION,
            _JEXTRACT_BUILD,
            archive.arch,
        ),
        sha256 = archive.sha256,
        stripPrefix = "jextract-%s" % _JEXTRACT_VERSION,
    )
    repository_ctx.file(
        "BUILD.bazel",
        """package(default_visibility = ["//visibility:public"])

filegroup(
    name = "tool",
    srcs = ["bin/jextract"] + glob(["runtime/**"]),
)
""",
    )

jextract_repository = repository_rule(
    implementation = _jextract_repository_impl,
)
