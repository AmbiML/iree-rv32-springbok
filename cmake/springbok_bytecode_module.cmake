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

# springbok_bytecode_module()
#
# A wrapper for the iree_bytecode_module to apply common iree-compile flags
# Parameters:
# NAME: Name of target.
# SRC: Source file to compile into a bytecode module. Support relative path.
# FLAGS: Flags to pass to the translation tool (list of strings).
# C_IDENTIFIER: Identifier to use for generate c embed code.
#     If omitted then no C embed code will be generated.
# DEPENDS: List of other targets and files required for this binary.
# RVV_OFF: Indicate RVV is OFF (default: ON)
#
# Examples:
# springbok_bytecode_module(
#   NAME
#     simple_float_mul_bytecode_module_static
#   SRC
#     "simple_float_mul.mlir"
#   C_IDENTIFIER
#     "simple_float_mul_bytecode_module_static"
#   FLAGS
#     "-iree-input-type=mhlo"
#   RVV_OFF
#   PUBLIC
# )
#
function(springbok_bytecode_module)
  cmake_parse_arguments(
    _RULE
    "PUBLIC;RVV_OFF"
    "NAME;SRC;C_IDENTIFIER"
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

  set(_LIB_NAME "${_PACKAGE_NAME}_${_RULE_NAME}")
  set(_O_FILE_NAME ${_RULE_NAME}.o)
  set(_H_FILE_NAME ${_RULE_NAME}.h)
  set(_VMFB_FILE_NAME ${_RULE_NAME}.vmfb)

  set(_CPU_FEATURES "+m,+f,+zvl512b,+zve32x")
  if (${_RULE_RVV_OFF})
    set(_CPU_FEATURES "+m,+f")
  endif()

  ## Example with VM C module.
  # Setup args for iree-compile.
  set(_TRANSLATE_ARGS ${_RULE_FLAGS})
  list(APPEND _TRANSLATE_ARGS "-iree-mlir-to-vm-bytecode-module")
  list(APPEND _TRANSLATE_ARGS "-iree-hal-target-backends=llvm-cpu")
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
  list(APPEND _TRANSLATE_ARGS "${_VMFB_FILE_NAME}")

  # Custom command for iree-compile to generate static library and C module.
  add_custom_command(
    OUTPUT
      ${_H_FILE_NAME}
      ${_O_FILE_NAME}
      ${_VMFB_FILE_NAME}
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

  # Alias the iree_package_name library to iree::package::name.
  # This lets us more clearly map to Bazel and makes it possible to
  # disambiguate the underscores in paths vs. the separators.
  add_library(${_PACKAGE_NS}::${_RULE_NAME} ALIAS ${_LIB_NAME})
  iree_package_dir(_PACKAGE_DIR)
  if(${_RULE_NAME} STREQUAL ${_PACKAGE_DIR})
    add_library(${_PACKAGE_NS} ALIAS ${_LIB_NAME})
  endif()

  set(_RULE_C_NAME "${_RULE_NAME}_c")
  set(_H_FILE_NAME ${_RULE_C_NAME}.h)
  set(_C_FILE_NAME ${_RULE_C_NAME}.c)

  # Generate the embed data with the bytecode module
  iree_c_embed_data(
    NAME
      "${_RULE_C_NAME}"
    IDENTIFIER
      "${_RULE_C_IDENTIFIER}"
    GENERATED_SRCS
      "${_VMFB_FILE_NAME}"
    C_FILE_OUTPUT
      "${_C_FILE_NAME}"
    H_FILE_OUTPUT
      "${_H_FILE_NAME}"
    FLATTEN
    PUBLIC
  )
endfunction()
