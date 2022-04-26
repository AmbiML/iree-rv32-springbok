# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import sys

import lit.formats
import lit.llvm

# Configuration file for the 'lit' test runner.
lit.llvm.initialize(lit_config, config)

config.name = "Model tests"
config.test_format = lit.formats.ShTest(True)

config.suffixes = [".txt"]
config.excludes = [
    "CMakeLists.txt"
]
dir_path = os.path.dirname(os.path.realpath(__file__))
config.environment["ROOTDIR"] = dir_path + "/.."
config.environment["BUILD"] = config.environment["ROOTDIR"] + "/build/build-riscv"

renode_cmd = (
    "%s/build_tools/test_runner.py"
    " --renode-path %s/build/renode/renode"
    % (config.environment["ROOTDIR"], config.environment["ROOTDIR"]))

config.test_exec_root = config.environment["ROOTDIR"] + "/build/springbok_iree/tests"

# Enable features based on -D FEATURES=internal syntax. FEATURE is used in the
# REQUIRES field in the lit test. Can add multiple features with comma delimiter.
features_param = lit_config.params.get("FEATURES")
if features_param:
    config.available_features.update(features_param.split(','))

config.environment["TEST_RUNNER_CMD"] = renode_cmd
