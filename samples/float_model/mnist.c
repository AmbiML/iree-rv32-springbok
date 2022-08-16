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

// mnist float model
// MlModel struct initialization to include model I/O info.
// Bytecode loading, input/output processes.

#include "mnist.h"

#include <springbok.h>

#include "iree/base/api.h"
#include "iree/hal/api.h"
#include "samples/util/util.h"

// Compiled module embedded here to avoid file IO:
#if !defined(BUILD_EMITC)
#include "samples/float_model/mnist_bytecode_module_static.h"
#include "samples/float_model/mnist_bytecode_module_static_c.h"
#else
#include "samples/float_model/mnist_c_module_static_c.h"
#include "samples/float_model/mnist_c_module_static_emitc.h"
#endif
#include "samples/float_model/mnist_input_c.h"

const MlModel kModel = {
    .num_input = 1,
    .num_input_dim = {4},
    .input_shape = {{1, 28, 28, 1}},
    .input_length = {28 * 28 * 1},
    .input_size_bytes = {sizeof(float)},
    .num_output = 1,
    .output_length = {10},
    .output_size_bytes = sizeof(float),
    .hal_element_type = IREE_HAL_ELEMENT_TYPE_FLOAT_32,
    .entry_func = "module.predict",
    .model_name = "mnist",
};

MnistOutput score;

iree_status_t create_module(iree_vm_instance_t *instance,
                            iree_vm_module_t **module) {
#if !defined(BUILD_EMITC)
  const struct iree_file_toc_t *module_file_toc =
      samples_float_model_mnist_bytecode_module_static_create();
  return iree_vm_bytecode_module_create(
      instance,
      iree_make_const_byte_span(module_file_toc->data, module_file_toc->size),
      iree_allocator_null(), iree_allocator_system(), module);
#else
  return module_create(instance, iree_allocator_system(), module);
#endif
}

iree_hal_executable_library_query_fn_t library_query(void) {
  return &mnist_linked_llvm_cpu_library_query;
}

iree_status_t load_input_data(const MlModel *model, void **buffer,
                              iree_const_byte_span_t **byte_span) {
  byte_span[0] = malloc(sizeof(iree_const_byte_span_t));
  *byte_span[0] = iree_make_const_byte_span(
      mnist_input, model->input_size_bytes[0] * model->input_length[0]);
  return iree_ok_status();
}

iree_status_t process_output(const MlModel *model,
                             iree_hal_buffer_mapping_t *buffers,
                             MlOutput *output) {
  iree_status_t result = iree_ok_status();
  // find the label index with best prediction
  float best_out = 0.0;
  int best_idx = -1;
  for (int i = 0; i < model->output_length[0]; ++i) {
    float out = ((float *)buffers[0].contents.data)[i];
    if (out > best_out) {
      best_out = out;
      best_idx = i;
    }
  }

  score.best_out = best_out;
  score.best_idx = best_idx;

  LOG_INFO("Digit recognition result is: digit: %d", best_idx);

  output->result = &score;
  output->len = sizeof(score);
  return result;
}
