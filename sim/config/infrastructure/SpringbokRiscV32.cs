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

using System;
using System.Linq;
using System.Text;

using Antmicro.Renode.Core;
using Antmicro.Renode.Core.Structure.Registers;
using Antmicro.Renode.Logging;
using Antmicro.Renode.Peripherals.Bus;
using Antmicro.Renode.Peripherals.Memory;
using Antmicro.Renode.Peripherals.Timers;
using Antmicro.Renode.Utilities;
using Antmicro.Renode.Utilities.Binding;

using Endianess = ELFSharp.ELF.Endianess;

namespace Antmicro.Renode.Peripherals.CPU
{
    public class SpringbokRiscV32 : RiscV32
    {
        public SpringbokRiscV32(Core.Machine machine,
                                uint hartId = 0,
                                PrivilegeArchitecture privilegeArchitecture = PrivilegeArchitecture.Priv1_11,
                                Endianess endianness = Endianess.LittleEndian,
                                string cpuType = "rv32imfv")
            : base(null, cpuType, machine, hartId, privilegeArchitecture, endianness)
        {
            RegisterCustomCSRs();

            //               funct7            -------
            //               rs2                      -----
            //               rs1                           -----
            //               funct3                             ---
            //               rd                                    -----
            InstallCustomInstruction(pattern: "-------------------------1111011", handler: HandleSpringbokCustom3); // custom-3

            Reset();
            // Placing these before reset results in them being reset (this is not intended behavior)
            // These should be moved withing Tlib out of the reset function.
            VectorRegisterLength = 512;
            VectorElementMaxWidth = 32;
        }

        public override void Reset()
        {
            base.Reset();

            // This core comes out of reset paused.
            this.IsHalted = true;

            if(ControlBlockRegistered)
            {
                ControlBlock.Reset();
            }
        }

        public void RegisterControlBlock(SpringbokRiscV32_ControlBlock controlBlock)
        {
            ControlBlock = controlBlock;
            ControlBlockRegistered = true;
        }

        private SpringbokRiscV32_ControlBlock ControlBlock;
        private bool ControlBlockRegistered = false;

        private void HandleSpringbokCustom3(UInt64 opcode)
        {
            int rd = (int)BitHelper.GetValue(opcode, 7, 5);
            int funct3 = (int)BitHelper.GetValue(opcode, 12, 3);
            int rs1 = (int)BitHelper.GetValue(opcode, 15, 5);
            int rs2 = (int)BitHelper.GetValue(opcode, 20, 5);

            switch(funct3)
            {
                case 0:
                    // simprint
                    // rd is logging level
                    // rs1 is pointer to null-terminated string to print
                    // rs2 is number to print
                    int levelNum = (int)(X[rd].RawValue);
                    LogLevel level = LogLevel.Error;

                    switch(levelNum)
                    {
                        case 0:
                            level = LogLevel.Error;
                            break;
                        case 1:
                            level = LogLevel.Warning;
                            break;
                        case 2:
                            level = LogLevel.Info;
                            break;
                        case 3:
                            level = LogLevel.Debug;
                            break;
                        case 4:
                            level = LogLevel.Noisy;
                            break;
                        default:
                            this.Log(LogLevel.Error, "Unrecognized logging level for simprint instruction! {0}: {1}", rd, levelNum);
                            return;
                    }

                    uint messagePtr = (uint)(X[rs1].RawValue);
                    uint number = (uint)(X[rs2].RawValue);

                    byte[] messageArray = new byte[256];

                    for(int i = 0; i < 255; i++)
                    {
                        messageArray[i] = (byte)(ReadByteFromBus(messagePtr++) & 127); // Just in case we read garbage, let's restrict it to ASCII garbage.
                        if(messageArray[i] == 0)
                        {
                            break;
                        }
                    }

                    String message = Encoding.ASCII.GetString(messageArray).TrimEnd((Char)0);

                    this.Log(level, "simprint: \"{0}\", {1} (0x{1:X})", message, number);

                    break;
                case 1:
                    // xcount
                    switch(rs1)
                    {
                        case 0:
                            // icount
                            X[rd] = ExecutedInstructions;
                            break;
                        case 1:
                            // ccount
                            // Renode simulates one cycle per instruction
                            X[rd] = ExecutedInstructions;
                            break;
                        default:
                            this.Log(LogLevel.Error, "xcount: unrecognized source: {0} (0x{0:X})", rs1);
                            break;
                    }
                    break;
                case 2:
                    // hostreq
                    if(ControlBlockRegistered)
                    {
                        ControlBlock.ExecHostReq();
                    }
                    break;
                case 3:
                    // finish
                    if(ControlBlockRegistered)
                    {
                        ControlBlock.ExecFinish();
                    }
                    break;
                default:
                    // Unrecognized
                    this.Log(LogLevel.Error, "custom-3: unrecognized funct3: {0} (0x{0:X})", funct3);
                    break;
            }
        }

        private void RegisterCustomCSRs()
        {
            // validate only privilege level when accessing CSRs
            // do not validate rw bit as VexRiscv custom CSRs do not follow the standard
            CSRValidation = CSRValidationLevel.None;

            RegisterCSR((ulong)CSRs.InstructionCount, () => InstructionCountCSRRead("InstructionCount"), value => { });
            RegisterCSR((ulong)CSRs.CycleCount, () => InstructionCountCSRRead("CycleCount"), value => { });
        }

        private ulong InstructionCountCSRRead(string name)
        {
            this.Log(LogLevel.Noisy, "Reading instruction count CSR {0} 0x{1:X}", name, ExecutedInstructions);
            ulong count = ExecutedInstructions;
            return count;
        }

        private enum CSRs
        {
            InstructionCount = 0x7C0,
            CycleCount = 0x7C1,
        }
    }

    public class SpringbokRiscV32_ControlBlock :
        IDoubleWordPeripheral,
        IProvidesRegisterCollection<DoubleWordRegisterCollection>,
        IKnownSize
    {

        public SpringbokRiscV32_ControlBlock(Machine machine,
                                             SpringbokRiscV32 core,
                                             MappedMemory imem,
                                             MappedMemory dmem)
        {
            Machine = machine;
            Core = core;
            IMem = imem;
            DMem = dmem;

            HostReqIRQ = new GPIO();
            FinishIRQ = new GPIO();
            InstructionFaultIRQ = new GPIO();
            DataFaultIRQ = new GPIO();

            Core.RegisterControlBlock(this);

            RegistersCollection = new DoubleWordRegisterCollection(this);
            DefineRegisters();

            Reset();
        }

        public void Reset()
        {
            mode = Mode.Freeze | Mode.SwReset;
            RegistersCollection.Reset();
        }

        private void DefineRegisters()
        {
            Registers.IntrState.Define32(this)
              .WithValueField(0, 4,
                              writeCallback: (_, value) => {
                                this.Log(LogLevel.Noisy, "Got {0} to clear IRQ pending bits", value);
                                irqsPending = irqsPending & ~(InterruptBits)value;
                                IrqUpdate();
                              },
                              valueProviderCallback: (_) => {
                                return (uint)irqsPending;
                              })
            ;

            Registers.IntrEnable.Define32(this)
              .WithValueField(0, 4,
                              writeCallback: (_, value) => {
                                this.Log(LogLevel.Noisy, "Got {0} to write IRQ enable bits", value);
                                irqsEnabled = (InterruptBits)value & InterruptBits.Mask;
                                IrqUpdate();
                              },
                              valueProviderCallback: (_) => {
                                return (uint)irqsEnabled;
                              })
            ;

            Registers.IntrTest.Define32(this)
              .WithValueField(0, 4,
                              writeCallback: (_, value) => {
                                this.Log(LogLevel.Noisy, "Got {0} to set IRQ pending bits", value);
                                irqsPending = irqsPending | ((InterruptBits)value & InterruptBits.Mask);
                                IrqUpdate();
                              })
              ;

            Registers.Control.Define32(this, resetValue: 0x00000003)
                    .WithValueField(0, 19, name: "FREEZE_VC_RESET_PC_START", writeCallback: (_, val) =>
                    {
                        Mode newMode = (Mode)val & Mode.Mask;

                        // Pause the core when either freeze or swreset is asserted.
                        if ((mode == Mode.Run) && (newMode != Mode.Run))
                        {
                            this.Log(LogLevel.Noisy, "Pausing core.");
                            Core.IsHalted = true;
                        }

                        // Trigger the core's reset when SwReset is deasserted.
                        if (((mode & Mode.SwReset) != 0) && ((newMode & Mode.SwReset) == 0))
                        {
                            this.Log(LogLevel.Noisy, "Resetting core.");
                            Core.Reset();
                            ulong startAddress = (val & ~(ulong)Mode.Mask) + Machine.SystemBus.GetRegistrationPoints(IMem, Core).First().Range.StartAddress;
                            this.Log(LogLevel.Noisy, "Setting PC to 0x{0:X}.", startAddress);
                            Core.PC = startAddress;
                        }

                        // Unpause the core when both freeze and SwReset are deasserted.
                        if ((mode != Mode.Run) && (newMode == Mode.Run))
                        {
                            this.Log(LogLevel.Noisy, "Resuming core.");
                            Core.IsHalted = false;

                            Core.Resume();
                        }

                        this.mode = newMode;
                    })
                    .WithIgnoredBits(19, 32 - 19);

            // To-do: Not sure how to implement disablable memory banks.
            Registers.MemoryBankControl.Define32(this)
                    .WithValueField(0, 4, out InstructionMemoryEnable, name: "I_MEM_ENABLE")
                    .WithValueField(4, 8, out DataMemoryEnable, name: "D_MEM_ENABLE")
                    .WithIgnoredBits(12, 32 - 12);

            // To-do: Not sure how to implement memory access range checks.
            Registers.ErrorStatus.Define32(this)
                    .WithFlag(0, name: "I_MEM_OUT_OF_RANGE")
                    .WithFlag(1, name: "D_MEM_OUT_OF_RANGE")
                    .WithValueField(2, 4, out InstructionMemoryDisableAccess, name: "I_MEM_DISABLE_ACCESS")
                    .WithValueField(6, 8, out DataMemoryDisableAccess, name: "D_MEM_DISABLE_ACCESS")
                    .WithIgnoredBits(14, 32 - 14);

            Registers.InitStart.Define32(this)
                    .WithValueField(0, 22, out InitStartAddress, name: "ADDRESS")
                    .WithFlag(22, out InitMemSelect, name: "IMEM_DMEM_SEL")
                    .WithIgnoredBits(23, 32 - 23);

            Registers.InitEnd.Define32(this)
                    .WithValueField(0, 22, out InitEndAddress, name: "ADDRESS")
                    .WithFlag(22, name: "VALID", mode: FieldMode.Read | FieldMode.Write, writeCallback: (_, val) =>
                    {
                  // If valid, do the memory clear.
                  if (val)
                        {
                            InitStatusPending.Value = true;
                            InitStatusDone.Value = false;
                            Machine.LocalTimeSource.ExecuteInNearestSyncedState( __ => {
                                if (InitMemSelect.Value)
                                {
                                    var instructionPageMask = ~((ulong)(InstructionPageSize - 1));
                                    for(ulong writeAddress = InitStartAddress.Value & instructionPageMask;
                                        writeAddress < ((InitEndAddress.Value + InstructionPageSize - 1) & instructionPageMask);
                                        writeAddress += InstructionPageSize)
                                    {
                                        IMem.WriteBytes((long)writeAddress, InstructionErasePattern, 0, InstructionPageSize);
                                    }
                                }
                                else
                                {
                                    var dataPageMask = ~((ulong)(DataPageSize - 1));
                                    for(ulong writeAddress = InitStartAddress.Value & dataPageMask;
                                        writeAddress < ((InitEndAddress.Value + DataPageSize - 1) & dataPageMask);
                                        writeAddress += DataPageSize)
                                    {
                                        DMem.WriteBytes((long)writeAddress, DataErasePattern, 0, DataPageSize);
                                    }
                                }
                                InitStatusPending.Value = false;
                                InitStatusDone.Value = true;
                            } );
                        }
                    })
                    .WithIgnoredBits(23, 32 - 23);
            Registers.InitStatus.Define32(this)
                    .WithFlag(0, out InitStatusPending, name: "INIT_PENDING")
                    .WithFlag(1, out InitStatusDone, name: "INIT_DONE")
                    .WithIgnoredBits(2, 32 - 2);
        }

        public virtual uint ReadDoubleWord(long offset)
        {
            return RegistersCollection.Read(offset);

        }

        public virtual void WriteDoubleWord(long offset, uint value)
        {
            RegistersCollection.Write(offset, value);
        }

        public void ExecHostReq()
        {
            // Pause the core and trigger a host interrupt signaling a request
            if (mode == Mode.Run)
            {
                this.Log(LogLevel.Noisy, "Pausing core for host request.");
            }
            else
            {
                this.Log(LogLevel.Error, "Pausing core for host request, but core was not expected to be running. Did you clear IsHalted manually?");
            }
            Core.IsHalted = true;
            mode = Mode.Freeze;
            irqsPending |= InterruptBits.HostReq;
            IrqUpdate();
        }

        public void ExecFinish()
        {
            // Pause, reset the core (actual reset occurs when SwReset is cleared) and trigger a host interrupt indicating completion
            if (mode == Mode.Run)
            {
                this.Log(LogLevel.Noisy, "Pausing and resetting core for host completion notification.");
            }
            else
            {
                this.Log(LogLevel.Error, "Pausing and resetting core for host completion notification, but core was not expected to be running. Did you clear IsHalted manually?");
            }
            Core.IsHalted = true;
            mode = Mode.Freeze | Mode.SwReset;
            irqsPending |= InterruptBits.Finish;
            IrqUpdate();
        }

        private void ExecFault(FaultType faultType)
        {
            // Pause, reset the core (actual reset occurs when SwReset is cleared) and trigger a host interrupt indicating a fault
            if (mode == Mode.Run)
            {
                this.Log(LogLevel.Noisy, "Pausing and resetting core for fault notification.");
            }
            else
            {
                this.Log(LogLevel.Error, "Pausing and resetting core for fault notification, but core was not expected to be running. Did you clear IsHalted manually?");
            }
            Core.IsHalted = true;
            mode = Mode.Freeze | Mode.SwReset;
            switch (faultType)
            {
            case FaultType.InstructionFetch:
                irqsPending |= InterruptBits.InstructionFault;
                IrqUpdate();
                return;
            case FaultType.DataAccess:
                irqsPending |= InterruptBits.DataFault;
                IrqUpdate();
                return;
            default:
                this.Log(LogLevel.Error, "Unknown fault type!");
                return;
            }
        }

        public DoubleWordRegisterCollection RegistersCollection { get; private set; }

        public GPIO HostReqIRQ { get; }
        public GPIO FinishIRQ { get; }
        public GPIO InstructionFaultIRQ { get; }
        public GPIO DataFaultIRQ { get; }

        private InterruptBits irqsEnabled;
        private InterruptBits irqsPending;

        private void IrqUpdate()
        {
          InterruptBits irqsPassed = irqsEnabled & irqsPending;
          HostReqIRQ.Set((irqsPassed & InterruptBits.HostReq) != 0);
          FinishIRQ.Set((irqsPassed & InterruptBits.Finish) != 0);
          InstructionFaultIRQ.Set((irqsPassed & InterruptBits.InstructionFault) != 0);
          DataFaultIRQ.Set((irqsPassed & InterruptBits.DataFault) != 0);
        }

        // To-do: Set the erase pattern to what the hardware actually does. 0x5A is
        // only for debugging purposes.
        private const int InstructionPageSize = 4;
        private readonly byte[] InstructionErasePattern = (byte[])Enumerable.Repeat((byte)0x5A, InstructionPageSize).ToArray();
        private const int DataPageSize = 64;
        private readonly byte[] DataErasePattern = (byte[])Enumerable.Repeat((byte)0x5A, DataPageSize).ToArray();

        // Disable unused variable warnings. These warnings will go away on their
        // their own when each register's behavior is implemented.
#pragma warning disable 414
        private IValueRegisterField InstructionMemoryEnable;
        private IValueRegisterField DataMemoryEnable;
        private IValueRegisterField InstructionMemoryDisableAccess;
        private IValueRegisterField DataMemoryDisableAccess;
        private IValueRegisterField InitStartAddress;
        private IFlagRegisterField InitMemSelect;
        private IValueRegisterField InitEndAddress;
        private IFlagRegisterField InitStatusPending;
        private IFlagRegisterField InitStatusDone;
#pragma warning restore 414

        private Mode mode;
        private readonly Machine Machine;
        private readonly SpringbokRiscV32 Core;
        private readonly MappedMemory IMem;
        private readonly MappedMemory DMem;

        // Length of register space.
        public long Size => 0x400;
        private enum Registers
        {
            IntrState = 0x00,
            IntrEnable = 0x04,
            IntrTest = 0x08,
            Control = 0x0C,
            MemoryBankControl = 0x10,
            ErrorStatus = 0x14,
            InitStart = 0x18,
            InitEnd = 0x1C,
            InitStatus = 0x20,
        };
        [Flags]
        private enum Mode
        {
            Run = 0x00,
            Freeze = 0x01,
            SwReset = 0x02,
            Mask = 0x03,
        };
        private enum FaultType
        {
            InstructionFetch,
            DataAccess,
        };
        [Flags]
        private enum InterruptBits
        {
            HostReq = 1,
            Finish = 2,
            InstructionFault = 4,
            DataFault = 8,
            Mask = 15,
        };
    }

}
