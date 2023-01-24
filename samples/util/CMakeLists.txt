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
    util_base
  HDRS
    "util.h"
  SRCS
    "util.c"
  DEPS
    ::alloc
    iree::modules::hal
)

# static library using regular HAL
iree_cc_library(
  NAME
    util_static
  DEPS
    ::util_base
    samples::device::device_static_loader
)

# vmvx using regular HAL
iree_cc_library(
  NAME
    util_vmvx
  DEPS
    ::util_base
    samples::device::device_vmvx_loader
)

# static library using inline HAL
iree_cc_library(
  NAME
    util_static_inline
  HDRS
    "util.h"
  SRCS
    "util.c"
  DEPS
    ::alloc
    iree::modules::hal::inline
    iree::modules::hal::loader
    samples::device::device_static_loader
  COPTS
    "-DBUILD_LOADER_HAL"
)

# vmvx using inline HAL
iree_cc_library(
  NAME
    util_vmvx_inline
  HDRS
    "util.h"
  SRCS
    "util.c"
  DEPS
    ::alloc
    iree::modules::hal::inline
    samples::device::device_vmvx_loader
  COPTS
    "-DBUILD_INLINE_HAL"
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
