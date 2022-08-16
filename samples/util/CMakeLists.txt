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

iree_cc_library(
  NAME
    util
  HDRS
    "util.h"
  SRCS
    "util.c"
  DEPS
    ::alloc
    iree::base
    iree::hal
    iree::hal::local
    iree::hal::local::loaders::static_library_loader
    iree::hal::drivers::local_sync::sync_driver
    iree::modules::hal
    iree::vm
    iree::vm::shims_emitc
    samples::device::device_static_loader
)

iree_cc_library(
  NAME
    alloc
  HDRS
    "alloc.h"
  SRCS
    "alloc.c"
  DEPS
    iree::base
)
