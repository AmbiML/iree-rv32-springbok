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
# https://github.com/llvm/llvm-project/blob/0eeab8b/llvm/lib/Target/RISCV/RISCVSubtarget.cpp#L30-L51
#-------------------------------------------------------------------------------

springbok_modules(
  NAME
    simple_float_mul
  SRC
    "simple_float_mul.mlir"
  C_IDENTIFIER
    "samples_simple_vec_mul_simple_float_mul"
  FLAGS
    "-iree-input-type=mhlo"
    "-riscv-v-fixed-length-vector-lmul-max=8"
  VMVX
  INLINE_HAL
)

springbok_modules(
  NAME
    simple_int_mul
  SRC
    "simple_int_mul.mlir"
  C_IDENTIFIER
    "samples_simple_vec_mul_simple_int_mul"
  FLAGS
    "-iree-input-type=mhlo"
    "-riscv-v-fixed-length-vector-lmul-max=8"
  VMVX
  INLINE_HAL
)

#-------------------------------------------------------------------------------
# Binaries to execute the MLIR bytecode modules
#-------------------------------------------------------------------------------

# Different util libraries available:
#   util_static: static library using regular HAL
#   util_vmvx: vmvx using regular HAL
#   util_static_inline: static library using inline HAL
#   util_vmvx_inline: vmvx using inline HAL

# If the program requires a larger stack size, add
#
#   LINKOPTS
#     "LINKER:--defsym=__stack_size__=<new stack size>"
#
# to increase it.

iree_cc_binary(
  NAME
    simple_float_vec_mul_bytecode_vmvx
  SRCS
    "float_vec.c"
  DEPS
    ::simple_float_mul_bytecode_module_vmvx_c
    samples::util::util_vmvx_inline
  LINKOPTS
    "LINKER:--defsym=__stack_size__=20k"
  COPTS
    "-DBUILD_VMVX"
)

iree_cc_binary(
  NAME
    simple_float_vec_mul_emitc_vmvx
  SRCS
    "float_vec.c"
  DEPS
    ::simple_float_mul_c_module_vmvx_emitc
    samples::util::util_vmvx_inline
  LINKOPTS
    "LINKER:--defsym=__stack_size__=20k"
  COPTS
    "-DBUILD_EMITC"
    "-DBUILD_VMVX"
)

iree_cc_binary(
  NAME
    simple_float_vec_mul_bytecode_static
  SRCS
    "float_vec.c"
  DEPS
    ::simple_float_mul_bytecode_module_static_c
    ::simple_float_mul_bytecode_module_static_lib
    iree::vm::bytecode_module
    samples::util::util_static_inline
  LINKOPTS
    "LINKER:--defsym=__stack_size__=20k"
)

iree_cc_binary(
  NAME
    simple_float_vec_mul_emitc_static
  SRCS
    "float_vec.c"
  DEPS
    ::simple_float_mul_c_module_static_emitc
    ::simple_float_mul_c_module_static_lib
    samples::util::util_static_inline
  LINKOPTS
    "LINKER:--defsym=__stack_size__=20k"
  COPTS
    "-DBUILD_EMITC"
)

iree_cc_binary(
  NAME
    simple_int_vec_mul_bytecode_vmvx
  SRCS
    "int_vec.c"
  DEPS
    ::simple_int_mul_bytecode_module_vmvx_c
    samples::util::util_vmvx_inline
  LINKOPTS
    "LINKER:--defsym=__stack_size__=20k"
  COPTS
    "-DBUILD_VMVX"
)

iree_cc_binary(
  NAME
    simple_int_vec_mul_emitc_vmvx
  SRCS
    "int_vec.c"
  DEPS
    ::simple_int_mul_c_module_vmvx_emitc
    samples::util::util_vmvx_inline
  LINKOPTS
    "LINKER:--defsym=__stack_size__=20k"
  COPTS
    "-DBUILD_EMITC"
    "-DBUILD_VMVX"
)

iree_cc_binary(
  NAME
    simple_int_vec_mul_bytecode_static
  SRCS
    "int_vec.c"
  DEPS
    ::simple_int_mul_bytecode_module_static_c
    ::simple_int_mul_bytecode_module_static_lib
    iree::vm::bytecode_module
    samples::util::util_static_inline
  LINKOPTS
    "LINKER:--defsym=__stack_size__=20k"
)

iree_cc_binary(
  NAME
    simple_int_vec_mul_emitc_static
  SRCS
    "int_vec.c"
  DEPS
    ::simple_int_mul_c_module_static_emitc
    ::simple_int_mul_c_module_static_lib
    samples::util::util_static_inline
  LINKOPTS
    "LINKER:--defsym=__stack_size__=20k"
  COPTS
    "-DBUILD_EMITC"
)
