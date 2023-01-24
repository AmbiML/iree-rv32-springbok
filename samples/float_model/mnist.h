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

#ifndef SAMPLES_FLOAT_MODEL_MNIST_H
#define SAMPLES_FLOAT_MODEL_MNIST_H

#include "samples/util/util.h"

typedef struct {
  int best_idx;
  float best_out;
} MnistOutput;

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

#endif  // SAMPLES_FLOAT_MODEL_MNIST_H_
