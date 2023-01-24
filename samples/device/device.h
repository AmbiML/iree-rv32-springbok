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

#ifndef SAMPLES_DEVICE_DEVICE_H_
#define SAMPLES_DEVICE_DEVICE_H_

#include "iree/hal/local/executable_loader.h"

// Create the HAL device from the different backend targets.
// The HAL device and loader are returned based on the implementation, and they
// must be released by the caller.
iree_status_t create_sample_device(iree_allocator_t host_allocator,
                                   iree_hal_device_t** out_device,
                                   iree_hal_executable_loader_t** loader);

#endif  // SAMPLES_DEVICE_DEVICE_H_
