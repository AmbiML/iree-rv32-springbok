#!/bin/bash
#
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [[ -z "$1" ]]; then
  cat << EOM
Usage: sim-springbok.sh bin [debug]
Where bin is a path to a compiled ELF and debug starts a GDB server
EOM
  exit 1
fi

ROOTDIR=$(dirname $(dirname $(realpath $0)))

command="start;"
if [[ "$2" == "debug" ]]; then
    command="machine StartGdbServer 3333;"
fi

bin_file=$(realpath $1)
(cd "${ROOTDIR}" && ./build/renode/renode -e "\$bin=@${bin_file}; i @sim/config/springbok.resc; \
${command} sysbus.vec_controlblock WriteDoubleWord 0xc 0" \
    --disable-xwt --console)
