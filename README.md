# RISC-V 32-Bit Bare-Metal ML Deployment on Springbok via IREE

This project demonstrates how to compile RISC-V 32-bit ML workloads via
[IREE](https://github.com/google/iree), and deploy the workloads with IREE's c
API to generate the bare-matal executables. The built artifacts are targeted for
Springbok, a RISC-V 32-bit bare-metal platform, and can be simulated with
[Renode](https://github.com/renode/renode).

## Prerequisites

First install the system packages:

```bash
sudo apt install xxd cmake ninja-build
pip install lit wget
```

To get you going we have pre-compiled an RV32 LLVM toolchain. This can be installed using:

```bash
./build_tools/install_toolchain.sh
```

The IREE compiler can be downloaded using:

```bash
./build_tools/download_iree_compiler.py
```

Finally Renode can be downloaded using:

```bash
./build_tools/download_renode.py
```

Make sure your `${HOME}/.local/bin` is in your PATH:

```bash
export PATH=${HOME}/.local/bin:${PATH}
```

## Code structure

* build_tools: Utility scripts for the project
* cmake: CMake Macros for the project
* samples: Codegen and execution of ML models based on IREE
  * device: Device HAL driver library
  * float_model: float model examples
  * quant_model: quantized model examples
  * simple_vec_mul: Point-wise vector multiplication examples
  * util: Runtime utility library for model execution
* sim/config: Renode configuration and infrastructure
* springbok: Low-level code and linker scripts for the Springbok machine
* third_party/iree: IREE codebase

## Build the project

All sample models we've included can be built at once using this command:

```bash
./build_tools/build_riscv.sh
```

Elfs will land in `build/build-riscv/samples/<sample_folder>/` and come in two flavors: `<model_name>_bytecode_static` and `<model_name>_emitc_static`. The bytecode executable uses the IREE VM, while the emitc executable compiles the VM commands into C.

## Run the executables

To run a simulation, run `./build_tools/sim_springbok.sh` with a path to a compiled executable. For example, to run MobileNet v1:

```bash
./build_tools/sim_springbok.sh build/build-riscv/samples/quant_model/mobilenet_v1_emitc_static
```

## Test the executables

This project utilizes LLVM `lit` and `FileCheck` to test the ML
executable performance. The tests are defined in the *_test.txt files under
`samples`. To run the tests:

```bash
lit --path $(realpath build/iree_compiler/tests/bin) -a samples
```

Test times can be found at `build/springbok_iree/tests/.lit_test_times.txt`.
