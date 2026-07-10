load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _mnemonic_flag_impl(ctx):
    return [BuildSettingInfo(value = ctx.build_setting_value)]

def extract_values_for_mnemonic(ctx, mnemonic):
    flag_values = []
    for value in ctx.attr._mnemonic_jvm_flags[BuildSettingInfo].value:
        key, jvm_flag = value.split("=", 1)
        if key != mnemonic:
            continue
        flag_values.append(jvm_flag)
    return flag_values

mnemonic_flag = rule(
    implementation = _mnemonic_flag_impl,
    build_setting = config.string(flag = True, allow_multiple = True)
)