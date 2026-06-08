# Real-Time FPGA Implementation of a Bit-Flipping LDPC Decoder

### Reliable Error Correction for Modern Digital Communication Systems

From noisy channels to error-free transmission — implementing Low-Density Parity-Check (LDPC) decoding on FPGA using Verilog HDL, MATLAB, and Xilinx Vivado.

---

## Overview

Modern communication systems such as 5G networks, satellite communication, Wi-Fi, and deep-space communication rely heavily on powerful error correction techniques to ensure reliable data transmission.

This project presents the design and implementation of a real-time Bit-Flipping LDPC Decoder on a Xilinx Basys-3 FPGA. The decoder performs iterative error correction using syndrome computation and bit-flipping logic, enabling accurate recovery of corrupted data transmitted through noisy channels.

The project combines communication theory, hardware design, FPGA implementation, and real-time validation into a complete end-to-end system.

---

## Project Information

| Item                    | Details                                            |
| ----------------------- | -------------------------------------------------- |
| Project Title           | FPGA Implementation of a Bit-Flipping LDPC Decoder |
| Platform                | Xilinx Basys-3 FPGA (Artix-7)                      |
| Design Language         | Verilog HDL                                        |
| Simulation Tools        | MATLAB, Xilinx Vivado                              |
| Communication Interface | UART                                               |
| Decoding Algorithm      | Hard-Decision Bit-Flipping                         |
| Academic Year           | 2025–2026                                          |

---

## The Problem

In practical communication systems, transmitted data is often corrupted due to:

* Thermal noise
* Channel interference
* Signal attenuation
* Wireless fading effects

Without error correction, communication reliability decreases significantly.

Traditional soft-decision LDPC decoders provide excellent performance but require complex arithmetic operations and large hardware resources.

The challenge was to develop a hardware-efficient LDPC decoder that could perform real-time error correction with reduced computational complexity.

---

## The Solution

A hard-decision Bit-Flipping LDPC decoder was designed and implemented on FPGA.

The system:

✓ Receives encoded data through UART

✓ Detects errors using syndrome computation

✓ Performs iterative bit-flipping correction

✓ Validates parity constraints

✓ Returns corrected codewords to the user

✓ Operates in real-time on FPGA hardware

---

## System Architecture



### Data Flow

PC
↓
UART Receiver
↓
Codeword Loader
↓
Syndrome Computation Unit
↓
Bit-Flipping Decoder
↓
FSM Controller
↓
UART Transmitter
↓
PC Output

---

## Core Modules

### UART Receiver

Receives serial data from the PC and converts it into parallel data for processing.

### Codeword Loader

Stores and organizes incoming LDPC codewords for decoding.

### Syndrome Computation Unit

Computes parity-check violations using the LDPC parity-check matrix.

### Bit-Flipping Unit

Identifies unreliable bits and performs iterative correction.

### Finite State Machine (FSM)

Controls decoding stages, iterations, and synchronization between modules.

### UART Transmitter

Transmits corrected codewords back to the PC.

---

## Design Methodology

### MATLAB Verification

The LDPC decoder was first developed and tested in MATLAB.

The simulation included:

* LDPC Encoding
* BPSK Modulation
* AWGN Channel
* Hard Decision Demodulation
* Bit-Flipping Decoding
* BER Analysis

### Hardware Development

The design was then translated into Verilog HDL and implemented on FPGA.

Key development stages included:

* RTL Design
* Testbench Development
* Functional Simulation
* Synthesis
* Implementation
* Bitstream Generation
* FPGA Validation

---

## Performance Results

### BER Performance

[Insert BER Graph]

The Bit Error Rate decreases significantly as the signal-to-noise ratio increases, validating the effectiveness of the LDPC decoder.

### Vivado Simulation

[Insert Vivado Waveform]

The simulation confirms correct syndrome computation, iterative decoding, and successful convergence.

### UART Validation

[Insert PuTTY Output]

Real-time communication between FPGA and PC was validated using UART and PuTTY.

### FPGA Hardware Validation

[Insert FPGA Images]

Successful and unsuccessful decoding cases were verified through LED indicators and output monitoring.

---

## FPGA Resource Utilization

| Resource        | Used | Available | Utilization |
| --------------- | ---- | --------- | ----------- |
| Slice LUTs      | 1658 | 20800     | 7.97%       |
| Slice Registers | 1339 | 41600     | 3.22%       |
| Block RAM       | 0    | 50        | 0.00%       |
| DSPs            | 0    | 90        | 0.00%       |

The low resource utilization demonstrates the efficiency of the Bit-Flipping architecture for FPGA implementation.

---

## Key Learnings

This project provided hands-on experience in:

* Error Control Coding
* LDPC Codes
* Communication Systems
* Verilog HDL
* FPGA Design
* UART Communication
* MATLAB Simulation
* Xilinx Vivado
* Hardware Debugging
* RTL Design Flow

---

## Challenges Faced

* Understanding LDPC parity-check matrices
* Implementing iterative decoding logic
* Debugging UART communication
* Verifying syndrome convergence
* FPGA synthesis and timing issues
* Hardware validation and testing

Each challenge contributed significantly to strengthening practical engineering and problem-solving skills.

---

## Team Members

* Anvi Keertana R
* Harishankar P M
* Lamiya Hassan A P
* Swaroop V S

### Project Guide

Prof. Sujith Kumar T P

### Institution

Government Engineering College Kozhikode

---

## Future Scope

* Weighted Bit-Flipping LDPC Decoders
* Soft-Decision LDPC Decoding
* High Throughput Architectures
* QC-LDPC Implementations
* 5G Communication Applications
* Satellite Communication Systems

---

## License

This repository is maintained for academic, educational, and portfolio purposes.

© 2026 Team LDPC Decoder Project

---

### If you found this project interesting, consider giving it a ⭐.
