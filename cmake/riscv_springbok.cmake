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

# A cmake cache to connect springbok BSP with the executables

if(NOT TARGET springbok)
  message(FATAL_ERROR "Please include springbok target first")
endif()

if(NOT DEFINED SPRINGBOK_LINKER_SCRIPT)
  message(FATAL_ERROR "Please specifiy SPRINGBOK_LINKER_SCRIPT path first")
endif()

function(add_executable executable)
  cmake_parse_arguments(AE "ALIAS;IMPORTED" "" "" ${ARGN})
  if(AE_ALIAS OR AE_IMPORTED)
    _add_executable(${executable} ${ARGN})
  else()
    _add_executable(${executable} ${ARGN})
    target_link_libraries(${executable} PRIVATE springbok)
    target_link_options(${executable} PRIVATE "-T${SPRINGBOK_LINKER_SCRIPT}")
    target_link_options(${executable} PRIVATE "-nostartfiles")
  endif()
endfunction()
