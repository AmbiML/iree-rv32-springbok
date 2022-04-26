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

#pragma once

#define SPRINGBOK_SIMPRINT_ERROR   (0)
#define SPRINGBOK_SIMPRINT_WARNING (1)
#define SPRINGBOK_SIMPRINT_INFO    (2)
#define SPRINGBOK_SIMPRINT_DEBUG   (3)
#define SPRINGBOK_SIMPRINT_NOISY   (4)

#define springbok_simprint_error(s, n)   springbok_simprint(SPRINGBOK_SIMPRINT_ERROR, s, n)
#define springbok_simprint_warning(s, n) springbok_simprint(SPRINGBOK_SIMPRINT_WARNING, s, n)
#define springbok_simprint_info(s, n)    springbok_simprint(SPRINGBOK_SIMPRINT_INFO, s, n)
#define springbok_simprint_debug(s, n)   springbok_simprint(SPRINGBOK_SIMPRINT_DEBUG, s, n)
#define springbok_simprint_noisy(s, n)   springbok_simprint(SPRINGBOK_SIMPRINT_NOISY, s, n)

// simprint
// Description:
//   This intrinsic prints a string and a number to the simulator console.
// Inputs:
//   _loglevel:
//     The logging level in decreasing priority (0 is highest priority, 4 is lowest)
//   _string:
//     A pointer to the null-terminated string to print
//   _number:
//     The number to print
// Outputs:
//   none
static inline void springbok_simprint(int _loglevel, const char *_string, int _number) {
  // simprint a0, a1, a2 # "-------[rs2][rs1]000[rd ]1111011"
  register int         loglevel __asm__ ("a0") = _loglevel;
  register const char *string   __asm__ ("a1") = _string;
  register int         number   __asm__ ("a2") = _number;
  __asm__ volatile ("\t.word 0x00C5857B\n" :
                  /* no outputs */ :
                  "r"(loglevel), "r"(string), "r"(number) :
                  /* no clobbers */);
}

// icount
// Description:
//   This intrinsic returns a 32-bit value representing the number of instructions executed since reset.
// Inputs:
//   none
// Outputs:
//   the number of instructions executed since reset
static inline unsigned int springbok_icount(void) {
  int retval;
  __asm__ volatile("csrr %0, 0x7c0;" : "=r"(retval));
  return retval;
}

// ccount
// Description:
//   This intrinsic returns a 32-bit value representing the number of unhalted cycles since reset.
// Inputs:
//   none
// Outputs:
//   the number of unhalted cycles since reset
static inline unsigned int springbok_ccount(void) {
  // ccount a0 # "------------00001001[rd ]1111011"
  int retval;
  __asm__ volatile("csrr %0, 0x7c1;" : "=r"(retval));
  return retval;
}

// hostreq
// Description:
//   This intrinsic halts Springbok and triggers a host request interrupt in an attached management core.
// Inputs:
//   none
// Outputs:
//   none
static inline void springbok_hostreq(void) {
  // hostreq # "-----------------010-----1111011"
  __asm__ volatile ("\t.word 0x0000207B\n" :
                    /* no outputs */ :
                    /* no inputs */ :
                    /* no clobbers */);
}

// finish
// Description:
//   This intrinsic halts and resets Springbok while triggerring a completion interrupt in an attached management core.
//   It's included here for completeness, but it should not actually be called by C/C++ applications as it bypasses
//   C/C++ destructors and crt stack sentinel verification.
// Inputs:
//   none
// Outputs:
//   none
__attribute__((noreturn)) static inline void springbok_finish(void) {
  // finish # "-----------------011-----1111011"
  __asm__ volatile ("\t.word 0x0000307B\n" :
                    /* no outputs */ :
                    /* no inputs */ :
                    /* no clobbers */);
  while(1);
}
