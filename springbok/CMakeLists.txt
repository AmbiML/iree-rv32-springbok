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

enable_language(ASM)

add_library(springbok INTERFACE)
add_library(springbok_intrinsic STATIC)
target_sources(springbok_intrinsic
    PRIVATE
      crt0.S
      springbok_gloss.cpp
      springbok.cpp
)

target_include_directories(springbok_intrinsic PUBLIC include)

target_link_libraries(springbok
INTERFACE
  springbok_intrinsic
)

target_include_directories(springbok INTERFACE include)

target_compile_options(springbok_intrinsic
    PUBLIC
      ${VEC_DEFAULT_COPTS}
)

target_link_options(springbok
    INTERFACE
      -Wl,--whole-archive ${CMAKE_CURRENT_BINARY_DIR}/libspringbok_intrinsic.a -Wl,--no-whole-archive
)
