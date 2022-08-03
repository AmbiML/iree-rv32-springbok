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

cmake_minimum_required(VERSION 3.13.4)

#-------------------------------------------------------------------------------
# Project configuration
#-------------------------------------------------------------------------------

project(iree-riscv32)

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

list(APPEND CMAKE_MODULE_PATH
  ${CMAKE_CURRENT_LIST_DIR}/cmake/
)

set(IREE_SOURCE_DIR "third_party/iree" CACHE PATH
    "IREE source code path. (default: third_party/iree/)")

include_directories(BEFORE SYSTEM ${CMAKE_CURRENT_LIST_DIR})
include_directories(BEFORE SYSTEM ${CMAKE_CURRENT_BINARY_DIR})

# Use nano spec header and libraries.
include_directories(BEFORE SYSTEM "${RISCV_TOOLCHAIN_ROOT}/riscv32-unknown-elf/include/newlib-nano/")
link_directories(BEFORE "${RISCV_TOOLCHAIN_ROOT}/riscv32-unknown-elf/lib/newlib-nano/")

#-------------------------------------------------------------------------------
# Springbok-specific settings
#-------------------------------------------------------------------------------
set(DTCM_LENGTH "16M" CACHE STRING "DTCM Length (default: 16M)")
add_link_options("LINKER:--defsym=__dtcm_length__=${DTCM_LENGTH}")
set(ITCM_LENGTH "1M" CACHE STRING "ITCM (I-mem) Length (default: 1M)")
add_link_options("LINKER:--defsym=__itcm_length__=${ITCM_LENGTH}")
set(STACK_SIZE "10K" CACHE STRING "Stack size (default: 10K)")
add_link_options("LINKER:--defsym=__stack_size__=${STACK_SIZE}")
set(SPRINGBOK_LINKER_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/springbok/springbok.ld" CACHE PATH "Springbok linker script path (default: springbok.ld)")
set(BUILD_WITH_SPRINGBOK ON CACHE BOOL "Build the target with springbok BSP (default: ON)")

#-------------------------------------------------------------------------------
# IREE-specific settings
#-------------------------------------------------------------------------------
set(IREE_BUILD_COMPILER OFF)
set(IREE_ENABLE_MLIR OFF)
set(IREE_BUILD_SAMPLES OFF)
set(IREE_ENABLE_THREADING OFF)
set(IREE_BUILD_TESTS OFF)
set(IREE_BUILD_BINDINGS_TFLITE OFF)
set(IREE_HAL_DRIVER_LOCAL_SYNC ON CACHE BOOL "" FORCE)
set(IREE_HAL_EXECUTABLE_LOADER_DEFAULTS OFF CACHE BOOL "" FORCE)
set(IREE_HAL_EXECUTABLE_LOADER_VMVX_MODULE ON CACHE BOOL "" FORCE)
set(IREE_HAL_DRIVER_DEFAULTS OFF CACHE BOOL "" FORCE)

#-------------------------------------------------------------------------------
# IREE-specific definitions
#-------------------------------------------------------------------------------
set(SPRINGBOK_CONFIG_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/springbok_config.h")
add_definitions(-DFLATCC_USE_GENERIC_ALIGNED_ALLOC)
add_definitions(-DIREE_PLATFORM_GENERIC)
add_definitions(-DIREE_SYNCHRONIZATION_DISABLE_UNSAFE=1)
add_definitions(-DIREE_FILE_IO_ENABLE=0)
add_definitions(-DIREE_USER_CONFIG_H="${SPRINGBOK_CONFIG_HEADER}")

# The project does a cmake hack here -- at the executable linkage stage, we
# append the logging library (and springbok BSP). Any logging library update
# (libspringbok.a) only gets rebuilt during executable
# linkage, but not during library compilation.
#
# However, an explicit include path gets added here across all targets so the
# header files can be found during compilation.

# Springbok BSP-related setting
add_subdirectory(springbok springbok)
include(riscv_springbok)
include_directories(springbok/include)

message(STATUS "Include IREE source at ${IREE_SOURCE_DIR}")
# Build IREE runtime libraries.
add_subdirectory(${IREE_SOURCE_DIR} iree)

# Apply IREE's CMake variables and build options so we can use IREE build
# functions properly in this project.
set(IREE_ROOT_DIR "${IREE_SOURCE_DIR}" CACHE PATH "IREE Root directory")
include(springbok_ops)

include(springbok_bytecode_module)
include(springbok_c_module)
include(springbok_modules)
include(iree_model_input)
# softmax op (and mfcc) requires floorf implementation in libm. Use the nano
# version.
find_library(m m
PATHS
  "${RISCV_TOOLCHAIN_ROOT}/riscv32-unknown-elf/lib/newlib-nano/"
REQUIRED)
link_libraries(m)
# Add the included directory here.
add_subdirectory(samples)
