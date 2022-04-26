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

ITCM_LENGTH  = DEFINED(__itcm_length__)  ? __itcm_length__  : 64K;
DTCM_LENGTH  = DEFINED(__dtcm_length__)  ? __dtcm_length__  : 4M;


MEMORY
{
        ITCM (rx) : ORIGIN = 0x32000000, LENGTH = ITCM_LENGTH
        DTCM (rw) : ORIGIN = 0x34000000, LENGTH = DTCM_LENGTH
}

STACK_SIZE = DEFINED(STACK_SIZE) ? STACK_SIZE : DEFINED(__stack_size__) ? __stack_size__ : 0x2000;
PROVIDE( _stack_ptr = ORIGIN(DTCM) + LENGTH(DTCM) - 64 );
PROVIDE( _stack_start_sentinel = ORIGIN(DTCM) + LENGTH(DTCM) - STACK_SIZE );
PROVIDE( _stack_end_sentinel = ORIGIN(DTCM) + LENGTH(DTCM) - 64 );

ENTRY(_start)

SECTIONS
{
        .text :
        {
                _stext = .;
                KEEP(*(.text._start))
                *(.text*)
                _etext = .;
        } > ITCM

        .rodata :
        {
                . = ALIGN(64);
                _srodata = .;
                *(.rodata*)
                _erodata = .;
        } > DTCM

        .preinit_array :
        {
                PROVIDE(__preinit_array_start = .);
                KEEP(*(.preinit_array))
                PROVIDE(__preinit_array_end = .);
        } > DTCM

        .init_array :
        {
                PROVIDE(__init_array_start = .);
                KEEP(*(SORT(.init_array.*)))
                KEEP(*(.init_array))
                PROVIDE(__init_array_end = .);
        } > DTCM

        .fini_array :
        {
                PROVIDE(__fini_array_start = .);
                KEEP(*(SORT(.fini_array.*)))
                KEEP(*(.fini_array))
                PROVIDE(__fini_array_end = .);
        } > DTCM

        .data :
        {
                . = ALIGN(64);
                _global_pointer = . + 0x800;
                _sdata = .;
                *(.data*)
                _edata = .;
        } > DTCM

        .bss (NOLOAD) :
        {
                . = ALIGN(64);
                _sbss = .;
                *(.bss*)
                *(COMMON)
                _ebss = .;
        } > DTCM

        .heap (NOLOAD) :
        {
                . = ALIGN(64);
                _sheap = .;
                . = ORIGIN(DTCM) + LENGTH(DTCM) - STACK_SIZE - 63;
                . = ALIGN(64);
                _eheap = .;
        } > DTCM

        .stack ORIGIN(DTCM) + LENGTH(DTCM) - STACK_SIZE (NOLOAD) :
        {
                _sstack = .;
                . = . + STACK_SIZE;
                . = ALIGN(64);
                _estack = .;
        } > DTCM

        _end = .;
}
