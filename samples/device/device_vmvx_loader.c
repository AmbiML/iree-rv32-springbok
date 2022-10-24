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

// VMVX module loading in IREE.

#include "iree/hal/drivers/local_sync/sync_device.h"
#include "iree/hal/local/loaders/vmvx_module_loader.h"
#include "iree/modules/hal/module.h"
#include "samples/device/device.h"
#include "samples/util/model_api.h"

// A function to create the HAL device from the different backend targets.
// The HAL device and loader are returned based on the implementation, and they
// must be released by the caller.
iree_status_t create_sample_device(iree_allocator_t host_allocator,
                                   iree_hal_device_t** out_device) {
  // Set parameters for the device created in the next step.
  iree_hal_sync_device_params_t params;
  iree_hal_sync_device_params_initialize(&params);

  iree_vm_instance_t* instance = NULL;
  iree_status_t status = iree_vm_instance_create(host_allocator, &instance);

  iree_hal_executable_loader_t* loader = NULL;
  if (iree_status_is_ok(status)) {
    status = iree_hal_vmvx_module_loader_create(
        instance, /*user_module_count=*/0, /*user_modules=*/NULL,
        host_allocator, &loader);
  }
  iree_vm_instance_release(instance);

  // Use the default host allocator for buffer allocations.
  iree_string_view_t identifier = iree_make_cstring_view("vmvx");
  iree_hal_allocator_t* device_allocator = NULL;
  if (iree_status_is_ok(status)) {
    status = iree_hal_allocator_create_heap(identifier, host_allocator,
                                            host_allocator, &device_allocator);
  }

  if (iree_status_is_ok(status)) {
    // Create the synchronous device.
    status = iree_hal_sync_device_create(
        identifier, &params, /*loader_count=*/1, &loader, device_allocator,
        host_allocator, out_device);
  }

  iree_hal_allocator_release(device_allocator);
  iree_hal_executable_loader_release(loader);
  return status;
}
