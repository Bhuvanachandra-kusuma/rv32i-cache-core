# rv32i-cache-core

A complete RV32I pipelined SoC implemented in Verilog, featuring a 5-stage in-order pipeline, Harvard L1 caches, and an AXI4-Lite UART peripheral. Built from scratch as a self-directed VLSI learning project.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                        rv32i_soc                             │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              rv32i_pipeline_core                       │  │
│  │        IF → ID → EX → MEM → WB  (RV32I ISA)          │  │
│  │        Hazard detection + Operand forwarding           │  │
│  └──────────────┬────────────────────┬────────────────────┘  │
│                 │ imem               │ dmem                   │
│          ┌──────┴──────┐      ┌──────┴──────┐                │
│          │   icache    │      │   dcache    │                │
│          └──────┬──────┘      └──────┬──────┘                │
│                 │                    │    ┌────────────────┐  │
│          ┌──────┴────────────────────┤    │   axi_uart     │  │
│          │       sram_model          │◄───│  + uart_tx     │  │
│          │  (dual-port, 2-cycle)     │    └────────────────┘  │
│          └───────────────────────────┘   axi_interconnect     │
└──────────────────────────────────────────────────────────────┘
```

---

## Memory Map

| Address Range | Peripheral |
|---|---|
| `0x00000000 – 0x0FFFFFFF` | SRAM (instructions + data, via caches) |
| `0x10000000 – 0x1FFFFFFF` | UART (AXI4-Lite, bypasses dcache) |

**UART registers:**

| Offset | Register | Description |
|---|---|---|
| `0x00` | TX_DATA | Write byte here to transmit |
| `0x04` | STATUS | Bit 0 = `tx_ready` (1 = ready to send) |

---

## Pipeline Design

5-stage in-order pipeline implementing the full RV32I base integer ISA.

| Stage | Function |
|---|---|
| IF | Instruction fetch via icache |
| ID | Decode + register file read |
| EX | ALU + branch resolution + forwarding |
| MEM | Data cache / AXI peripheral access |
| WB | Write-back to register file |

**Key design decisions:**

- Branch resolves in EX (not MEM) — minimises flush penalty
- Load-use hazard: `front_stall` freezes IF/ID/ID-EX only; `back_stall` (cache/peripheral) freezes all stages — this separation is critical for correct load-to-MEM advancement
- Forwarding covers EX-EX and MEM-EX paths
- Write-first register file prevents WB→ID RAW hazards

---

## AXI4-Lite UART Peripheral

The CPU sends a character over UART using standard memory-mapped store/load instructions:

```asm
lui  x5, 0x10000       # x5 = 0x10000000 (UART base)
addi x6, x0, 0x48      # x6 = 'H' (ASCII 72)
poll:
  lw   x7, 4(x5)       # read STATUS register
  andi x7, x7, 1       # check tx_ready bit
  beq  x7, x0, poll    # wait if not ready
sw   x6, 0(x5)         # write 'H' to TX_DATA → transmits
```

**UART parameters:** 115200 baud, 100MHz clock, 1 start bit, 8 data bits, 1 stop bit, no parity.
**AXI4-Lite interconnect** includes a DONE state after every transaction to prevent immediate re-triggering while the pipeline resumes.

---

## File Structure

```
rtl/
├── core/
│   ├── rv32i_pipeline_core.v   ← top-level pipeline
│   ├── if_id_reg.v
│   ├── id_ex_reg.v
│   ├── ex_mem_reg.v
│   ├── mem_wb_reg.v
│   ├── hazard_unit.v
│   ├── forwarding_unit.v
│   ├── alu.v
│   ├── reg_file.v
│   ├── imm_gen.v
│   ├── control.v
│   └── branch_unit.v
├── cache/
│   ├── icache.v
│   └── dcache.v
├── mem/
│   └── sram_model.v
├── peripheral/
│   ├── uart_tx.v
│   ├── axi_uart.v
│   └── axi_interconnect.v
└── rv32i_soc.v                 ← top-level SoC

tb/
├── tb_pipeline.v               ← Phase 1 unit tests (18/18)
└── tb_soc.v                    ← Full SoC tests (9/9)

sim/
└── program.hex                 ← Test program
```

---

## Test Program

The simulation program (`sim/program.hex`) does the following:

1. Computes the sum of integers 1 to 10 (result = 55)
2. Stores the result at SRAM address `0x400`
3. Loads the UART base address `0x10000000` into x5
4. Polls the UART STATUS register until `tx_ready = 1`
5. Transmits ASCII `'H'` (0x48) over the UART TX pin
6. Halts (`jal x0, 0`)

---

## Simulation Results

**Phase 1 — Pipeline unit tests: 18/18 PASS**

**Phase 2 — Full SoC with UART: 9/9 PASS**

```
=== rv32i-cache-core + UART SoC Test ===

--- Correctness ---
  PASS  x1 = 55 (sum 1..10)
  PASS  x4 = 0x400 (store addr)
  PASS  x5 = 0x10000000 (UART base)
  PASS  x6 = 0x48 (ASCII H)
  PASS  x7 = 1 (STATUS ready)
  PASS  UART received byte = H
  PASS  UART transmission complete

--- Cache Performance ---
  PASS  I$ recorded hits
  PASS  I$ recorded misses

--- Performance Metrics ---
  Total cycles  : 14999
  I$ hits       : 14914
  I$ misses     : 85
  D$ hits       : 1
  D$ misses     : 17
  I$ hit rate   : 99%
```

---

## Synthesis Results

**Target:** Xilinx Zynq UltraScale+ (`xczu7eg-ffvc1156-2-e`, speed grade -2)
**Tool:** Vivado 2024.2

| Resource | Used | Available | Utilization |
|---|---|---|---|
| CLB LUTs | 8,047 | 230,400 | 3.49% |
| Flip-Flops | 17,466 | 460,800 | 3.79% |
| Block RAMs | 14.5 tiles | 312 | 4.65% |
| DSPs | 0 | 1,728 | 0% |

**Timing:**
- Clock period: 10ns (100MHz constraint)
- WNS: 2.450ns → **~170MHz capable**
- TNS: 0.000ns
- Failing endpoints: 0
- **All timing constraints met ✓**

The 14.5 BRAM tiles are inferred from the dual-port SRAM model (instruction + data memory). The register file is inferred as distributed RAM (LUT as Memory). No DSPs used — the ALU uses CARRY8 carry-chain logic.

---

## How to Run

**Prerequisites:** Icarus Verilog (`iverilog`), GTKWave (optional)

**Phase 1 — Pipeline unit tests:**
```bash
iverilog -o sim/tb_pipeline tb/tb_pipeline.v rtl/core/*.v
vvp sim/tb_pipeline
```

**Phase 2 — Full SoC simulation:**
```bash
iverilog -o sim/tb_soc tb/tb_soc.v \
  rtl/core/*.v rtl/cache/*.v rtl/mem/*.v \
  rtl/peripheral/*.v rtl/rv32i_soc.v
vvp sim/tb_soc
```

**View waveforms:**
```bash
gtkwave sim/tb_soc.vcd
```

---

## Key Bugs Fixed During Development

**1. Load-use stall freezing EX/MEM and MEM/WB (root cause of all UART failures)**
The original `pipe_stall` signal was used for all pipeline registers. When a load-use hazard fired, it froze the entire pipeline including EX/MEM and MEM/WB, preventing the load instruction from advancing to the memory stage. Fixed by separating into `front_stall` (load-use + cache, for IF/ID/ID-EX) and `back_stall` (cache only, for EX/MEM/MEM-WB).

**2. AXI interconnect immediate re-trigger**
After an AXI transaction completed, `cpu_stall` dropped to 0 but `cpu_req` was still asserted for one cycle, causing a new transaction to start before the pipeline could advance. Fixed by adding a DONE state that holds for one cycle before returning to IDLE.

**3. uart_access not gated by cpu_req**
The LUI instruction loading `0x10000000` into x5 left that value in the MEM stage ALU result. Without gating `uart_access` by `cpu_dmem_req`, the interconnect fired spuriously for non-memory instructions. Fixed by: `uart_access = (addr[31:28] == 4'h1) && cpu_dmem_req`.

**4. UART receiver off-by-one in testbench**
The testbench receiver was sampling at the wrong clock count, missing the stop bit. Fixed by capturing the byte immediately when bit 7 is sampled rather than waiting for the stop bit window.

---

## Tools Used

| Tool | Purpose |
|---|---|
| Icarus Verilog | RTL simulation |
| GTKWave | Waveform analysis |
| Vivado 2024.2 | Synthesis, implementation, timing analysis |
| Python | Instruction encoding verification |

---

## Author

Bhuvanachandra Kusuma
M.Sc. Nanoelectronic Systems, TU Dresden
GitHub: [Bhuvanachandra-kusuma](https://github.com/Bhuvanachandra-kusuma)
