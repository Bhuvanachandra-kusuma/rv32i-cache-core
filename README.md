# rv32i-cache-core

**RV32I Pipelined Processor with L1 Instruction and Data Caches**

Simulation-verified. All tests passing. Targets PYNQ-Z1 (Zynq XC7Z020).

---

## Test Results

```
Phase 1 — Pipeline registers:   18/18 PASS
Phase 2/3 — Full SoC:           11/11 PASS

x1 = 55  (sum 1..10 ✓)
x4 = 0x400  (store address ✓)
dcache[0x400] = 55  (write-back hit ✓)

I$ hit rate: 94%   D$ hit rate: 5% (expected — small program, cold start)
```

---

## Project Structure

```
rv32i-cache-core/
├── rtl/
│   ├── core/
│   │   ├── rv32i_pipeline_core.v   ← top-level pipeline (5-stage)
│   │   ├── if_id_reg.v             ← IF/ID register (stall + flush)
│   │   ├── id_ex_reg.v             ← ID/EX register (stall + flush)
│   │   ├── ex_mem_reg.v            ← EX/MEM register (stall)
│   │   ├── mem_wb_reg.v            ← MEM/WB register (stall)
│   │   ├── hazard_unit.v           ← load-use stall + branch flush
│   │   ├── forwarding_unit.v       ← EX-EX and MEM-EX bypass
│   │   ├── alu.v                   ← all RV32I ALU operations
│   │   ├── reg_file.v              ← 32×32 write-first register file
│   │   ├── imm_gen.v               ← I/S/B/U/J immediate formats
│   │   ├── control.v               ← opcode decoder
│   │   └── branch_unit.v           ← BEQ/BNE/BLT/BGE/BLTU/BGEU
│   ├── cache/
│   │   ├── icache.v                ← direct-mapped I$ (read-only)
│   │   └── dcache.v                ← direct-mapped D$ (write-back)
│   ├── mem/
│   │   └── sram_model.v            ← dual-port behavioral SRAM
│   └── rv32i_soc.v                 ← SoC top: core + caches + SRAM
├── tb/
│   ├── tb_pipeline.v               ← Phase 1: unit tests (18 tests)
│   └── tb_soc.v                    ← Phase 2/3: full SoC test
└── sim/
    ├── program.hex                  ← test program: sum 1..10 = 55
    ├── tb_pipeline.vcd              ← generated waveform (Phase 1)
    └── tb_soc.vcd                   ← generated waveform (Phase 2/3)
```

---

## How to Run

### Prerequisites

```bash
# Ubuntu / WSL
sudo apt install iverilog gtkwave

# macOS
brew install icarus-verilog gtkwave
```

### Phase 1 — Pipeline unit tests

```bash
# Compile
iverilog -o sim/tb_pipeline \
  tb/tb_pipeline.v \
  rtl/core/if_id_reg.v \
  rtl/core/id_ex_reg.v \
  rtl/core/ex_mem_reg.v \
  rtl/core/mem_wb_reg.v \
  rtl/core/hazard_unit.v \
  rtl/core/forwarding_unit.v

# Run
vvp sim/tb_pipeline

# View waveforms
gtkwave sim/tb_pipeline.vcd
```

Expected output: `18/18 PASS`

### Phase 2/3 — Full SoC simulation

```bash
# Compile
iverilog -o sim/tb_soc \
  tb/tb_soc.v \
  rtl/core/if_id_reg.v \
  rtl/core/id_ex_reg.v \
  rtl/core/ex_mem_reg.v \
  rtl/core/mem_wb_reg.v \
  rtl/core/hazard_unit.v \
  rtl/core/forwarding_unit.v \
  rtl/core/alu.v \
  rtl/core/reg_file.v \
  rtl/core/imm_gen.v \
  rtl/core/control.v \
  rtl/core/branch_unit.v \
  rtl/core/rv32i_pipeline_core.v \
  rtl/cache/icache.v \
  rtl/cache/dcache.v \
  rtl/mem/sram_model.v \
  rtl/rv32i_soc.v

# Run
vvp sim/tb_soc

# View waveforms
gtkwave sim/tb_soc.vcd
```

Expected output: `11/11 PASS`, I$ hit rate ~94%

### Vivado (alternative simulator)

1. Create new RTL project — no board needed for simulation-only
2. Add all `rtl/**/*.v` as **Design Sources**
3. Add `tb/tb_soc.v` as **Simulation Source**
4. Right-click `tb_soc` → **Run Simulation → Run Behavioral Simulation**
5. Waveforms open automatically in Vivado's built-in viewer

---

## How to Evaluate Results

There are three evaluation levels, used in this order:

### Level 1 — GTKWave waveforms (simulation, primary method)

Open `sim/tb_soc.vcd` in GTKWave after running the testbench.

**Key signals to inspect:**

| Signal path | What to look for |
|---|---|
| `dut.u_core.pc` | Advances by 4 each cycle; jumps to branch target on taken branch |
| `dut.u_core.id__instr` | Instruction word flowing through decode |
| `dut.u_core.ex__branch_taken` | Pulses high when branch/jump fires |
| `dut.u_core.pipe_stall` | Goes high during cache misses |
| `dut.u_icache.cpu_hit` | Toggles 0→1 as cache warms up |
| `dut.u_icache.cpu_stall` | High during cache line fill |
| `dut.u_dcache.dirty_array[0]` | Goes high after SW instruction |
| `dut.u_core.wb__reg_write` | Pulses each time a register is written |
| `dut.u_core.wb__write_data` | Should show 1,3,6,10,15,21,28,36,45,55 (partial sums) |

**GTKWave tips:**
- File → Open New Tab → select your `.vcd`
- Drag signals from the Signal Browser into the wave panel
- Press `Ctrl+Shift+F` to fit all in view
- Click a signal → press `I` to zoom to a transition

### Level 2 — Testbench pass/fail (automated)

The testbench prints pass/fail for every check. This is the quickest sanity check — if all pass, waveform inspection is optional.

### Level 3 — FPGA on PYNQ-Z1 (after simulation is clean)

Once simulation passes:

1. Open Vivado, create RTL project targeting `xc7z020clg400-1`
2. Add all RTL sources, set `rv32i_soc` as top
3. Add XDC constraints file with clock definition:
   ```tcl
   create_clock -period 10.000 [get_ports clk]
   ```
4. Run Synthesis → Implementation → Generate Bitstream
5. Open Hardware Manager → Program Device
6. Use ILA (Integrated Logic Analyzer) to probe internal signals at speed

---

## How to Push to GitHub

### First time (new repo)

```bash
cd rv32i-cache-core

# Initialize git
git init
git add .
git commit -m "Initial commit: RV32I 5-stage pipeline + L1 cache SoC"

# Create repo on GitHub (do this in browser or via gh CLI)
gh repo create rv32i-cache-core --public --source=. --remote=origin --push

# Or manually:
git remote add origin https://github.com/YOUR_USERNAME/rv32i-cache-core.git
git branch -M main
git push -u origin main
```

### Subsequent pushes (after making changes)

```bash
# Check what changed
git status
git diff

# Stage and commit
git add rtl/core/alu.v          # add specific files
git add .                        # or add everything

git commit -m "Phase 2: add direct-mapped icache and dcache with write-back"

# Push
git push
```

### Recommended `.gitignore`

```
sim/*.vcd
sim/tb_pipeline
sim/tb_soc
*.swp
*.bak
```

Create it:
```bash
cat > .gitignore << 'EOF'
sim/*.vcd
sim/tb_pipeline
sim/tb_soc
*.swp
*.bak
EOF
git add .gitignore
git commit -m "Add .gitignore"
```

### Good commit message format

```
Phase 1: 5-stage pipeline with hazard + forwarding (18/18 tests pass)
Phase 2: direct-mapped I$ and D$ with write-back policy
fix: write-first register file prevents WB→ID RAW hazard
fix: branch resolves in EX stage for correct cache-stall behavior
```

---

## Program: `sim/program.hex`

Computes sum = 1 + 2 + ... + 10 = 55, stores result at address `0x400`.

```asm
addi x1, x0, 0       # sum = 0
addi x2, x0, 1       # i = 1
addi x3, x0, 11      # limit = 11
loop:
  add  x1, x1, x2   # sum += i
  addi x2, x2, 1    # i++
  blt  x2, x3, loop # while i < 11
lui  x4, 0
addi x4, x4, 0x400  # x4 = 0x400
sw   x1, 0(x4)      # mem[0x400] = 55
jal  x0, 0          # halt (infinite loop)
```

Expected register state after execution:
- `x1 = 55`
- `x2 = 11`
- `x3 = 11`
- `x4 = 0x400`

---

## Architecture Notes

### Key design decisions

**Write-first register file** — standard in production cores. When WB writes to a register at the same cycle that ID reads it, the read returns the new value (bypasses the flip-flop). This prevents a RAW hazard that forwarding cannot catch.

**Branch resolves in EX stage** — branch condition and target are both computed in EX. The PC redirect uses `ex__branch_taken` directly rather than waiting for EX/MEM. This is necessary for correct behavior under cache stalls: if the branch instruction is frozen in EX by an icache miss, the redirect fires correctly when the stall clears.

**Global stall** — all five pipeline registers (IF/ID, ID/EX, EX/MEM, MEM/WB) freeze together on any cache miss. Register file writes are also gated. This prevents stale data from corrupting register state during multi-cycle fills.

**Write-back D$** — stores update the cache line and set a dirty bit. The line is only written to SRAM on eviction. This is realistic (write-through would saturate memory bandwidth in a real system).

### Known limitations (next steps)

- No branch predictor (assumes not-taken, 2-cycle penalty on every taken branch)
- No RV32I multiply/divide extension (M extension)
- No CSR registers or privileged mode
- D$ hit rate is low on cold start (expected — single small program)
- No parameterized widths (hardcoded 32-bit)
