# Spartan-6 DSP48A1 Slice — RTL Design & Verification

*Prepared by: Aly Khaled*

A behavioral Verilog model of the Xilinx Spartan-6 `DSP48A1` hard macro: pre-adder/subtracter, 18x18 multiplier, post-adder/subtracter, and the full register/clock-enable/reset pipeline, built to match the datasheet port list and OPMODE-driven behavior so it can be dropped in as a drop-in equivalent of the primitive and pushed through the Vivado synthesis/implementation flow.

## 1. Overview

The `DSP48A1` slice takes four data inputs (`A`, `B`, `C`, `D`), an 8-bit `OPMODE` control word, and cascade inputs (`BCIN`, `PCIN`), and produces:

- **`M`** — 36-bit multiplier output (registered or direct)
- **`P`** — 48-bit primary post-adder/subtracter output
- **`BCOUT`**, **`PCOUT`** — cascade outputs to a downstream DSP48A1 slice
- **`CARRYOUT`** / **`CARRYOUTF`** — carry out of the post-adder/subtracter

Internally, data flows: `D`/`B` → optional pre-adder/subtracter → 18x18 multiplier → `X` mux → post-adder/subtracter (with `Z` mux and `C` port) → `P`. Every stage has an independent pipeline register that can be enabled or bypassed via a parameter, matching the real primitive's `A0REG`/`A1REG`/.../`OPMODEREG` attribute set.

## 2. File Structure

```
.
├── dsp.v                      # RTL: DSP module + reg_and_mux submodule
├── DSPtestbench.v             # Self-checking testbench (DSP_tb)
├── run.do                     # Questasim compile/simulate/wave script
├── Constraints_basys3.xdc     # Vivado timing constraint (100 MHz on W5)
└── README.md
```

## 3. RTL Architecture

### 3.1 `reg_and_mux` (reusable pipeline stage, instantiated 10x)

A parameterized register-plus-bypass-mux block used for every pipeline stage in the design (`A0`, `A1`, `B0`, `B1`, `C`, `D`, `OPMODE`, `M`, `CARRYIN`, `CARRYOUT`, `P`):

| Parameter | Purpose |
|---|---|
| `rstTYPE` | `"SYNC"` or `"ASYNC"` reset behavior |
| `reg_pipeline` | `1` = output is the registered value, `0` = output bypasses the register (combinational passthrough) |
| `width` | Bus width of this stage |

This single module is why the top-level `DSP` module doesn't need to be split further — every stage's register/bypass/reset/clock-enable behavior is centralized here instead of repeated ten times.

### 3.2 `DSP` (top module)

Implements, in order:

1. **B/BCIN input mux** — `B_INPUT` parameter selects direct `B` vs. cascaded `BCIN`.
2. **Input pipeline stage 0** — `D_REG`, `B0_REG`, `A0_REG`, `C_REG` (first-stage registers; `A0REG`/`B0REG` default to bypass per the datasheet).
3. **Pre-adder/subtracter** — `OPMODE[6]` selects add (`D+B0`) or subtract (`D-B0`).
4. **Mux before B1** — `OPMODE[4]` selects pre-adder output vs. raw `B0` feeding into the multiplier's B operand.
5. **Input pipeline stage 1** — `A1_REG`, `B1_REG`, `OPMODE_REG`.
6. **18x18 multiplier** — `A1_MUX_OUT * B1_MUX_OUT` → `M_REG`.
7. **Carry-in mux (`CYI`)** — `CARRYINSEL` parameter selects `CARRYIN` pin vs. `OPMODE[5]`.
8. **X mux** (`OPMODE[1:0]`) — zero / multiplier product / `P` feedback / concatenated `D:A:B`.
9. **Z mux** (`OPMODE[3:2]`) — zero / `PCIN` / `P` feedback / `C` port.
10. **Post-adder/subtracter** — `OPMODE[7]` selects `X+Z+CIN` vs. `Z-(X+CIN)`; carry/borrow out of bit 48 feeds `CARRYOUT`/`CARRYOUTF`.
11. **Output pipeline** — `P_REG`, `CYO_REG`.

Cascade outputs: `BCOUT = B1_MUX_OUT`, `PCOUT = P` (internal, pre- or post-register per `PREG`).

### 3.3 Deviations from the Xilinx primitive (for the writeup)

- `CARRYINSEL` and `B_INPUT` are implemented as **string parameters** compared in `always @(*)` blocks rather than as true Vivado enumerated attributes on a primitive instantiation — functionally equivalent in simulation and synthesis, but worth noting since the real `DSP48A1` primitive takes these as vendor attributes, not RTL parameters.
- This is a fully synthesizable behavioral model, not an instantiation of the `DSP48A1` primitive itself — Vivado is expected to infer/map it onto the hardened DSP48A1 block during synthesis (check the synthesized schematic to confirm the mapping, per the assignment's deliverable #4).

## 4. Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `A0REG`, `B0REG` | `0` | First-stage A/B pipeline register (0 = bypass) |
| `A1REG`, `B1REG` | `1` | Second-stage A/B pipeline register |
| `CREG`, `DREG`, `MREG`, `PREG`, `CARRYINREG`, `CARRYOUTREG`, `OPMODEREG` | `1` | Register enable for each respective stage |
| `CARRYINSEL` | `"OPMODE[5]"` | `"CARRYIN"` or `"OPMODE[5]"` — source of the carry-cascade input |
| `B_INPUT` | `"DIRECT"` | `"DIRECT"` or `"CASCADE"` — B port source |
| `RSTTYPE` | `"SYNC"` | `"SYNC"` or `"ASYNC"` — reset behavior for all registers |

## 5. OPMODE Encoding (as implemented)

| Bit(s) | Function |
|---|---|
| `[1:0]` | X mux: `0`=zero, `1`=multiplier product, `2`=P feedback, `3`=concatenated D:A:B |
| `[3:2]` | Z mux: `0`=zero, `1`=PCIN, `2`=P feedback, `3`=C port |
| `[4]` | Pre-adder bypass (`0`) vs. use pre-adder result (`1`) feeding B1 |
| `[5]` | Carry-in value when `CARRYINSEL="OPMODE[5]"` |
| `[6]` | Pre-adder/subtracter: `0`=add (`D+B`), `1`=subtract (`D-B`) |
| `[7]` | Post-adder/subtracter: `0`=add (`X+Z+CIN`), `1`=subtract (`Z-(X+CIN)`) |

## 6. Verification

### 6.1 Testbench structure (`DSP_tb`)

Self-checking, directed-test testbench with 5 phases, each gated by `@(negedge CLK)` so outputs are checked once the pipeline has settled:

1. **Reset check** — all resets asserted, random data driven; confirms every output (`M`, `P`, `PCOUT`, `BCOUT`, `CARRYOUT`, `CARRYOUTF`) reads `0`.
2. **Path 1** (`OPMODE=8'b11011101`) — exercises pre-adder subtract (`D-B`) feeding the multiplier via `OPMODE[4]`, X = multiplier product, Z = C port, post-adder = subtract. Expected `BCOUT='hf` (=`D-B`=`25-10`) and `M='h12c` (=`A*(D-B)`=`20*15`) are independently reproducible from the RTL's datapath equations.
3. **Path 2** (`OPMODE=8'b00010000`) — pre-adder bypass (raw `B` to multiplier), X=zero, Z=zero → `P` should hold at `0`.
4. **Path 3** (`OPMODE=8'b00001010`) — X=P feedback, Z=P feedback with post-adder in add mode → `P`/`PCOUT` should hold their previous value (accumulator-style self-check via `preP`/`prePOUT`).
5. **Path 4** (`OPMODE=8'b10100111`) — Z=`PCIN`, X=concatenated D:A:B, post-adder subtract with `CARRYIN` cascade → exercises the 48-bit carry-out path (`CARRYOUT`/`CARRYOUTF` expected `1`).

Each phase repeats 100 times with the same directed operands but randomized `BCIN`/`PCIN`/`CARRYIN` (which don't feed the checked outputs in each mode) to catch any accidental sensitivity to those cascade inputs.

### 6.2 Results

All five directed-test phases passed on the final run:

```
CORRECT OUTPUT-The reset is working well
CORRECT OUTPUT-path 1 works well
CORRECT OUTPUT-path 2 works well
CORRECT OUTPUT-path 3 works well
CORRECT OUTPUT-path 4 works well
```

Linting reported **0 warnings, 0 errors**. Synthesis and implementation timing summaries both report **all user-specified timing constraints met**:

| | Setup WNS | Hold WHS | Pulse Width WPWS | Failing endpoints |
|---|---|---|---|---|
| Post-synthesis | 5.224 ns | 0.182 ns | 4.500 ns | 0 |
| Post-implementation | 2.580 ns | 0.059 ns | 3.950 ns | 0 |

Post-implementation utilization: 2762 Slice LUTs, 4225 Slice Registers, 1 DSP, 327 Bonded IOBs (out of 500 available on the target part).

### 6.3 Running the simulation (Questasim / `do` file)

```tcl
vlib work
vlog dsp.v DSPtestbench.v
vsim -voptargs=+acc work.DSP_tb
add wave *
run -all
```
Saved as `run.do`, run with `vsim -do run.do` (or `do run.do` from within the Questasim console). Waveform and transcript results are captured per the assignment's deliverable #2 — see Section 6.2 above.

### 6.4 Running the Vivado flow

1. Create a new project, add `dsp.v` as a design source.
2. Add `Constraints_basys3.xdc`, containing only the clock constraint:
   ```tcl
   set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports CLK]
   create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports CLK]
   ```
   (10 ns period = 100 MHz, per the assignment's requirement.)
3. **Target part — worth double-checking before final submission.** The assignment specifies **`xc7a200tffg1156-3`** rather than the Basys 3's stock part, precisely because this design's I/O count (327 bonded IOBs used) exceeds what the Basys 3 board exposes. The `Constraints_basys3.xdc` file itself is fine to reuse (it only carries the clock constraint, no board-specific pin range), but confirm the *project's target part* was actually set to `xc7a200tffg1156-3` and not left on a Basys-3-sized part — otherwise pin allocation for the wide A/B/C/D/M/P/PCOUT/PCIN buses may not be physically realizable on the smaller device.
4. Run **Elaboration** → capture the "Messages" tab (no critical warnings/errors) and a schematic snippet showing the DSP block among other inferred cells.
5. Run **Synthesis** → capture Messages, schematic (overview + detailed + zoomed views), utilization report, and timing report.
6. Run **Implementation** → capture Messages, device view, utilization report, and timing report.
7. Run the linting tool with default methodology/goals → capture a snippet showing no errors (confirmed on this run: 0 warnings, 0 errors).

## 7. Deliverables Checklist (per assignment spec)

Status reflects the submitted report:

- [x] RTL code
- [x] Testbench code
- [x] Do file
- [x] QuestaSim waveform snippets (inputs + outputs visible)
- [x] Constraint file (clock only, 100 MHz, pin W5)
- [x] Elaboration: Messages tab + schematic snippet
- [x] Synthesis: Messages tab + utilization report + timing report + schematic snippets
- [x] Implementation: Messages tab + utilization report + timing report + device snippet
- [x] Linting: snippet showing no errors


## 8. Signal Reference

Full port and parameter tables are in the original assignment spec (`DSP48A1.pdf`, Spartan-6 UG389 datasheet excerpt) — see Sections 3–5 there for the authoritative signal-by-signal description of every port used in this RTL.
