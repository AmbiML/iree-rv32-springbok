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

# iree_model_input()
#
# CMake function to load an external model input (an image)
# and convert to the iree_c_embed_data.
#
# Parameters:
# NAME: Name of model input image.
# SHAPE: Input shape.
# SRC: Input image URL.
# QUANT: When added, indicate it's a quant model.
#
# Examples:
# iree_model_input(
#   NAME
#     mobilenet_quant_input
#   SHAPE
#     "1, 224, 224, 3"
#   SRC
#     "https://storage.googleapis.com/download.tensorflow.org/ \
#     example_images/YellowLabradorLooking_new.jpg"
#   QUANT
# )
#
function(iree_model_input)
  cmake_parse_arguments(
    _RULE
    "QUANT"
    "NAME;SHAPE;SRC;RANGE"
    ""
    ${ARGN}
  )

  string(REGEX REPLACE "[ \t\r\n]" "" _RULE_SRC_TRIM ${_RULE_SRC})
  string(REGEX MATCH "^https:" _RULE_SRC_URL ${_RULE_SRC_TRIM})
  if (_RULE_SRC_URL)
    get_filename_component(_INPUT_FILENAME "${_RULE_SRC}" NAME)
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
  else()
    set(_INPUT_FILENAME ${_RULE_SRC_TRIM})
  endif()

  set(_GEN_INPUT_SCRIPT "${CMAKE_SOURCE_DIR}/build_tools/gen_mlmodel_input.py")
  set(_OUTPUT_BINARY ${_RULE_NAME})
  set(_ARGS)
  list(APPEND _ARGS "--i=${_INPUT_FILENAME}")
  list(APPEND _ARGS "--o=${_OUTPUT_BINARY}")
  list(APPEND _ARGS "--s=${_RULE_SHAPE}")
  if(_RULE_RANGE)
    list(APPEND _ARGS "--r=${_RULE_RANGE}")
  endif()
  if(_RULE_QUANT)
    list(APPEND _ARGS "--q")
  endif()

  # Replace dependencies passed by ::name with iree::package::name
  iree_package_ns(_PACKAGE_NS)
  list(TRANSFORM _RULE_DEPS REPLACE "^::" "${_PACKAGE_NS}::")

  # Prefix the library with the package name, so we get: iree_package_name.
  iree_package_name(_PACKAGE_NAME)

  set(_RULE_C_NAME "${_RULE_NAME}_c")
  set(_LIB_NAME "${_PACKAGE_NAME}_${_RULE_C_NAME}")
  set(_GEN_TARGET "${_LIB_NAME}_gen")
  set(_H_FILE_NAME ${_RULE_C_NAME}.h)

  add_custom_command(
    OUTPUT
      ${_OUTPUT_BINARY}
      ${_H_FILE_NAME}
    COMMAND
      ${_GEN_INPUT_SCRIPT} ${_ARGS}
    COMMAND
      xxd -i ${_OUTPUT_BINARY} > ${_H_FILE_NAME}
    DEPENDS
      ${_GEN_INPUT_SCRIPT}
      ${_INPUT_FILENAME}
  )

  add_custom_target(
    ${_GEN_TARGET}
    DEPENDS
      "${_H_FILE_NAME}"
  )

  add_library(${_LIB_NAME}
  ${_H_FILE_NAME}
 )
 add_dependencies(${_LIB_NAME} ${_GEN_TARGET})

 SET_TARGET_PROPERTIES(
   ${_LIB_NAME}
   PROPERTIES
   LINKER_LANGUAGE C
 )

 # Alias the iree_package_name library to iree::package::name.
 # This lets us more clearly map to Bazel and makes it possible to
 # disambiguate the underscores in paths vs. the separators.
 add_library(${_PACKAGE_NS}::${_RULE_C_NAME} ALIAS ${_LIB_NAME})
 iree_package_dir(_PACKAGE_DIR)
 if(${_RULE_C_NAME} STREQUAL ${_PACKAGE_DIR})
   add_library(${_PACKAGE_NS} ALIAS ${_LIB_NAME})
 endif()
endfunction()
