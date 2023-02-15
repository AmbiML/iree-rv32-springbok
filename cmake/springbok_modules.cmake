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

# springbok_modules()
#
# A wrapper for the springbok_bytecode_module and springbok_c_module to apply common iree-compile flags
# Parameters:
# NAME: Name of target.
# SRC: Source file to compile into a bytecode module. Support relative path and
#     URL.
# FLAGS: Flags to pass to the translation tool (list of strings).
# C_IDENTIFIER: Identifier to use for generate c embed code.
#     If omitted then no C embed code will be generated.
# RVV_OFF: Indicate RVV is OFF (default: ON)
# VMVX: Compile VMVX backend
# INLINE_HAL: Use inline HAL.
#
# Examples:
# springbok_modules(
#   NAME
#     mobilenet_v1
#   SRC
#     "https://storage.googleapis.com/tfhub-lite-models/tensorflow/lite-model/mobilenet_v1_0.25_224_quantized/1/default/1.tflite"
#   C_IDENTIFIER
#     "samples_quant_model_mobilenet_v1"
#   FLAGS
#     "-iree-input-type=tosa"
#     "-riscv-v-vector-bits-min=512"
#     "-riscv-v-fixed-length-vector-lmul-max=8"
# )
#
# springbok_modules(
#   NAME
#     simple_float_mul
#   SRC
#     "simple_float_mul.mlir"
#   C_IDENTIFIER
#     "samples_simple_vec_mul_simple_float_mul"
#   FLAGS
#     "-iree-input-type=mhlo"
# )
#

function(springbok_modules)
  cmake_parse_arguments(
    _RULE
    "RVV_OFF;VMVX;INLINE_HAL"
    "NAME;SRC;C_IDENTIFIER"
    "FLAGS"
    ${ARGN}
  )

  if (${_RULE_RVV_OFF})
    set(_RVV_OFF_ARG "RVV_OFF")
  endif()

  string(REGEX REPLACE "[ \t\r\n]" "" _RULE_SRC_TRIM ${_RULE_SRC})
  string(REGEX MATCH "^https:" _RULE_SRC_URL ${_RULE_SRC_TRIM})
  if (_RULE_SRC_URL)
    get_filename_component(_INPUT_EXT "${_RULE_SRC_TRIM}" LAST_EXT)
    set(_INPUT_FILENAME "${_RULE_NAME}${_INPUT_EXT}")
    find_program(_WGET wget HINT "$ENV{PATH}" REQUIRED)
    add_custom_command(
      OUTPUT
        ${_INPUT_FILENAME}
      COMMAND
        ${_WGET} -q -P "${CMAKE_CURRENT_BINARY_DIR}" -O "${_INPUT_FILENAME}"
        "${_RULE_SRC_TRIM}"
      COMMENT
        "Download ${_INPUT_FILENAME} from ${_RULE_SRC_TRIM}"
    )
    set(_INPUT_FILENAME "${CMAKE_CURRENT_BINARY_DIR}/${_INPUT_FILENAME}")
  else()
    set(_INPUT_FILENAME ${_RULE_SRC_TRIM})
  endif()

  if (${_RULE_INLINE_HAL})
    set(_INLINE_HAL_ARG "INLINE_HAL")
  endif()

  springbok_static_module(
    NAME
      "${_RULE_NAME}_bytecode_module_static"
    SRC
      "${_INPUT_FILENAME}"
    C_IDENTIFIER
      "${_RULE_C_IDENTIFIER}_bytecode_module_static"
    FLAGS
      ${_RULE_FLAGS}
    "${_RVV_OFF_ARG}"
    "${_INLINE_HAL_ARG}"
    DEPENDS
      "${_INPUT_FILENAME}"
  )

  springbok_static_module(
    NAME
      "${_RULE_NAME}_c_module_static"
    SRC
      "${_INPUT_FILENAME}"
    FLAGS
      ${_RULE_FLAGS}
    "${_RVV_OFF_ARG}"
    "${_INLINE_HAL_ARG}"
    EMITC
    DEPENDS
      "${_INPUT_FILENAME}"
  )

  if (${_RULE_VMVX})
    springbok_vmvx_module(
      NAME
        "${_RULE_NAME}_bytecode_module_vmvx"
      SRC
        "${_INPUT_FILENAME}"
      C_IDENTIFIER
        "${_RULE_C_IDENTIFIER}_bytecode_module_vmvx"
      FLAGS
        ${_RULE_FLAGS}
      DEPENDS
        "${_INPUT_FILENAME}"
      "${_INLINE_HAL_ARG}"
    )

    springbok_vmvx_module(
      NAME
        "${_RULE_NAME}_c_module_vmvx"
      SRC
        "${_INPUT_FILENAME}"
      FLAGS
        ${_RULE_FLAGS}
      "${_INLINE_HAL_ARG}"
      EMITC
      DEPENDS
        "${_INPUT_FILENAME}"
    )
  endif()

endfunction()
