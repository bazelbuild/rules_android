#!/bin/bash --posix
# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eux

# Unset TESTBRIDGE_TEST_ONLY environment variable set by Bazel's --test_filter
# flag so that JUnit3 doesn't filter out the Android test suite class. Instead,
# forward this variable as a Java flag with the same name.
if [[ -z "${TESTBRIDGE_TEST_ONLY+1}" ]]; then
  ANDROID_TESTBRIDGE_TEST_ONLY=""
else
  ANDROID_TESTBRIDGE_TEST_ONLY=${TESTBRIDGE_TEST_ONLY}
  unset TESTBRIDGE_TEST_ONLY
fi

argv=$(cat <<END
--aapt=%aapt% \
--adb=%adb% \
--apks_to_install=%apks_to_install% \
--data_deps=%data_deps% \
--device_broker_type=%device_broker_type% \
--device_script=%device_script% \
--dex2oat_on_cloud_enabled=%dex2oat_on_cloud_enabled% \
--fixture_scripts=%fixture_scripts% \
--hermetic_server_script=%host_service_fixtures% \
--hermetic_servers=%host_service_fixture_services% \
--proxy_server_name=%proxy% \
--test_filter=${ANDROID_TESTBRIDGE_TEST_ONLY} \
--test_label=%test_label%
END
)

# Bazel-only test arguments for the device broker
additional_bazel_only_argv=$(cat <<END
--install_test_services=true
END
)

export GOOGLE3_DIR="$TEST_SRCDIR/google3"

# Jacoco Code Coverage
jacoco_metadata='%jacoco_metadata%'
if [[ -n "${jacoco_metadata}" ]]
then
    export JACOCO_METADATA="$GOOGLE3_DIR/$jacoco_metadata"
    export NEW_JAVA_COVERAGE_RELEASED=true
fi

# We pass in $argv via two channels here:
# 1) regular arguments: parsed normally by internal test entry point.
# 2) --jvm_flag: external AndroidDeviceTestSuite doesn't parse the argvs if
# passed in regularly, so we pass them in via a JVM flag hack and parse them
# at the AndroidDeviceTestSuite constructor.
%test_entry_point% \
    --wrapper_script_flag=--jvm_flag=-D%test_suite_property_name% \
    --wrapper_script_flag=--jvm_flag=-Dargv="$additional_bazel_only_argv $argv" \
    $argv "$@"
