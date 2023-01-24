#!/bin/bash
#
# Copyright 2022 Google LLC
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

# Build RV32 IREE artifacts


set -x
set -e

ROOT_DIR="${ROOT_DIR:-$(git rev-parse --show-toplevel)}"

CMAKE_BIN="${CMAKE_BIN:-$(which cmake)}"
RISCV_RV32_NEWLIB_TOOLCHAIN_ROOT="${RISCV_RV32_NEWLIB_TOOLCHAIN_ROOT:-$ROOT_DIR/build/toolchain_iree_rv32imf}"

"${CMAKE_BIN?}" --version
ninja --version

IREE_SOURCE="${IREE_SOURCE:-$ROOT_DIR/third_party/iree}"

if [[ ! -d "${IREE_SOURCE?}" ]]; then
  echo "can't find the IREE source code at ${IREE_SOURCE?}"
  exit 1
fi

echo "Sync ${IREE_SOURCE?} and its submodules"
git submodule update --init

pushd ${IREE_SOURCE?} > /dev/null
git submodule sync && git submodule update --init --depth=10 --jobs=8
popd > /dev/null

BUILD_HOST_DIR="${BUILD_HOST_DIR:-$ROOT_DIR/build/iree_compiler}"
BUILD_RISCV_DIR="${BUILD_RISCV_DIR:-$ROOT_DIR/build/build-riscv}"

if [[ -d "${BUILD_RISCV_DIR?}" ]]; then
  echo "build-riscv directory already exists. Will use cached results there."
else
  echo "build-riscv directory does not already exist. Creating a new one."
  mkdir -p "${BUILD_RISCV_DIR?}"
fi

echo "Build riscv target at ${BUILD_RISCV_DIR?}"
declare -a args
args=(
  "-G" "Ninja"
  "-B" "${BUILD_RISCV_DIR?}"
  -DCMAKE_TOOLCHAIN_FILE="$(realpath ${ROOT_DIR?}/cmake/riscv_iree.cmake)"
  -DCMAKE_BUILD_TYPE=MinSizeRel
  -DIREE_HOST_BIN_DIR="$(realpath ${BUILD_HOST_DIR?})/bin"
  -DRISCV_TOOLCHAIN_ROOT="${RISCV_RV32_NEWLIB_TOOLCHAIN_ROOT?}"
)

args_str=$(IFS=' ' ; echo "${args[*]}")
"${CMAKE_BIN?}" ${args_str} "${ROOT_DIR?}"
"${CMAKE_BIN?}" --build "${BUILD_RISCV_DIR?}"
