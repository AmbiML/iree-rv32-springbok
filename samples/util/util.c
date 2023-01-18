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

// An example based on iree/samples/simple_embedding.

#include "samples/util/util.h"

#include <springbok.h>
#include <stdio.h>

#include "iree/base/api.h"
#include "iree/hal/api.h"
#include "iree/modules/hal/inline/module.h"
#include "iree/modules/hal/loader/module.h"
#include "iree/modules/hal/module.h"
#include "iree/vm/api.h"
#include "iree/vm/bytecode_module.h"
#include "samples/device/device.h"

extern const MlModel kModel;
// Create context that will hold the module state across invocations.
static iree_status_t create_context(iree_vm_instance_t *instance,
                                    iree_hal_device_t **device,
                                    iree_vm_context_t **context) {
  iree_allocator_t host_allocator = iree_allocator_system();
  iree_status_t result = iree_vm_instance_create(host_allocator, &instance);

#if defined(BUILD_INLINE_HAL)
  IREE_RETURN_IF_ERROR(iree_hal_module_register_inline_types(instance));
#elif defined(BUILD_LOADER_HAL)
  IREE_RETURN_IF_ERROR(iree_hal_module_register_loader_types(instance));
#else
  IREE_RETURN_IF_ERROR(iree_hal_module_register_all_types(instance));
#endif

  iree_hal_executable_loader_t *loader = NULL;
  if (iree_status_is_ok(result)) {
    result = create_sample_device(host_allocator, device, &loader);
  }

  // Load bytecode or C module.
  iree_vm_module_t *module = NULL;
  if (iree_status_is_ok(result)) {
    result = create_module(instance, &module);
  }

#if defined(BUILD_INLINE_HAL) || defined(BUILD_LOADER_HAL)
  // Create hal_inline_module
  iree_vm_module_t *hal_inline_module = NULL;
  if (iree_status_is_ok(result)) {
    result = iree_hal_inline_module_create(
        instance, IREE_HAL_INLINE_MODULE_FLAG_NONE,
        iree_hal_device_allocator(*device), host_allocator, &hal_inline_module);
  }
#endif
#if defined(BUILD_INLINE_HAL)
  iree_vm_module_t *modules[] = {hal_inline_module, module};
#elif defined(BUILD_LOADER_HAL)
  // Create hal_loader_module
  iree_vm_module_t *hal_loader_module = NULL;
  if (iree_status_is_ok(result)) {
    result = iree_hal_loader_module_create(instance, IREE_HAL_MODULE_FLAG_NONE,
                                           /*loader_count=*/1, &loader,
                                           host_allocator, &hal_loader_module);
  }
  iree_hal_executable_loader_release(loader);
  iree_vm_module_t *modules[] = {hal_inline_module, hal_loader_module, module};
#else
  // Create hal_module
  iree_vm_module_t *hal_module = NULL;
  if (iree_status_is_ok(result)) {
    result =
        iree_hal_module_create(instance, *device, IREE_HAL_MODULE_FLAG_NONE,
                               host_allocator, &hal_module);
  }
  iree_vm_module_t *modules[] = {hal_module, module};
#endif

  // Allocate a context that will hold the module state across invocations.
  if (iree_status_is_ok(result)) {
    result = iree_vm_context_create_with_modules(
        instance, IREE_VM_CONTEXT_FLAG_NONE, IREE_ARRAYSIZE(modules),
        &modules[0], host_allocator, context);
  }
#if defined(BUILD_INLINE_HAL) || defined(BUILD_LOADER_HAL)
  iree_vm_module_release(hal_inline_module);
#else
  iree_vm_module_release(hal_module);
#endif
#if defined(BUILD_LOADER_HAL)
  iree_vm_module_release(hal_loader_module);
#endif
  iree_vm_module_release(module);
  return result;
}

// Prepare the input buffers and buffer_views based on the data type. They must
// be released by the caller.
static iree_status_t prepare_input_hal_buffer_views(
    const MlModel *model, iree_hal_device_t *device, void **arg_buffers,
    iree_hal_buffer_view_t **arg_buffer_views) {
  iree_status_t result = iree_ok_status();

  // Prepare the input buffer, and populate the initial value.
  // The input buffer must be released by the caller.
  iree_const_byte_span_t *byte_span[MAX_MODEL_INPUT_NUM] = {NULL};
  result = load_input_data(model, arg_buffers, byte_span);

  // Wrap buffers in shaped buffer views.
  // The buffers can be mapped on the CPU and that can also be used
  // on the device. Not all devices support this, but the ones we have now do.

  iree_hal_buffer_params_t buffer_params = {
      .type =
          IREE_HAL_MEMORY_TYPE_HOST_LOCAL | IREE_HAL_MEMORY_TYPE_DEVICE_VISIBLE,
      .access = IREE_HAL_MEMORY_ACCESS_READ,
      .usage = IREE_HAL_BUFFER_USAGE_DEFAULT};
  for (int i = 0; i < model->num_input; ++i) {
    if (iree_status_is_ok(result)) {
      result = iree_hal_buffer_view_allocate_buffer(
          iree_hal_device_allocator(device), model->num_input_dim[i],
          model->input_shape[i], model->hal_element_type,
          IREE_HAL_ENCODING_TYPE_DENSE_ROW_MAJOR, buffer_params, *byte_span[i],
          &(arg_buffer_views[i]));
    }
    if (byte_span[i] != NULL) {
      free(byte_span[i]);
    }
  }
  return result;
}

iree_status_t run(const MlModel *model) {
  iree_vm_instance_t *instance = NULL;
  iree_hal_device_t *device = NULL;
  iree_vm_context_t *context = NULL;
  // create context
  iree_status_t result = create_context(instance, &device, &context);

  // Lookup the entry point function.
  // Note that we use the synchronous variant which operates on pure type/shape
  // erased buffers.
  iree_vm_function_t main_function;
  if (iree_status_is_ok(result)) {
    result = (iree_vm_context_resolve_function(
        context, iree_make_cstring_view(model->entry_func), &main_function));
  }

  // Prepare the input buffers.
  void *arg_buffers[MAX_MODEL_INPUT_NUM] = {NULL};
  iree_hal_buffer_view_t *arg_buffer_views[MAX_MODEL_INPUT_NUM] = {NULL};
  if (iree_status_is_ok(result)) {
    result = prepare_input_hal_buffer_views(model, device, arg_buffers,
                                            arg_buffer_views);
  }

  // Setup call inputs with our buffers.
  iree_vm_list_t *inputs = NULL;
  if (iree_status_is_ok(result)) {
    result = iree_vm_list_create(
        /*element_type=*/NULL, /*capacity=*/model->num_input,
        iree_allocator_system(), &inputs);
  }
  iree_vm_ref_t arg_buffer_view_ref;
  for (int i = 0; i < model->num_input; ++i) {
    arg_buffer_view_ref = iree_hal_buffer_view_move_ref(arg_buffer_views[i]);
    if (iree_status_is_ok(result)) {
      result = iree_vm_list_push_ref_move(inputs, &arg_buffer_view_ref);
    }
  }

  // Prepare outputs list to accept the results from the invocation.
  // The output vm list is allocated statically.
  iree_vm_list_t *outputs = NULL;
  if (iree_status_is_ok(result)) {
    result = iree_vm_list_create(
        /*element_type=*/NULL,
        /*capacity=*/1, iree_allocator_system(), &outputs);
  }

  // Invoke the function.
  if (iree_status_is_ok(result)) {
    result = iree_vm_invoke(context, main_function, IREE_VM_CONTEXT_FLAG_NONE,
                            /*policy=*/NULL, inputs, outputs,
                            iree_allocator_system());
  }

  // Validate output and gather buffers.
  iree_hal_buffer_mapping_t mapped_memories[MAX_MODEL_OUTPUTS] = {{0}};
  for (int index_output = 0; index_output < model->num_output; index_output++) {
    iree_hal_buffer_view_t *ret_buffer_view = NULL;
    if (iree_status_is_ok(result)) {
      // Get the result buffers from the invocation.
      ret_buffer_view = (iree_hal_buffer_view_t *)iree_vm_list_get_ref_deref(
          outputs, index_output, iree_hal_buffer_view_get_descriptor());
      if (ret_buffer_view == NULL) {
        result = iree_make_status(IREE_STATUS_NOT_FOUND,
                                  "can't find return buffer view");
      }
    }
    if (iree_status_is_ok(result)) {
      result = iree_hal_buffer_map_range(
          iree_hal_buffer_view_buffer(ret_buffer_view),
          IREE_HAL_MAPPING_MODE_SCOPED, IREE_HAL_MEMORY_ACCESS_READ, 0,
          IREE_WHOLE_BUFFER, &mapped_memories[index_output]);
    }

    if (iree_status_is_ok(result)) {
      if (index_output > model->num_output ||
          mapped_memories[index_output].contents.data_length /
                  model->output_size_bytes !=
              model->output_length[index_output]) {
        result =
            iree_make_status(IREE_STATUS_UNKNOWN, "output length mismatches");
      }
    }
  }

  // Post-process memory into model output.
  if (iree_status_is_ok(result)) {
    MlOutput output = {.result = NULL, .len = 0};
    result = process_output(model, mapped_memories, &output);
    // TODO: Utilize the output in the larger system.
  }

  for (int index_output = 0; index_output < model->num_output; index_output++) {
    if (mapped_memories[index_output].contents.data != NULL) {
      iree_hal_buffer_unmap_range(&mapped_memories[index_output]);
    }
  }
  iree_vm_list_release(inputs);
  iree_vm_list_release(outputs);
  for (int i = 0; i < model->num_input; ++i) {
    if (arg_buffers[i] != NULL) {
      free(arg_buffers[i]);
    }
  }
  iree_vm_context_release(context);
  IREE_IGNORE_ERROR(iree_hal_allocator_statistics_fprint(
      stdout, iree_hal_device_allocator(device)));
  iree_hal_device_release(device);
  iree_vm_instance_release(instance);
  return result;
}

int main() {
  const MlModel *model_ptr = &kModel;
  const iree_status_t result = run(model_ptr);
  int ret = (int)iree_status_code(result);
  if (!iree_status_is_ok(result)) {
    iree_status_fprint(stderr, result);
    iree_status_free(result);
  } else {
    LOG_INFO("%s finished successfully", model_ptr->model_name);
  }

  return ret;
}
