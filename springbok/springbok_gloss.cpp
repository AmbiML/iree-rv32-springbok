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

#include <stdlib.h>
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdint.h>

#include <springbok_intrinsics.h>

void* __dso_handle = (void*) &__dso_handle;

extern "C" void *_sbrk(int nbytes) {
  extern char _sheap, _eheap;
  static char *_heap_ptr = &_sheap;

  if ((nbytes < 0) ||
      (_heap_ptr + nbytes > &_eheap)) {
    springbok_simprint(SPRINGBOK_SIMPRINT_ERROR, "_sbrk failed to allocate memory. Number of bytes requested:", nbytes);
    springbok_simprint(SPRINGBOK_SIMPRINT_ERROR, "Number of unallocated bytes remaining:", static_cast<int32_t>(&_eheap - _heap_ptr));
    errno = ENOMEM;
    return (void *)-1;
  }

  void *base = _heap_ptr;
  _heap_ptr += nbytes;
  return base;
}

extern "C" int _read(int file, char *ptr, int len) {
  if (file != STDIN_FILENO) {
    errno = EBADF;
    return -1;
  }

  return 0;
}

extern "C" int _write(int file, char *buf, int nbytes) {
  static int _write_line_buffer_len[2] = {0, 0};
  static char _write_line_buffer[2][256];

  if (file != STDOUT_FILENO && file != STDERR_FILENO) {
    errno = EBADF;
    return -1;
  }

  if (nbytes <= 0) {
    return 0;
  }

  if (buf == NULL) {
    errno = EFAULT;
    return -1;
  }

  const int buffer_num   = (file == STDOUT_FILENO)? 0 : 1;
  const int buffer_level = (file == STDOUT_FILENO)? SPRINGBOK_SIMPRINT_INFO : SPRINGBOK_SIMPRINT_ERROR;

  int bytes_read = 0;
  char c;
  do {
    int len = _write_line_buffer_len[buffer_num];
    c = *(buf++);
    bytes_read++;

    if ((c == '\n') || (c == '\0')) {
      _write_line_buffer[buffer_num][len] = '\0';
      springbok_simprint(buffer_level, _write_line_buffer[buffer_num], buffer_num);
      len = 0;
    } else {
      _write_line_buffer[buffer_num][len] = c;
      len++;

      if (len == 255) {
        _write_line_buffer[buffer_num][len] = '\0';
        springbok_simprint(buffer_level, _write_line_buffer[buffer_num], buffer_num);
        len = 0;
      }
    }

    _write_line_buffer_len[buffer_num] = len;
  } while (bytes_read < nbytes);

  return bytes_read;
}

extern "C" int _close(int file) {
  errno = EBADF;
  return -1;
}

extern "C" int _lseek(int file, int offset, int whence) {
  if (file != STDOUT_FILENO && file != STDERR_FILENO) {
    errno = EBADF;
    return -1;
  }

  return 0;
}

extern "C" int _fstat(int file, struct stat *st) {
  if (file != STDOUT_FILENO && file != STDERR_FILENO) {
    errno = EBADF;
    return -1;
  }

  if (st == NULL) {
    errno = EFAULT;
    return -1;
  }

  st->st_mode = S_IFCHR;
  return 0;
}

extern "C" int _isatty(int file) {
  if (file != STDOUT_FILENO && file != STDERR_FILENO) {
    errno = EBADF;
    return -1;
  }

  return 1;
}

void operator delete(void *p) noexcept {
  free(p);
}

extern "C" void operator delete(void *p, unsigned long c) noexcept {
  operator delete(p);
}
