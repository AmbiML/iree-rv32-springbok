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
# A modified version of iree_static_linker_test to apply common iree-compile flags
# Parameters:
# NAME: Name of target.
# SRC: Source file to compile into a bytecode module. Support relative path.
# C_IDENTIFIER: Identifier to use for generate c embed code.
# FLAGS: Flags to pass to the translation tool (list of strings).
# DEPENDS: List of other targets and files required for this binary.
# RVV_OFF: Indicate RVV is OFF (default: ON)
# EMITC: Uses EmitC to output C code instead of VM bytecode.
# INLINE_HAL: Use inline HAL.
#
# Examples:
# springbok_static_module(
#   NAME
#     simple_float_mul_c_module_static
#   SRC
#     "simple_float_mul.mlir"
#   C_IDENTIFIER
#     "simple_float_mul"
#   FLAGS
#     "-iree-input-type=mhlo"
#   RVV_OFF
#   EMITC
# )
#
function(springbok_static_module)
  cmake_parse_arguments(
    _RULE
    "RVV_OFF;EMITC;INLINE_HAL"
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

  iree_package_name(_PACKAGE_NAME)
  iree_package_ns(_PACKAGE_NS)

  set(_CPU_FEATURES "+m,+f,+zvl512b,+zve32x")
  if (${_RULE_RVV_OFF})
    set(_CPU_FEATURES "+m,+f")
  endif()

  # Set common iree-compile flags
  set(_COMPILER_ARGS ${_RULE_FLAGS})
  list(APPEND _COMPILER_ARGS "--iree-hal-target-backends=llvm-cpu")
  list(APPEND _COMPILER_ARGS "--iree-llvm-debug-symbols=false")
  list(APPEND _COMPILER_ARGS "--iree-vm-bytecode-module-strip-source-map=true")
  list(APPEND _COMPILER_ARGS "--iree-vm-emit-polyglot-zip=false")
  list(APPEND _COMPILER_ARGS "--iree-llvm-target-triple=riscv32-pc-linux-elf")
  list(APPEND _COMPILER_ARGS "--iree-llvm-target-cpu=generic-rv32")
  list(APPEND _COMPILER_ARGS "--iree-llvm-target-cpu-features=${_CPU_FEATURES}")
  list(APPEND _COMPILER_ARGS "--iree-llvm-target-abi=ilp32")
  list(APPEND _COMPILER_ARGS "--iree-llvm-link-embedded=false")
  if (${_RULE_INLINE_HAL})
    list(APPEND _COMPILER_ARGS "--iree-execution-model=inline-dynamic")
  endif()

  if(_RULE_EMITC)
    set(_O_FILE_NAME "${_RULE_NAME}_c.o")
    set(_H_FILE_NAME "${_RULE_NAME}_emitc.h")
    set(_MODULE_NAME "${_RULE_NAME}_emitc")

    get_filename_component(_MLIR_SRC "${_MLIR_SRC}" REALPATH)
    list(APPEND _COMPILER_ARGS "--output-format=vm-c")
    list(APPEND _COMPILER_ARGS "--iree-vm-target-index-bits=32")
    list(APPEND _COMPILER_ARGS "--iree-llvm-link-static")
    list(APPEND _COMPILER_ARGS "--iree-llvm-static-library-output-path=${_O_FILE_NAME}")
    list(APPEND _COMPILER_ARGS "${_MLIR_SRC}")
    list(APPEND _COMPILER_ARGS "-o")
    list(APPEND _COMPILER_ARGS "${_H_FILE_NAME}")

    set(_OUTPUT_FILES "${_H_FILE_NAME}")
    string(REPLACE ".o" ".h" _STATIC_HDR_PATH "${_O_FILE_NAME}")
    list(APPEND _OUTPUT_FILES "${_O_FILE_NAME}" "${_STATIC_HDR_PATH}")

    add_custom_command(
      OUTPUT ${_OUTPUT_FILES}
      COMMAND iree-compile ${_COMPILER_ARGS}
      DEPENDS iree-compile ${_MLIR_SRC}
    )

    set(_EMITC_LIB_NAME "${_PACKAGE_NAME}_${_MODULE_NAME}")
    add_library(${_EMITC_LIB_NAME}
      STATIC
      ${_H_FILE_NAME}
    )
    target_compile_definitions(${_EMITC_LIB_NAME} PUBLIC EMITC_IMPLEMENTATION=\"${_H_FILE_NAME}\")
    SET_TARGET_PROPERTIES(
      ${_EMITC_LIB_NAME}
      PROPERTIES
        LINKER_LANGUAGE C
    )
    add_library(${_PACKAGE_NS}::${_MODULE_NAME} ALIAS ${_EMITC_LIB_NAME})

  else()  # bytecode module path
    # Generate the embed data with the bytecode module.
    set(_O_FILE_NAME "${_RULE_NAME}.o")
    set(_H_FILE_NAME "${_RULE_NAME}.h")
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
      STATIC_LIB_PATH
        "${_O_FILE_NAME}"
      C_IDENTIFIER
        "${_RULE_C_IDENTIFIER}"
      PUBLIC
    )
  endif(_RULE_EMITC)

  set(_NAME "${_RULE_NAME}_lib")
  set(_LIB_NAME "${_PACKAGE_NAME}_${_NAME}")
  add_library(${_LIB_NAME}
    STATIC
    ${_O_FILE_NAME}
  )
  SET_TARGET_PROPERTIES(
    ${_LIB_NAME}
    PROPERTIES
    LINKER_LANGUAGE C
  )

  # Set alias for this static library to be used later in the function.
  add_library(${_PACKAGE_NS}::${_NAME} ALIAS ${_LIB_NAME})
endfunction()
