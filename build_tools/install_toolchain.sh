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

# Install the prebuilt RISC-V LLVM toolchain.

function clean {
    rm "${DOWNLOAD_DIR}/${TOOLCHAIN_TARBALL}" \
       "${DOWNLOAD_DIR}/${TOOLCHAIN_TARBALL}.sha256sum"
}

function die {
  echo "$@" >/dev/stderr
  exit 1
}

function try {
  $@ || die "Failed to execute '$@'"
}

DOWNLOAD_DIR="${DOWNLOAD_DIR:-build/tmp}"
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-build}"

TOOLCHAIN_TARBALL="toolchain_iree_rv32.tar.gz"

trap clean EXIT

echo "Download ${TOOLCHAIN_TARBALL} from GCS..."
DOWNLOAD_URL="https://storage.googleapis.com/shodan-public-artifacts/${TOOLCHAIN_TARBALL}"
mkdir -p "${DOWNLOAD_DIR}"

wget --progress=dot:giga -P "${DOWNLOAD_DIR}" "${DOWNLOAD_URL}"
wget -P "${DOWNLOAD_DIR}" "${DOWNLOAD_URL}.sha256sum"
pushd "${DOWNLOAD_DIR}" > /dev/null
try sha256sum -c "${TOOLCHAIN_TARBALL}.sha256sum"
popd > /dev/null

try tar -C "${TOOLCHAIN_DIR}" -xf "${DOWNLOAD_DIR}/${TOOLCHAIN_TARBALL}"
