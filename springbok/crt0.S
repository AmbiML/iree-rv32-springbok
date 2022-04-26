# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

        .section .text._start
        .align 2
        .globl _start
_start:
        ###############################################
        # Put all scalar registers into a known state #
        ###############################################
        la   sp, _stack_ptr
        la   gp, _global_pointer
        mv   tp, zero
        mv   t1, zero
        mv   t2, zero
        mv   s0, zero
        mv   s1, zero
        mv   a1, zero
        mv   a2, zero
        mv   a3, zero
        mv   a4, zero
        mv   a5, zero
        mv   a6, zero
        mv   a7, zero
        mv   s2, zero
        mv   s3, zero
        mv   s4, zero
        mv   s5, zero
        mv   s6, zero
        mv   s7, zero
        mv   s8, zero
        mv   s9, zero
        mv   s10, zero
        mv   s11, zero
        mv   t3, zero
        mv   t4, zero
        mv   t5, zero
        mv   t6, zero

#ifndef LIBSPRINGBOK_NO_VECTOR_SUPPORT
        ###############################################
        # Put all vector registers into a known state #
        ###############################################
        # Set vector extension to "initial"
        csrr a0, mstatus
        ori a0, a0, 0x600
        addi a0, a0, -0x200
        csrw mstatus, a0

        # Set lmul=8 and clear the register file
        vsetvli t0, zero, e8, m8, tu, mu
        vmv.v.i v0, 0
        vmv.v.i v8, 0
        vmv.v.i v16, 0
        vmv.v.i v24, 0

        # Set lmul=1
        vsetvli t0, zero, e8, m1, tu, mu

        # Set vector extension to "clean"
        xori a0, a0, 0x600
        csrw mstatus, a0
#endif

#ifndef LIBSPRINGBOK_NO_FLOAT_SUPPORT
        ###############################################################
        # Reset all other CSRs, and perform any other processor setup #
        ###############################################################
        # Enable floating point unit
        csrr a0, mstatus
        li a1, 0x2000
        or a0, a0, a1
        csrw mstatus, a0
#endif

#ifndef LIBSPRINGBOK_NO_EXCEPTION_SUPPORT
        la a0, exception_handler
        csrw mtvec, a0
#endif

        #############################################################
        # Set up stack sentinels                                    #
        #############################################################
        jal  ra, _setup_stack_sentinels

        ##########################
        # Register fini handlers #
        ##########################
        la   a0, __libc_fini_array
        call atexit

        ##################################
        # Perform C initialization calls #
        ##################################
        call __libc_init_array

        #############
        # Call main #
        #############
        li   a0, 0 #argv
        li   a1, 0 #argc
        li   a2, 0 #envp
        la   ra, main
        jalr ra, ra
        # Save main's return value into s0
        mv   s0, a0

        ######################
        # Call C destructors #
        ######################
        li   a1, 0
        call __call_exitprocs

        # Don't clear the stack if the program returned from main
        j    1f

_exit:
        # Save _exit's return value
        mv   s0, a0

        # Clear the stack
        la   sp, _stack_ptr
1:
        ##########################################################################
        # Verify stack sentinels are unchanged and that sp is where we expect it #
        ##########################################################################
        # Check the stack, and fix it if it's broken
        jal  ra, _check_stack

        # Was the stack corrupted?
        beq  a0, zero, 1f

        # The stack was corrupted!
        # These strings are stored in instruction memory like
        # this so they can't ever be corrupted.
        li   t0, 0x63617473 # "stac"
        li   t1, 0x6f63206b # "k co"
        li   t2, 0x70757272 # "rrup"
        li   t3, 0x00646574 # "ted\0"
        addi sp, sp, -16
        sw   t0, 0(sp)
        sw   t1, 4(sp)
        sw   t2, 8(sp)
        sw   t3, 12(sp)
        li   t4, 0 # ERROR logging level
        .word 0x00A10EFB # simprint t4, sp, a0 (encoded as custom3<func3=0>)
        addi sp, sp, 16
1:

        # Restore the application's return value
        mv   a0, s0

        # Print main's return value
        # These strings are stored in instruction memory like
        # this so they can't ever be corrupted.
        li   t0, 0x6e69616d # "main"
        li   t1, 0x74657220 # " ret"
        li   t2, 0x656e7275 # "urne"
        li   t3, 0x00203a64 # "d: \0"
        addi sp, sp, -16
        sw   t0, 0(sp)
        sw   t1, 4(sp)
        sw   t2, 8(sp)
        sw   t3, 12(sp)
        li   t4, 2 # INFO logging level
        .word 0x00A10EFB # simprint t4, sp, a0 (encoded as custom3<func3=0>)
        addi sp, sp, 16

_finish:
#ifndef LIBSPRINGBOK_NO_EXCEPTION_SUPPORT
        # Store the application's return value and machine exception program
        # counter onto the stack
        addi sp, sp, -8
        sw   a0, 0(sp)
        csrr t0, mepc
        sw   t0, 4(sp)
#else
        # Store the application's return value onto the stack
        addi sp, sp, -4
        sw   a0, 0(sp)
#endif
1:
        .word 0x0000307B # finish (encoded as custom3<func3=3>)
        j    1b

_setup_stack_sentinels:
        #######################################
        # Write our stack sentinels to memory #
        #######################################
        la   a0, _stack_start_sentinel
        li   a1, 0xCAFEF00D
        sw   a1, 0(a0)
        sw   a1, 4(a0)
        sw   a1, 8(a0)
        sw   a1, 12(a0)
        sw   a1, 16(a0)
        sw   a1, 20(a0)
        sw   a1, 24(a0)
        sw   a1, 28(a0)
        sw   a1, 32(a0)
        sw   a1, 36(a0)
        sw   a1, 40(a0)
        sw   a1, 44(a0)
        sw   a1, 48(a0)
        sw   a1, 52(a0)
        sw   a1, 56(a0)
        sw   a1, 60(a0)

        la   a0, _stack_end_sentinel
        li   a1, 0xDECAFBAD
        sw   a1, 0(a0)
        sw   a1, 4(a0)
        sw   a1, 8(a0)
        sw   a1, 12(a0)
        sw   a1, 16(a0)
        sw   a1, 20(a0)
        sw   a1, 24(a0)
        sw   a1, 28(a0)
        sw   a1, 32(a0)
        sw   a1, 36(a0)
        sw   a1, 40(a0)
        sw   a1, 44(a0)
        sw   a1, 48(a0)
        sw   a1, 52(a0)
        sw   a1, 56(a0)
        sw   a1, 60(a0)
        ret

_check_stack:
        ########################################################################
        # Check that our stack sentinels are there and that the stack is empty #
        ########################################################################
        # repair the stack pointer if it's broken
        mv   a0, sp
        la   sp, _stack_ptr
        bne  a0, sp, 2f

        la   a0, _stack_start_sentinel
        addi a1, a0, 64
        li   a2, 0xCAFEF00D
1:
        lw   a3, 0(a0)
        bne  a2, a3, 2f
        addi a0, a0, 4
        bne  a0, a1, 1b

        la   a0, _stack_end_sentinel
        addi a1, a0, 64
        li   a2, 0xDECAFBAD
1:
        lw   a3, 0(a0)
        bne  a2, a3, 2f
        addi a0, a0, 4
        bne  a0, a1, 1b
        # stack is fine
        mv   a0, zero
        ret
        # stack corruption!
2:      li   a0, 1
        ret

#ifndef LIBSPRINGBOK_NO_EXCEPTION_SUPPORT
.weak exception_handler
exception_handler:
        # Exception occurred
        # These strings are stored in instruction memory like
        # this so they can't ever be corrupted.
        li   t0, 0x65637845 # "Exce"
        li   t1, 0x6f697470 # "ptio"
        li   t2, 0x636f206e # "n oc"
        li   t3, 0x72727563 # "curr"
        li   t4, 0x00006465 # "ed\0\0"
        addi sp, sp, -20
        sw   t0, 0(sp)
        sw   t1, 4(sp)
        sw   t2, 8(sp)
        sw   t3, 12(sp)
        sw   t4, 16(sp)
        csrr a0, mcause
        li   t6, 0 # ERROR logging level
        .word 0x00A10FFB # simprint t6, sp, a0 (encoded as custom3<func3=0>)
        addi sp, sp, 20
        # Store mcause as the reture value
        mv   s0, a0
        call print_csrs
        # Restore the return value to be used in _finish
        mv   a0, s0
        # Clear the stack
        la   sp, _stack_ptr
        j _finish

.weak print_csrs
print_csrs:
        mret
#endif
