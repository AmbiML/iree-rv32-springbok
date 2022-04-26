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

// Mobilenet_v1_0.25_224 quant model
// MlModel struct initialization to include model I/O info.
// Bytecode loading, input/output processes.

#include <springbok.h>

#include "iree/base/api.h"
#include "iree/hal/api.h"
#include "mobilenet_v1.h"
#include "samples/util/util.h"

// Compiled module embedded here to avoid file IO:
#include "samples/quant_model/mobilenet_quant_input_c.h"
#if !defined(BUILD_EMITC)
#include "samples/quant_model/mobilenet_v1_bytecode_module_static.h"
#include "samples/quant_model/mobilenet_v1_bytecode_module_static_c.h"
#else
#include "samples/quant_model/mobilenet_v1_c_module_static_c.h"
#include "samples/quant_model/mobilenet_v1_c_module_static_emitc.h"
#endif

const MlModel kModel = {
    .num_input = 1,
    .num_input_dim = {4},
    .input_shape = {{1, 224, 224, 3}},
    .input_length = {224 * 224 * 3},
    .input_size_bytes = {sizeof(uint8_t)},
    .num_output = 1,
    .output_length = {1001},
    .output_size_bytes = sizeof(uint8_t),
    .hal_element_type = IREE_HAL_ELEMENT_TYPE_UINT_8,
    .entry_func = "module.main",
    .model_name = "mobilenet_v1_0.25_224_quant",
};

MobilenetV1Output score;

iree_status_t create_module(iree_vm_module_t **module) {
#if !defined(BUILD_EMITC)
  const struct iree_file_toc_t *module_file_toc =
      samples_quant_model_mobilenet_v1_bytecode_module_static_create();
  return iree_vm_bytecode_module_create(
      iree_make_const_byte_span(module_file_toc->data, module_file_toc->size),
      iree_allocator_null(), iree_allocator_system(), module);
#else
  return module_create(iree_allocator_system(), module);
#endif
}

iree_hal_executable_library_query_fn_t library_query(void) {
#if !defined(BUILD_EMITC)
  return &mobilenet_v1_bytecode_module_static_linked_llvm_library_query;
#else
  return &mobilenet_v1_c_module_static_linked_llvm_library_query;
#endif
}

iree_status_t load_input_data(const MlModel *model, void **buffer,
                              iree_const_byte_span_t **byte_span) {
  byte_span[0] = malloc(sizeof(iree_const_byte_span_t));
  *byte_span[0] = iree_make_const_byte_span(
      mobilenet_quant_input,
      model->input_size_bytes[0] * model->input_length[0]);
  return iree_ok_status();
}

iree_status_t process_output(const MlModel *model,
                             iree_hal_buffer_mapping_t *buffers,
                             MlOutput *output) {
  iree_status_t result = iree_ok_status();
  // find the label index with best prediction
  int best_out = 0;
  int best_idx = -1;
  for (int i = 0; i < model->output_length[0]; ++i) {
    uint8_t out = ((uint8_t *)buffers[0].contents.data)[i];
    if (out > best_out) {
      best_out = out;
      best_idx = i;
    }
  }
  score.best_out = best_out;
  score.best_idx = best_idx;

  LOG_INFO("Image prediction result is: id: %d", best_idx + 1);

  output->result = &score;
  output->len = sizeof(score);
  return result;
}
