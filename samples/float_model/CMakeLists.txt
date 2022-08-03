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

#-------------------------------------------------------------------------------
# Build the mlir bytecode modules with iree-compile.
#-------------------------------------------------------------------------------

springbok_modules(
  NAME
    mobilenet_v1
  SRC
    "https://storage.googleapis.com/tfhub-lite-models/tensorflow/lite-model/mobilenet_v1_0.25_224/1/default/1.tflite"
  C_IDENTIFIER
    "samples_float_model_mobilenet_v1"
  FLAGS
    "-iree-input-type=tosa"
  PUBLIC
)

springbok_modules(
  NAME
    mnist
  SRC
    "${CMAKE_SOURCE_DIR}/third_party/iree/samples/models/mnist.mlir"
  C_IDENTIFIER
    "samples_float_model_mnist"
  FLAGS
    "-iree-input-type=mhlo"
  PUBLIC
)

#-------------------------------------------------------------------------------
# Binaries to execute the IREE model input
#-------------------------------------------------------------------------------

iree_model_input(
  NAME
    mobilenet_input
  SHAPE
    "1, 224, 224, 3"
  SRC
    "https://storage.googleapis.com/download.tensorflow.org/ \
    example_images/YellowLabradorLooking_new.jpg"
)

iree_model_input(
  NAME
    mnist_input
  SHAPE
    "1, 28, 28, 1"
  SRC
    "https://github.com/google/iree/raw/ \
    1e8d1fa96057c47d1fda918f3a2f71f14b073937/samples/iree_vision_inference/mnist_test.png"
  RANGE
    "0, 1"
)

#-------------------------------------------------------------------------------
# Binaries to execute the MLIR bytecode modules
#-------------------------------------------------------------------------------


# If the program requires a larger stack size, add
#
#   LINKOPTS
#     "LINKER:--defsym=__stack_size__=<new stack size>"
#
# to increase it.

iree_cc_binary(
  NAME
    mobilenet_v1_bytecode_static
  SRCS
    "mobilenet_v1.c"
  DEPS
    ::mobilenet_v1_bytecode_module_static
    ::mobilenet_v1_bytecode_module_static_c
    ::mobilenet_input_c
    iree::vm::bytecode_module
    samples::util::util
  LINKOPTS
    "LINKER:--defsym=__itcm_length__=1M"
    "LINKER:--defsym=__stack_size__=200k"
)

iree_cc_binary(
  NAME
    mobilenet_v1_emitc_static
  SRCS
    "mobilenet_v1.c"
  DEPS
    ::mobilenet_v1_c_module_static_c
    ::mobilenet_v1_c_module_static_emitc
    ::mobilenet_input_c
    samples::util::util
    "m"
  LINKOPTS
    "LINKER:--defsym=__itcm_length__=1M"
    "LINKER:--defsym=__stack_size__=200k"
  COPTS
    "-DBUILD_EMITC"
)

iree_cc_binary(
  NAME
    mnist_bytecode_static
  SRCS
    "mnist.c"
  DEPS
    ::mnist_bytecode_module_static
    ::mnist_bytecode_module_static_c
    ::mnist_input_c
    iree::vm::bytecode_module
    samples::util::util
  LINKOPTS
    "LINKER:--defsym=__stack_size__=100k"
)

iree_cc_binary(
  NAME
    mnist_emitc_static
  SRCS
    "mnist.c"
  DEPS
    ::mnist_c_module_static_c
    ::mnist_c_module_static_emitc
    ::mnist_input_c
    samples::util::util
    "m"
  LINKOPTS
    "LINKER:--defsym=__stack_size__=100k"
  COPTS
    "-DBUILD_EMITC"
)
