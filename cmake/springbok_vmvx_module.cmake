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
# springbok_static_module()
#
# A modified version of iree_vmvx_linker_test to apply common iree-compile flags
# Parameters:
# NAME: Name of target.
# SRC: Source file to compile into a bytecode module. Support relative path.
# FLAGS: Flags to pass to the translation tool (list of strings).
# DEPENDS: List of other targets and files required for this binary.
# EMITC: Uses EmitC to output C code instead of VM bytecode.
# INLINE_HAL: Use inline HAL.
#
# Examples:
# springbok_vmvx_module(
#   NAME
#     simple_float_mul_c_module_vmvx
#   SRC
#     "simple_float_mul.mlir"
#   C_IDENTIFIER
#     "simple_float_mul"
#   FLAGS
#     "-iree-input-type=mhlo"
#   EMITC
# )
#
function(springbok_vmvx_module)
  cmake_parse_arguments(
    _RULE
    "EMITC;INLINE_HAL"
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
    list(APPEND _ARGS "--output-format=mlir-ir")
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
  iree_get_executable_path(_COMPILER_TOOL "iree-compile")
  iree_package_name(_PACKAGE_NAME)
  iree_package_ns(_PACKAGE_NS)

  # Set common iree-compile flags
  set(_COMPILER_ARGS ${_RULE_FLAGS})
  if (${_RULE_INLINE_HAL})
    list(APPEND _COMPILER_ARGS "--iree-execution-model=inline-static")
    list(APPEND _COMPILER_ARGS "--iree-hal-target-backends=vmvx-inline")
  else()
    list(APPEND _COMPILER_ARGS "--iree-hal-target-backends=vmvx")
  endif()

  if(_RULE_EMITC)
    list(APPEND _COMPILER_ARGS "--iree-vm-target-index-bits=32")
    set(_MODULE_NAME "${_RULE_NAME}_emitc")
    set(_H_FILE_NAME "${_RULE_NAME}_emitc.h")
    iree_c_module(
      NAME
        ${_MODULE_NAME}
      SRC
        "${_MLIR_SRC}"
      FLAGS
        ${_COMPILER_ARGS}
      H_FILE_OUTPUT
        "${_H_FILE_NAME}"
      NO_RUNTIME
    )
  else()  # bytecode module path
    # Generate the embed data with the bytecode module.
    set(_MODULE_NAME "${_RULE_NAME}")
    if(NOT _RULE_C_IDENTIFIER)
      set(_RULE_C_IDENTIFIER "${_PACKAGE_NAME}_${_RULE_NAME}")
    endif()
    iree_bytecode_module(
      NAME
        ${_MODULE_NAME}
      SRC
        "${_MLIR_SRC}"
      FLAGS
        ${_COMPILER_ARGS}
      C_IDENTIFIER
        "${_RULE_C_IDENTIFIER}"
      PUBLIC
    )
  endif(_RULE_EMITC)
endfunction()
