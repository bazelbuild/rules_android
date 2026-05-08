load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def extract_jvm_flags_for_mnemonic(ctx, mnemonic):
    flag_values = []
    for value in ctx.attr._mnemonic_jvm_flags[BuildSettingInfo].value:
        key, jvm_flag = value.split("=", 1)
        if key != mnemonic:
            continue
        flag_values.append(jvm_flag)
    return flag_values
