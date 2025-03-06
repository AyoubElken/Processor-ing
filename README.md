# Pipelined Processor - VHDL Implementation

This repository contains the VHDL implementation of a **16-bit pipelined processor** that was as an improvement to the 9 bit I did in school wich is designed for educational purposes. The processor supports a variety of instructions, including arithmetic, logical, memory access, and control flow operations. The design is pipelined to improve performance and includes basic hazard detection and handling mechanisms.

---

## Table of Contents
1. [Overview](#overview)
2. [Features](#features)
3. [Supported Instructions](#supported-instructions)
4. [Pipeline Stages](#pipeline-stages)
5. [Simulation and Testing](#simulation-and-testing)
6. [FPGA Implementation](#fpga-implementation)
7. [Future Work?](#future-work)
8. [License](#license)

---

## Overview

The processor is a **16-bit RISC-style architecture** with a **5-stage pipeline**:
1. **Fetch (IF)**: Fetches instructions from memory.
2. **Decode (ID)**: Decodes instructions and reads registers.
3. **Execute (EX)**: Performs arithmetic and logical operations.
4. **Memory (MEM)**: Handles memory access (load/store).
5. **Writeback (WB)**: Writes results back to registers.

The design includes:
- A **register file** with 8 general-purpose registers.
- An **ALU** supporting arithmetic, logical, and shift operations.
- Basic **hazard detection** for load-use stalls.
- Support for **branching** and **jumping**.

---

## Features

- **16-bit Data Path**: All registers, ALU operations, and memory accesses are 16 bits wide.
- **Pipelined Architecture**: Improves throughput by overlapping instruction execution.
- **Supported Operations**:
  - Arithmetic: ADD, SUB, MUL
  - Logical: AND, OR, XOR
  - Shifts: SHL (shift left), SHR (shift right)
  - Memory: LD (load), ST (store)
  - Control Flow: JMP (jump), BEQ (branch if equal), HALT
- **Hazard Handling**: Basic load-use stall detection.
- **Modular Design**: Components like ALU, register file, and pipeline stages are modular and reusable.

---

## Supported Instructions

The processor supports the following instructions, encoded in a 16-bit format:

| Instruction | Opcode | Description |
|-------------|--------|-------------|
| `MV Rx, Ry`   | `0000` | Move data from Ry to Rx |
| `MVI Rx, #D`  | `0001` | Load immediate value D into Rx |
| `ADD Rx, Ry`  | `0010` | Rx = Rx + Ry |
| `SUB Rx, Ry`  | `0011` | Rx = Rx - Ry |
| `MUL Rx, Ry`  | `0100` | Rx = Rx * Ry |
| `AND Rx, Ry`  | `0110` | Rx = Rx AND Ry |
| `OR Rx, Ry`   | `0111` | Rx = Rx OR Ry |
| `XOR Rx, Ry`  | `1000` | Rx = Rx XOR Ry |
| `SHL Rx, Ry`  | `1001` | Rx = Rx << Ry |
| `SHR Rx, Ry`  | `1010` | Rx = Rx >> Ry |
| `LD Rx, [Ry]` | `1011` | Load data from memory address Ry into Rx |
| `ST Rx, [Ry]` | `1100` | Store data from Rx into memory address Ry |
| `JMP #D`      | `1101` | Jump to address D |
| `BEQ Rx, Ry, #D` | `1110` | Branch to address D if Rx == Ry |
| `HALT`        | `1111` | Stop execution |

---

## Pipeline Stages

The processor is divided into five pipeline stages:

1. **Fetch (IF)**:
   - Fetches the instruction from memory using the program counter (PC).
   - Updates the PC for the next instruction.

2. **Decode (ID)**:
   - Decodes the instruction and reads source registers.
   - Sign-extends immediate values.

3. **Execute (EX)**:
   - Performs arithmetic, logical, or shift operations using the ALU.
   - Computes branch targets and evaluates branch conditions.

4. **Memory (MEM)**:
   - Handles memory access (load/store).
   - Passes ALU results to the next stage.

5. **Writeback (WB)**:
   - Writes results back to the destination register.
   - Updates the register file.

---

## Simulation and Testing

To simulate the processor:

1. Use a VHDL simulator (e.g., ModelSim, GHDL) to compile and run the code.
2. Write a testbench to provide input signals (`clock`, `reset_n`, `data_in`, `addr_in`) and observe the output (`data_out`, `addr_out`, `mem_read`, `mem_write`, `done`).
3. Verify the functionality of each instruction by checking the contents of registers and memory after execution.

Example testbench steps:
- Load an immediate value into a register using `MVI`.
- Perform arithmetic operations using `ADD` and `SUB`.
- Test memory access using `LD` and `ST`.
- Verify control flow using `JMP` and `BEQ`.

---

## FPGA Implementation

The processor can be implemented on an FPGA using the following steps:

1. **Synthesis**:
   - Use a synthesis tool (e.g., Quartus, Vivado) to synthesize the VHDL code.
   - Ensure the design meets timing constraints.

2. **Pin Assignment**:
   - Map the input/output ports to FPGA pins:
     - `clock`: Connect to a clock source (e.g., a button or external oscillator).
     - `reset_n`: Connect to a reset button.
     - `data_in`: Connect to switches for data input.
     - `addr_in`: Connect to switches for address input.
     - `data_out`: Connect to LEDs to display data.
     - `addr_out`: Connect to LEDs to display addresses.
     - `mem_read`/`mem_write`: Connect to LEDs to indicate memory operations.
     - `done`: Connect to an LED to indicate completion.

3. **Testing on FPGA**:
   - Load the synthesized design onto the FPGA.
   - Use switches and buttons to input instructions and data.
   - Observe the results on the LEDs.

---

## Future Work

- **Add Forwarding Unit**: Implement forwarding to handle data hazards without stalling.
- **Expand Instruction Set**: Add support for more operations (e.g., DIV, CMP).
- **Improve Branch Prediction**: Add a simple branch predictor to reduce pipeline stalls.
- **Add Interrupt Handling**: Implement interrupt support for real-time applications.
- **Optimize Performance**: Reduce critical path delays and improve clock speed.

---

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

Feel free to contribute to this project by opening issues or submitting pull requests. For any questions, please rarely contact.

Happy coding! 🚀
