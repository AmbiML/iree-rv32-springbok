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

#ifndef SAMPLES_UTIL_MODEL_API_H_
#define SAMPLES_UTIL_MODEL_API_H_

// Define ML model configuration and model-specific utility APIs.

#include "iree/base/api.h"
#include "iree/hal/api.h"
#include "iree/hal/local/executable_library.h"
#include "iree/modules/hal/module.h"
#include "iree/vm/api.h"
#include "iree/vm/bytecode_module.h"

#define MAX_MODEL_INPUT_NUM 2
#define MAX_MODEL_INPUT_DIM 4
#define MAX_MODEL_OUTPUTS 12
#define MAX_ENTRY_FUNC_NAME 20

typedef struct {
  int num_input;
  int num_input_dim[MAX_MODEL_INPUT_NUM];
  iree_hal_dim_t input_shape[MAX_MODEL_INPUT_NUM][MAX_MODEL_INPUT_DIM];
  int input_length[MAX_MODEL_INPUT_NUM];
  int input_size_bytes[MAX_MODEL_INPUT_NUM];
  int num_output;
  int output_length[MAX_MODEL_OUTPUTS];
  int output_size_bytes;
  enum iree_hal_element_types_t hal_element_type;
  char entry_func[MAX_ENTRY_FUNC_NAME];
  char model_name[];
} MlModel;

typedef struct {
  void *result;
  uint32_t len;
} MlOutput;

// Load the statically embedded library
iree_hal_executable_library_query_fn_t library_query(void);

// Function to create the bytecode or C module.
iree_status_t create_module(iree_vm_instance_t *instance,
                            iree_vm_module_t **module);

// For each ML workload, based on the model configuration, allocate the buffer
// and prepare the data. It can be loaded from a embedded image binary, a
// randomly generated stream, or a pointer from the sensor/ISP output.
iree_status_t load_input_data(const MlModel *model, void **buffer,
                              iree_const_byte_span_t **byte_span);

// Process the ML execution output into the final data to be sent to the
// host. The final format is model dependent, so the address and size
// are returned via `output.`
iree_status_t process_output(const MlModel *model,
                             iree_hal_buffer_mapping_t *buffers,
                             MlOutput *output);

#endif  // SAMPLES_UTIL_MODEL_API_H_
