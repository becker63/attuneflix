"""A string flag for the Playwright browsers directory of the e2e test."""

def _browsers_path_impl(ctx):
    return [platform_common.TemplateVariableInfo({
        "PLAYWRIGHT_BROWSERS_PATH": ctx.build_setting_value,
    })]

# The value is exposed as the make variable $(PLAYWRIGHT_BROWSERS_PATH) to targets
# that list the flag in `toolchains`. js_test exports its `env` unconditionally in
# the launcher, so `--test_env` cannot override it; this flag can.
browsers_path = rule(
    implementation = _browsers_path_impl,
    build_setting = config.string(flag = True),
)
