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
# Build the mlir bytecode modules with iree-compile. Note the last two flags
# are for RVV support.
#-------------------------------------------------------------------------------

springbok_modules(
  NAME
    mobilenet_v1
  SRC
    "https://storage.googleapis.com/tfhub-lite-models/tensorflow/lite-model/mobilenet_v1_0.25_224_quantized/1/default/1.tflite"
  C_IDENTIFIER
    "samples_quant_model_mobilenet_v1"
  FLAGS
    "-iree-input-type=tosa"
    "-riscv-v-vector-bits-min=512"
    "-riscv-v-fixed-length-vector-lmul-max=8"
)

#-------------------------------------------------------------------------------
# Binaries to execute the IREE model input
#-------------------------------------------------------------------------------

iree_model_input(
  NAME
    mobilenet_quant_input
  SHAPE
    "1, 224, 224, 3"
  SRC
    "https://storage.googleapis.com/download.tensorflow.org/ \
    example_images/YellowLabradorLooking_new.jpg"
  QUANT
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
    ::mobilenet_quant_input_c
    ::mobilenet_v1_bytecode_module_static_c
    ::mobilenet_v1_bytecode_module_static_lib
    iree::vm::bytecode_module
    samples::util::util_static
  LINKOPTS
    "LINKER:--defsym=__itcm_length__=1M"
    "LINKER:--defsym=__stack_size__=300k"
)

iree_cc_binary(
  NAME
    mobilenet_v1_emitc_static
  SRCS
    "mobilenet_v1.c"
  DEPS
    ::mobilenet_quant_input_c
    ::mobilenet_v1_c_module_static_emitc
    ::mobilenet_v1_c_module_static_lib
    samples::util::util_static
  LINKOPTS
    "LINKER:--defsym=__itcm_length__=1M"
    "LINKER:--defsym=__stack_size__=300k"
  COPTS
    "-DBUILD_EMITC"
)
