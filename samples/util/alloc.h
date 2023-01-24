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

#ifndef SAMPLES_UTIL_ALLOC_H_
#define SAMPLES_UTIL_ALLOC_H_

#include "samples/util/model_api.h"

// Allocate the input buffer w.r.t the model config.
// The buffer must be released by the external caller.
iree_status_t alloc_input_buffer(const MlModel *model, void **buffer);

#endif  // SAMPLES_UTIL_ALLOC_H_
