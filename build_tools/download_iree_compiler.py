#!/usr/bin/env python3
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

#!/usr/bin/env python3
"""Download IREE host compiler from the snapshot release."""

import os
import sys
import tarfile
import time
import argparse
import requests
import urllib
import wget

from pathlib import Path

def download_artifact(assets, keywords, out_dir):
    """Download the artifact from the asset list based on the keyword."""
    # Find the linux tarball and download it.
    artifact_match = False
    for asset in assets:
        download_url = asset["browser_download_url"]
        artifact_name = asset["name"]
        if all(x in artifact_name for x in keywords):
            artifact_match = True
            break
    if not artifact_match:
        print("%s is not found" % (keywords[0]))
        sys.exit(1)

    print("\nDownload %s from %s\n" % (artifact_name, download_url))
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    out_file = os.path.join(out_dir, artifact_name)

    num_retries = 3
    for i in range(num_retries + 1):
        try:
            wget.download(download_url, out=out_file)
            break
        except urllib.error.HTTPError as e:
            if i == num_retries:
                raise
            print(f"{e}\nDownload failed. Retrying...")
            time.sleep(5)
    return out_file


def main():
    """ Download IREE host compiler from the snapshot release."""

    parser = argparse.ArgumentParser(
        description="Download IREE host compiler from snapshot releases")
    parser.add_argument(
        "--tag_name", action="store", default="candidate-20220417.110",
        help="snapshot tag to download. If not set, default to the one synced to third_party/iree commit.")
    parser.add_argument(
        "--release_url", action="store",
        default="https://api.github.com/repos/google/iree/releases",
        help=("URL to check the IREE release."
              "(default: https://api.github.com/repos/google/iree/releases)")
    )
    parser.add_argument(
        "--installed_dir", action="store", default="build/iree_compiler",
        help="path to install IREE compiler, default to build/iree_compiler.")
    args = parser.parse_args()

    iree_compiler_dir = Path(args.installed_dir)
    r = requests.get(("%s/tags/%s" % (args.release_url, args.tag_name)),
                     auth=('user', 'pass'))

    if r.status_code != 200:
        print("Not getting the snapshot %s information. Status code: %d" %
              (args.tag_name, r.status_code))
        sys.exit(1)

    snapshot = r.json()

    tag_name = snapshot["tag_name"]
    commit_sha = snapshot["target_commitish"]

    print("Snapshot: %s" % tag_name)

    tag_file = iree_compiler_dir / "tag"

    # Check the tag of the existing download.
    tag_match = False
    if os.path.isfile(tag_file):
        with open(tag_file, 'r') as f:
            for line in f:
                if tag_name == line.replace("\n", ""):
                    tag_match = True
                    break

    if tag_match:
        print("IREE compiler is up-to-date")
        sys.exit(0)

    tmp_dir = iree_compiler_dir / "tmp"
    whl_file = download_artifact(snapshot["assets"],
                                 ["iree_tools_tflite", "linux", "x86_64.whl"],
                                 tmp_dir)
    tar_file = download_artifact(
        snapshot["assets"], ["linux-x86_64.tar"], tmp_dir)

    # Install IREE TFLite tool
    cmd = ("pip3 install %s --no-cache-dir" % whl_file)
    os.system(cmd)

    # Extract the tarball to ${iree_compiler_dir}
    install_dir = iree_compiler_dir
    if not install_dir:
        os.mkdir(install_dir)

    tar = tarfile.open(tar_file)
    tar.extractall(path=install_dir)
    tar.close()

    os.remove(tar_file)
    os.remove(whl_file)
    print("\nIREE compiler is installed")

    # Add tag file for future checks
    with open(tag_file, "w") as f:
        f.write("%s\ncommit_sha: %s\n" % (tag_name, commit_sha))


if __name__ == "__main__":
    main()
