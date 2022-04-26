// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <stdint.h>
#include "springbok.h"

#ifndef LIBSPRINGBOK_NO_EXCEPTION_SUPPORT

extern "C" void print_csrs(void) {
    uint32_t mcause;
    uint32_t mepc;
    uint32_t mtval;
    uint32_t misa;
    uint32_t mtvec;
    uint32_t mhartid;
    uint32_t marchid;
    uint32_t mvendorid;
    uint32_t mimpid;
    __asm__ volatile("csrr %[MCAUSE], mcause"
                   : [MCAUSE] "=r"(mcause):);
    __asm__ volatile("csrr %[MEPC], mepc"
                   : [MEPC] "=r"(mepc):);
    __asm__ volatile("csrr %[MTVAL], mtval"
                   : [MTVAL] "=r"(mtval):);
    __asm__ volatile("csrr %[MISA], misa"
                   : [MISA] "=r"(misa):);
    __asm__ volatile("csrr %[MTVEC], mtvec"
                   : [MTVEC] "=r"(mtvec):);
    __asm__ volatile("csrr %[MHARTID], mhartid"
                   : [MHARTID] "=r"(mhartid):);
    __asm__ volatile("csrr %[MARCHID], marchid"
                   : [MARCHID] "=r"(marchid):);
    __asm__ volatile("csrr %[MVENDORID], mvendorid"
                   : [MVENDORID] "=r"(mvendorid):);
    __asm__ volatile("csrr %[MIMPID], mimpid"
                   : [MIMPID] "=r"(mimpid):);
    LOG_ERROR("MCAUSE:\t\t0x%08X", static_cast<unsigned int>(mcause));
    LOG_ERROR("MEPC:\t\t0x%08X", static_cast<unsigned int>(mepc));
    LOG_ERROR("MTVAL:\t\t0x%08X", static_cast<unsigned int>(mtval));
    LOG_ERROR("MISA:\t\t0x%08X", static_cast<unsigned int>(misa));
    LOG_ERROR("MTVEC:\t\t0x%08X", static_cast<unsigned int>(mtvec));
    LOG_ERROR("MHARTID:\t\t0x%08X", static_cast<unsigned int>(mhartid));
    LOG_ERROR("MARCHID:\t\t0x%08X", static_cast<unsigned int>(marchid));
    LOG_ERROR("MVENDORID:\t0x%08X", static_cast<unsigned int>(mvendorid));
    LOG_ERROR("MIMPID:\t\t0x%08X", static_cast<unsigned int>(mimpid));
 }

#endif

#ifndef LIBSPRINGBOK_NO_FLOAT_SUPPORT

// Helper function for float_to_str. Copies a string into the output buffer.
static void print_str(char *buffer, const int len, int *l, const char *str) {
  for (int i = 0; str[i] != '\0'; i++) {
    if (*l < len) {
      buffer[*l] = str[i];
    }
    (*l)++;
  }
}

// Helper function for float_to_str. Copies a fixed-point decimal number up to
// 16 digits long into the output buffer.
static void print_fp_num(char *buffer, const int len, int *l, uint64_t abs_value,
                         const bool negative, const int fixed_point) {
  uint8_t digits[16];
  int i;

  for(i = 0; i < 16; i++) {
    digits[i] = abs_value % 10;
    abs_value /= 10;
  }
  for(i = 15; i > fixed_point; i--) {
    if (digits[i]) {
      break;
    }
  }
  if (negative) {
    if ((*l) < len) {
      buffer[*l] = '-';
    }
    (*l)++;
  }
  for(; i >= 0; i--) {
    if(i == fixed_point-1) {
      if((*l) < len) {
        buffer[*l] = '.';
      }
      (*l)++;
    }
    if((*l) < len) {
      buffer[*l] = digits[i] + '0';
    }
    (*l)++;
  }
}

// This function converts a floating point value into a string. It doesn't rely
// on any external library functions to do so, including string manipulation
// functions. It's (probably) not good enough for production and may have bugs.
// Always prints at least 7 significant figures, which is just slightly less
// precise than single precision.
//
// Usage:
//   [Code]
//     int main(void) {
//       const float sorta_pi = 3.141592653589f;
//       int chars_needed = float_to_str(0, NULL, sorta_pi);
//       char *buffer = new char[chars_needed];
//       float_to_str(chars_needed, buffer, sorta_pi);
//       printf("Pi is ~%s, %d characters printed\n", buffer, chars_needed);
//       delete[] buffer;
//       return 0;
//     }
//
//   [Output]
//     Pi is 3.141592, 9 characters printed
extern "C" int float_to_str(const int len, char *buffer, const float value) {
  if (buffer == NULL && len != 0) {
    // Bad inputs
    LOG_ERROR("float_to_str handed null buffer with non-zero length! len:%d",
              len);
    return 0;
  }

  int l = 0;

  union {
    float value;
    uint32_t raw;
  } conv = { .value = value };

  const uint32_t raw_v = conv.raw;
  const uint32_t raw_absv = raw_v & UINT32_C(0x7FFFFFFF);
  const float absv = value < 0? -value : value;

  if (raw_absv > UINT32_C(0x7F800000)) {
    // NaN
    print_str(buffer, len, &l, "[NaN]");

  } else if (raw_absv == UINT32_C(0x7F800000)) {
    // Infinity
    if (value > 0) {
      print_str(buffer, len, &l, "[+INF]");
    } else {
      print_str(buffer, len, &l, "[-INF]");
    }

  } else if (absv >= 1.f && absv < 10000000.f) {
    // Convert to 7.6 decimal fixed point and print
    print_fp_num(buffer, len, &l, static_cast<uint64_t>(absv * 1000000.f), value < 0, 6);

  } else if (absv > 0) {
    // Scientific notation

    // The powers of ten from 10^-45 to 10^38 rounded downward and cast to
    // binary32. Each stored value holds the property of being the next value
    // lower or equal to the associated power of ten.
    const uint32_t kRawBucketStart[84] = {
      0x00000000, 0x00000007, 0x00000047, 0x000002c9, 0x00001be0, 0x000116c2, 0x000ae397, 0x006ce3ee,
      0x02081cea, 0x03aa2424, 0x0554ad2d, 0x0704ec3c, 0x08a6274b, 0x0a4fb11e, 0x0c01ceb3, 0x0da2425f,
      0x0f4ad2f7, 0x10fd87b5, 0x129e74d1, 0x14461206, 0x15f79687, 0x179abe14, 0x19416d9a, 0x1af1c900,
      0x1c971da0, 0x1e3ce508, 0x1fec1e4a, 0x219392ee, 0x233877aa, 0x24e69594, 0x26901d7c, 0x283424dc,
      0x29e12e13, 0x2b8cbccc, 0x2d2febff, 0x2edbe6fe, 0x3089705f, 0x322bcc77, 0x33d6bf94, 0x358637bd,
      0x3727c5ac, 0x38d1b717, 0x3a83126e, 0x3c23d70a, 0x3dcccccc, 0x3f7fffff, 0x411fffff, 0x42c7ffff,
      0x4479ffff, 0x461c3fff, 0x47c34fff, 0x497423ff, 0x4b18967f, 0x4cbebc1f, 0x4e6e6b27, 0x501502f8,
      0x51ba43b7, 0x5368d4a5, 0x551184e7, 0x56b5e620, 0x58635fa9, 0x5a0e1bc9, 0x5bb1a2bc, 0x5d5e0b6b,
      0x5f0ac723, 0x60ad78eb, 0x6258d726, 0x64078678, 0x65a96816, 0x6753c21b, 0x69045951, 0x6aa56fa5,
      0x6c4ecb8f, 0x6e013f39, 0x6fa18f07, 0x7149f2c9, 0x72fc6f7c, 0x749dc5ad, 0x76453719, 0x77f684df,
      0x799a130b, 0x7b4097ce, 0x7cf0bdc2, 0x7e967699,
    };
    // The inverse powers of ten from 10^45 to 10^-38. The 32 values from each
    // edge are scaled up and down by 2^32 to keep them from becoming
    // denormalized or infinity. Since this is a power of 2, it will not affect
    // numerical accuracy.
    const uint32_t kRawBucketScale[84] = {
      0x7a335dbf, 0x788f7e32, 0x76e596b7, 0x7537abc6, 0x7392efd1, 0x71eb194f, 0x703c143f, 0x6e967699,
      0x6cf0bdc2, 0x6b4097cf, 0x699a130c, 0x67f684df, 0x66453719, 0x649dc5ae, 0x62fc6f7c, 0x6149f2ca,
      0x5fa18f08, 0x5e013f3a, 0x5c4ecb8f, 0x5aa56fa6, 0x59045952, 0x5753c21c, 0x55a96816, 0x54078678,
      0x5258d726, 0x50ad78ec, 0x4f0ac723, 0x4d5e0b6b, 0x4bb1a2bc, 0x4a0e1bca, 0x48635faa, 0x46b5e621,
      0x551184e7, 0x5368d4a5, 0x51ba43b7, 0x501502f9, 0x4e6e6b28, 0x4cbebc20, 0x4b189680, 0x49742400,
      0x47c35000, 0x461c4000, 0x447a0000, 0x42c80000, 0x41200000, 0x3f800000, 0x3dcccccd, 0x3c23d70b,
      0x3a83126f, 0x38d1b718, 0x3727c5ad, 0x358637be, 0x43d6bf95, 0x422bcc78, 0x40897060, 0x3edbe6ff,
      0x3d2febff, 0x3b8cbccc, 0x39e12e13, 0x383424dd, 0x36901d7d, 0x34e69595, 0x333877aa, 0x319392ef,
      0x2fec1e4a, 0x2e3ce509, 0x2c971da1, 0x2af1c900, 0x29416d9a, 0x279abe15, 0x25f79687, 0x24461206,
      0x229e74d2, 0x20fd87b5, 0x1f4ad2f8, 0x1da24260, 0x1c01ceb3, 0x1a4fb11f, 0x18a6274b, 0x1704ec3d,
      0x1554ad2e, 0x13aa2425, 0x12081cea, 0x1059c7dc,
    };
    const float *bucket_start = reinterpret_cast<const float*>(kRawBucketStart);
    const float *bucket_scale = reinterpret_cast<const float*>(kRawBucketScale);

    // Search and find the first smaller power of 10.
    int e;
    for(e = 38; e >= -45; e--) {
      if (bucket_start[e+45] < absv) {
        break;
      }
    }
    const int abs_e = e < 0 ? -e : e;

    // Prescale by 2^32 if the power of 10 is too large or small.
    float scaled_absv = absv;
    if (e < -45+32) {
      scaled_absv *= 4294967296.f; // exactly 2^32
    } else if (e >= 39-32) {
      scaled_absv *= 0.00000000023283064365386962890625; // exactly 2^-32
    }

    // Scale by the inverse power of 10. The scales by 2^32 will cancel out
    // and provide a value in the range of [1, 10).
    scaled_absv *= bucket_scale[e+45];

    // Print as a signed 1.6 decimal fixed-point value with signed exponent.
    print_fp_num(buffer, len, &l, static_cast<uint64_t>(scaled_absv * 1000000.f), value < 0, 6);
    print_str(buffer, len, &l, "e");
    print_fp_num(buffer, len, &l, abs_e, e < 0, 0);

  } else {
    // Exactly 0
    print_fp_num(buffer, len, &l, 0, false, 0);
  }

  // Add a null terminator, even if there isn't room.
  if (l < len) {
    buffer[l] = '\0';
  } else if (len > 0) {
    buffer[len-1] = '\0';
  }
  l++;

  // Return the number of characters needed for display.
  return l;
}

#else  // defined(LIBSPRINGBOK_NO_FLOAT_SUPPORT)

extern "C" int float_to_str(const int len, char *buffer, const float value) {
  // Dummy function since float support is disabled in libspringbok
  LOG_ERROR("float_to_str is disabled because libspringbok was compiled without float support");
  return 0;
}

#endif
