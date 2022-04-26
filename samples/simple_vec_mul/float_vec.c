/*
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Float simple_mul bytecode loading and input/output processes

#include "iree/base/api.h"
#include "iree/hal/api.h"
#include "samples/util/util.h"

// Compiled module embedded here to avoid file IO:
#if !defined(BUILD_EMITC)
#include "samples/simple_vec_mul/simple_float_mul_bytecode_module_static.h"
#include "samples/simple_vec_mul/simple_float_mul_bytecode_module_static_c.h"
#else
#include "samples/simple_vec_mul/simple_float_mul_c_module_static_c.h"
#include "samples/simple_vec_mul/simple_float_mul_c_module_static_emitc.h"
#endif

const MlModel kModel = {
    .num_input = 2,
    .num_input_dim = {1, 1},
    .input_shape = {{1024}, {1024}},
    .input_length = {1024, 1024},
    .input_size_bytes = {sizeof(float), sizeof(float)},
    .num_output = 1,
    .output_length = {1024},
    .output_size_bytes = sizeof(float),
    .hal_element_type = IREE_HAL_ELEMENT_TYPE_FLOAT_32,
    .entry_func = "module.simple_mul",
    .model_name = "simple_float_vec_mul",
};

iree_status_t create_module(iree_vm_module_t **module) {
#if !defined(BUILD_EMITC)
  const struct iree_file_toc_t *module_file_toc =
      samples_simple_vec_mul_simple_float_mul_bytecode_module_static_create();
  return iree_vm_bytecode_module_create(
      iree_make_const_byte_span(module_file_toc->data, module_file_toc->size),
      iree_allocator_null(), iree_allocator_system(), module);
#else
  return module_create(iree_allocator_system(), module);
#endif
}

iree_hal_executable_library_query_fn_t library_query(void) {
  return &simple_mul_dispatch_0_library_query;
}

iree_status_t load_input_data(const MlModel *model, void **buffer,
                              iree_const_byte_span_t **byte_span) {
  iree_status_t result = alloc_input_buffer(model, buffer);
  // Populate initial values
  // arg0 = 0, 1/4, 1/2, 3/4... 1023/4
  // arg1 = 0, 1/2, 1, 3/2... 1023/2
  if (iree_status_is_ok(result)) {
    for (int i = 0; i < model->input_length[0]; ++i) {
      ((float *)buffer[0])[i] = i / 4.0f;
      ((float *)buffer[1])[i] = i / 2.0f;
    }
  }
  for (int i = 0; i < model->num_input; ++i) {
    byte_span[i] = malloc(sizeof(iree_const_byte_span_t));
    *byte_span[i] = iree_make_const_byte_span(
        buffer[i], model->input_size_bytes[i] * model->input_length[i]);
  }
  return result;
}

iree_status_t process_output(const MlModel *model,
                             iree_hal_buffer_mapping_t *buffers,
                             MlOutput *output) {
  iree_status_t result = iree_ok_status();
  for (int i = 0; i < buffers[0].contents.data_length / sizeof(float); ++i) {
    if (((const float *)buffers[0].contents.data)[i] != i * i / 8.0f) {
      result = iree_make_status(IREE_STATUS_UNKNOWN, "result mismatches");
      break;
    }
  }
  return result;
}
