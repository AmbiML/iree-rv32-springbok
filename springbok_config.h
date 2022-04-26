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

// Springbok-specific implementation for some IREE functions.

#ifndef SPRINGBOK_CONFIG_H
#define SPRINGBOK_CONFIG_H

// IREE_TIME_NOW_FN is required and used to fetch the current RTC time and to be
// used for wait handling. A thread-less system can just return 0.
#define IREE_TIME_NOW_FN \
  {                      \
    return 0;            \
  }

// IREE_DEVICE_SIZE_T for status print out.
#define IREE_DEVICE_SIZE_T uint32_t
#define PRIdsz PRIu32

#endif // SPRINGBOK_CONFIG_H
