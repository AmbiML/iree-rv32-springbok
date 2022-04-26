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

include(CMakeParseArguments)

# springbok_c_module()
#
# A wrapper for the iree c module to apply common iree-compile flags
# Parameters:
# NAME: Name of target.
# SRC: Source file to compile into an emitC module. Support relative path.
# FLAGS: Flags to pass to the translation tool (list of strings).
# DEPENDS: List of other targets and files required for this binary.
# RVV_OFF: Indicate RVV is OFF (default: ON)
#
# Examples:
# springbok_c_module(
#   NAME
#     simple_float_mul_c_module_static
#   SRC
#     "simple_float_mul.mlir"
#   FLAGS
#     "-iree-input-type=mhlo"
#   RVV_OFF
#   PUBLIC
# )
#
function(springbok_c_module)
  cmake_parse_arguments(
    _RULE
    "PUBLIC;RVV_OFF"
    "NAME;SRC"
    "FLAGS;DEPENDS"
    ${ARGN}
  )

  set(_MLIR_SRC "${_RULE_SRC}")
  string(FIND "${_RULE_SRC}" ".tflite" _IS_TFLITE REVERSE)
  if(${_IS_TFLITE} GREATER 0)
    find_program(IREE_IMPORT_TFLITE_TOOL "iree-import-tflite" REQUIRED)
    set(_MLIR_SRC "${CMAKE_CURRENT_BINARY_DIR}/${_RULE_NAME}.mlir")
    get_filename_component(_SRC_PATH "${_RULE_SRC}" REALPATH)
    set(_ARGS "${_SRC_PATH}")
    list(APPEND _ARGS "-o")
    list(APPEND _ARGS "${_RULE_NAME}.mlir")
    # Only add the custom_command here. The output is passed to
    # iree_bytecode_module as the source.
    add_custom_command(
      OUTPUT
        "${_RULE_NAME}.mlir"
      COMMAND
        ${IREE_IMPORT_TFLITE_TOOL}
        ${_ARGS}
      DEPENDS
        ${IREE_IMPORT_TFLITE_TOOL}
        ${_RULE_DEPENDS}
    )
  endif()

  get_filename_component(_MLIR_SRC "${_MLIR_SRC}" REALPATH)
  iree_get_executable_path(_TRANSLATE_TOOL_EXECUTABLE "iree-compile")
  iree_get_executable_path(_LINKER_TOOL_EXECUTABLE "lld")

  # Replace dependencies passed by ::name with iree::package::name
  iree_package_ns(_PACKAGE_NS)
  list(TRANSFORM _RULE_DEPS REPLACE "^::" "${_PACKAGE_NS}::")

  # Prefix the library with the package name, so we get: iree_package_name.
  iree_package_name(_PACKAGE_NAME)

  set(_RULE_C_NAME "${_RULE_NAME}_c")
  set(_LIB_NAME "${_PACKAGE_NAME}_${_RULE_C_NAME}")
  set(_O_FILE_NAME ${_RULE_C_NAME}.o)
  set(_H_FILE_NAME ${_RULE_C_NAME}.h)
  set(_RULE_EMITC_NAME "${_RULE_NAME}_emitc")
  set(_EMITC_LIB_NAME "${_PACKAGE_NAME}_${_RULE_EMITC_NAME}")
  set(_EMITC_FILE_NAME ${_RULE_EMITC_NAME}.h)

  set(_CPU_FEATURES "+m,+f,+zvl512b,+zve32x")
  if (${_RULE_RVV_OFF})
    set(_CPU_FEATURES "+m,+f")
  endif()

  ## Example with VM C module.
  # Setup args for iree-compile.
  set(_TRANSLATE_ARGS ${_RULE_FLAGS})
  list(APPEND _TRANSLATE_ARGS "-iree-mlir-to-vm-c-module")
  list(APPEND _TRANSLATE_ARGS "-iree-hal-target-backends=dylib-llvm-aot")
  list(APPEND _TRANSLATE_ARGS "-iree-llvm-target-triple=riscv32-pc-linux-elf")
  list(APPEND _TRANSLATE_ARGS "-iree-llvm-target-cpu=generic-rv32")
  list(APPEND _TRANSLATE_ARGS "-iree-llvm-target-cpu-features=${_CPU_FEATURES}")
  list(APPEND _TRANSLATE_ARGS "-iree-llvm-target-abi=ilp32")
  list(APPEND _TRANSLATE_ARGS "-iree-llvm-link-embedded=false")
  list(APPEND _TRANSLATE_ARGS "-iree-llvm-link-static")
  list(APPEND _TRANSLATE_ARGS "-iree-llvm-system-linker-path=\"${_LINKER_TOOL_EXECUTABLE}\"")
  list(APPEND _TRANSLATE_ARGS "-iree-llvm-static-library-output-path=${_O_FILE_NAME}")
  list(APPEND _TRANSLATE_ARGS "${_MLIR_SRC}")
  list(APPEND _TRANSLATE_ARGS "-o")
  list(APPEND _TRANSLATE_ARGS "${_EMITC_FILE_NAME}")

  # Custom command for iree-compile to generate static library and C module.
  add_custom_command(
    OUTPUT
      ${_H_FILE_NAME}
      ${_O_FILE_NAME}
      ${_EMITC_FILE_NAME}
    COMMAND ${_TRANSLATE_TOOL_EXECUTABLE} ${_TRANSLATE_ARGS}
    DEPENDS
      ${_TRANSLATE_TOOL_EXECUTABLE}
      ${_MLIR_SRC}
      ${_RULE_DEPENDS}
      ${_LINKER_TOOL_EXECUTABLE}
  )

  add_library(${_LIB_NAME}
    STATIC
    ${_O_FILE_NAME}
  )

  SET_TARGET_PROPERTIES(
    ${_LIB_NAME}
    PROPERTIES
      LINKER_LANGUAGE C
  )

  add_library(${_EMITC_LIB_NAME}
    STATIC
    ${_EMITC_FILE_NAME}
  )
  target_compile_definitions(${_EMITC_LIB_NAME} PUBLIC EMITC_IMPLEMENTATION)

  SET_TARGET_PROPERTIES(
    ${_EMITC_LIB_NAME}
    PROPERTIES
      LINKER_LANGUAGE C
  )

  # Alias the iree_package_name library to iree::package::name.
  # This lets us more clearly map to Bazel and makes it possible to
  # disambiguate the underscores in paths vs. the separators.
  add_library(${_PACKAGE_NS}::${_RULE_C_NAME} ALIAS ${_LIB_NAME})
  add_library(${_PACKAGE_NS}::${_RULE_EMITC_NAME} ALIAS ${_EMITC_LIB_NAME})
  iree_package_dir(_PACKAGE_DIR)
  if(${_RULE_C_NAME} STREQUAL ${_PACKAGE_DIR})
    add_library(${_PACKAGE_NS} ALIAS ${_LIB_NAME})
  endif()
  if(${_RULE_EMITC_NAME} STREQUAL ${_PACKAGE_DIR})
    add_library(${_PACKAGE_NS} ALIAS ${_EMITC_LIB_NAME})
  endif()
endfunction()
