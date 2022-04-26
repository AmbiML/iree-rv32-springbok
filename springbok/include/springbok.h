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

#ifndef SPRINGBOK_H
#define SPRINGBOK_H
#include <springbok_intrinsics.h>
#include <stdio.h>

#define ERROR_TAG "ERROR"
#define WARN_TAG "WARN"
#define INFO_TAG "INFO"
#define DEBUG_TAG "DEBUG"
#define NOISY_TAG "NOISY"

#define LOG_FMT "%s |"
#define LOG_ARGS(LOG_TAG) LOG_TAG

#define LOG_MAX_SZ 256

#define SIMLOG(sim_log_level, fmt, ...)                  \
  do {                                                   \
    char tmp_log_msg[LOG_MAX_SZ];                        \
    snprintf(tmp_log_msg, LOG_MAX_SZ, fmt, __VA_ARGS__); \
    springbok_simprint_##sim_log_level(tmp_log_msg, 0);  \
  } while (0)

#define LOG_ERROR(msg, args...) \
  SIMLOG(error, LOG_FMT msg, LOG_ARGS(ERROR_TAG), ##args)
#define LOG_WARN(msg, args...) \
  SIMLOG(warning, LOG_FMT msg, LOG_ARGS(WARN_TAG), ##args)
#define LOG_INFO(msg, args...) \
  SIMLOG(info, LOG_FMT msg, LOG_ARGS(INFO_TAG), ##args)
#define LOG_DEBUG(msg, args...) \
  SIMLOG(debug, LOG_FMT msg, LOG_ARGS(DEBUG_TAG), ##args)
#define LOG_NOISY(msg, args...) \
  SIMLOG(noisy, LOG_FMT msg, LOG_ARGS(NOISY_TAG), ##args)

#ifdef __cplusplus
extern "C" {
#endif
int float_to_str(const int len, char *buffer, const float value);
#ifdef __cplusplus
}
#endif

#endif
