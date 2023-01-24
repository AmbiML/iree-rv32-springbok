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

#ifndef SAMPLES_QUANT_MODEL_MOBILENETV1_H
#define SAMPLES_QUANT_MODEL_MOBILENETV1_H

#include "samples/util/util.h"

typedef struct {
  int best_idx;
  int best_out;
} MobilenetV1Output;

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

#endif  // SAMPLES_QUANT_MODELS_MOBILENET_V1_H_
