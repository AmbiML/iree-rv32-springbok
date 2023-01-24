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

#include "mobilenet_v1.h"

#include <springbok.h>

// Compiled module embedded here to avoid file IO:
#include "samples/quant_model/mobilenet_quant_input_c.h"
#if !defined(BUILD_EMITC)
#include "samples/quant_model/mobilenet_v1_bytecode_module_static.h"
#include "samples/quant_model/mobilenet_v1_bytecode_module_static_c.h"
#else
#include "samples/quant_model/mobilenet_v1_c_module_static_c.h"
#include "samples/quant_model/mobilenet_v1_c_module_static_emitc.h"
#endif

MobilenetV1Output score;

iree_status_t create_module(iree_vm_instance_t *instance,
                            iree_vm_module_t **module) {
#if !defined(BUILD_EMITC)
  const struct iree_file_toc_t *module_file_toc =
      samples_quant_model_mobilenet_v1_bytecode_module_static_create();
  return iree_vm_bytecode_module_create(
      instance,
      iree_make_const_byte_span(module_file_toc->data, module_file_toc->size),
      iree_allocator_null(), iree_allocator_system(), module);
#else
  return module_create(instance, iree_allocator_system(), module);
#endif
}

iree_hal_executable_library_query_fn_t library_query(void) {
  return &mobilenet_v1_linked_llvm_cpu_library_query;
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
                             uint32_t *output_length) {
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

  *output_length = sizeof(score);
  return result;
}
