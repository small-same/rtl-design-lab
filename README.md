# Digital Front-End Design Flow — Experimental Project

## 1. Project Overview

This is an experimental project that mimics a **digital front-end design flow** using open-source EDA tools. It is intended for learning and research purposes, not for production tapeout.

The design target is a simple RISC-V SoC subsystem built around the **Ibex core** (RV32IMC, lowRISC, Apache 2.0), integrated with AXI4-Lite peripherals including SRAM, DMA, UART, and Timer.

The flow covers the typical front-end stages:

```
RTL Design  →  Code Review  →  Lint  →  Simulation  →  Logic Synthesis
```

All EDA tools (Verilator, Yosys, Icarus Verilog, RISC-V GCC) run inside Docker containers — nothing needs to be installed on the host besides Docker.

A **Claude Code multi-agent pipeline** automates the flow: specialized agents handle spec writing, RTL coding, code review, lint, simulation, and debug in a structured, repeatable iteration loop.

## 2. SoC Architecture

```
Ibex CPU (ibex_core + ibex_register_file_ff)
    │ instr port          │ data port
    └────────┐   ┌────────┘
             ▼   ▼
          obi_mux               ← 2-to-1 fixed-priority arbiter
              │
              ▼
       obi_axil_adapter         ← OBI → AXI4-Lite protocol bridge
              │
              ▼
       axi_interconnect         ← 1-master, 4-slave address decoder
         │         │          │         │
         ▼         ▼          ▼         ▼
     axi_sram  axi_dma_regs  axi_uart  axi_timer
      (4 KB)    + dma_core    _lite      (32-bit)
```

### Address Map

| Base Address | Size | Module | Description |
|---|---|---|---|
| `0x0000_0000` | 4 KB | `axi_sram` | Instruction & data memory |
| `0x0001_0000` | 32 B | `axi_dma_regs` | DMA control / status registers |
| `0x0002_0000` | 16 B | `axi_uart_lite` | UART transmit / receive |
| `0x0003_0000` | 16 B | `axi_timer` | Timer counter + compare-match IRQ |

### Interrupt Routing

| Signal | Source |
|---|---|
| `irq_timer_i` | `axi_timer` (compare match) |
| `irq_external_i` | `axi_uart_lite` \| `axi_dma` |
| `irq_software_i` | Tied low (unused) |

## 3. Design Flow Mapping

This project maps to a simplified digital front-end flow as follows:

| Front-End Stage | Tool Used | Notes |
|---|---|---|
| Specification | Markdown (`doc/`) | Interface, register, timing |
| RTL Design | SystemVerilog | Hand-written + agent-assisted |
| Code Review | Agent (read-only) | Style, synthesizability, bugs |
| Lint | Verilator `--lint-only` | Static checks, warnings |
| Simulation (IP) | Icarus Verilog | Per-module functional verification |
| Simulation (SoC) | Verilator | Full-chip with firmware boot |
| Logic Synthesis | Yosys | Area / cell count estimation |

**Stages NOT covered** (out of scope for this experiment):
- Formal verification (e.g., JasperGold, SymbiYosys)
- DFT insertion
- STA (static timing analysis)
- Physical design (place & route)
- Sign-off (LVS, DRC, power)

## 4. Prerequisites

- **Windows 11** + **Docker Desktop**
- Docker image based on Ubuntu 22.04, containing:
  - Icarus Verilog (iverilog, vvp)
  - Verilator
  - Yosys
  - RISC-V toolchain (`riscv32-unknown-elf-gcc`)
  - make, git
- Build the Docker image once before first use:

```bash
docker compose build
```

## 5. Directory Structure

```
ip/
  common/
    rtl/                    — Shared components (async_fifo, sync_ff)
    tb/tb_macros.vh         — Standardized testbench macros (log, VCD ctrl)
  ibex/rtl/                 — Ibex RISC-V CPU (external IP, Apache 2.0)
  picorv32/rtl/             — PicoRV32 (legacy, kept for reference)
  obi_mux/                  — 2-to-1 OBI arbiter (merges Ibex instr + data)
  obi_axil_adapter/         — OBI-to-AXI4-Lite protocol bridge
  axi_sram/                 — AXI4-Lite SRAM controller (4 KB)
  axi_interconnect/         — 1-to-4 AXI4-Lite address decoder / crossbar
  axi_dma/                  — DMA engine + AXI4-Lite register interface
  axi_uart_lite/            — Minimal UART (loopback mode for simulation)
  axi_timer/                — 32-bit timer with compare-match interrupt
  {module}/
    rtl/                    — RTL source files
    tb/                     — Testbench (Icarus Verilog compatible)
    filelist/rtl.f          — RTL file list (for lint / synthesis)
    filelist/sim.f          — Simulation file list (RTL + testbench)
    Makefile                — Per-IP targets: make lint, make sim

soc/
  rtl/soc_top.sv            — SoC top-level integration module
  tb/tb_soc_top.sv          — SoC testbench (runs on Verilator)
  fw/                       — Firmware: boot.S, main.c, link.ld, Makefile
  filelist/                 — SoC-level file lists
  doc/                      — SoC design specification

scripts/
  lint/run_lint.sh          — Verilator lint wrapper
  sim/run_sim.sh            — Icarus Verilog simulation wrapper
  sim/run_sim_verilator.sh  — Verilator simulation wrapper (SoC level)
  syn/run_syn.sh            — Yosys synthesis wrapper

.claude/
  agents/                   — Agent definitions (7 specialized agents)
  prompts/                  — Slash commands & pipeline orchestration
```

## 6. EDA Commands

All commands run inside Docker:

```bash
# Lint — static RTL checks (Verilator)
docker compose run --rm eda make -C ip/axi_sram lint

# Simulation — IP level (Icarus Verilog)
docker compose run --rm eda make -C ip/axi_sram sim

# Simulation — SoC level (Verilator, required for Ibex SV packages)
docker compose run --rm eda bash scripts/sim/run_sim_verilator.sh \
    soc/filelist/sim.f tb_soc_top soc

# Logic Synthesis — SoC level (Yosys)
docker compose run --rm eda bash scripts/syn/run_syn.sh \
    soc/filelist/rtl.f soc_top soc

# Firmware cross-compilation (RISC-V GCC)
docker compose run --rm eda make -C soc/fw
```

### VCD Waveform Dump Control

| Plusarg | Effect |
|---|---|
| *(default)* | Full dump |
| `+NO_DUMP` | Disable dump entirely |
| `+DUMP_START=N +DUMP_DURATION=M` | Windowed dump |

Reports are written to `{ip_dir}/reports/{lint,sim,syn}/` (git-ignored).

## 7. Simulation Strategy

- **IP-level**: Icarus Verilog (`run_sim.sh`) — each peripheral has its own self-checking testbench. IP-level RTL avoids SV `interface`/`package` for iverilog compatibility.
- **SoC-level**: Verilator (`run_sim_verilator.sh`) — required because the Ibex CPU uses SystemVerilog packages. Firmware boots from SRAM and exercises peripherals.

## 8. Multi-Agent Pipeline

Seven Claude Code agents collaborate in a sequential pipeline. Within each step, agents run in parallel (one per IP) for efficiency.

| Agent | Capabilities | Role |
|---|---|---|
| `design-spec-agent` | Read-only | Write & validate specs |
| `rtl-designer` | Read + Write | Generate / fix RTL |
| `rtl-code-reviewer` | Read-only | Review style & correctness |
| `lint-synthesis-agent` | Read + Bash | Run EDA tools, parse reports |
| `sim-debug-agent` | Read + Bash | Analyze sim failures, re-sim |
| `verification-reviewer` | Read-only | Review testbenches & coverage |
| `script-reviewer` | Read-only | Review EDA & build scripts |

### Pipeline Flow

```
Spec  →  RTL Design  →  Code Review  →  Lint  →  Sim  →  Synthesis
               ↑                                    │
               └──── fix & re-verify (if errors) ───┘
```

### Shortcut Commands

Defined in `.claude/prompts/`:

| Command | Description |
|---|---|
| `/lint <ip>` | Lint a single IP |
| `/sim <ip>` | Simulate a single IP |
| `/check <ip>` | Lint + sim in parallel |
| `/review <ip>` | RTL code review (read-only) |
| `/status` | File completeness & report overview |
| `/add_ip <name>` | Scaffold a new IP skeleton |
| `/fw_build` | Cross-compile firmware |
| `/run_pipeline` | Full pipeline (all steps, all IPs) |
| `/run_step <step> <ips>` | Single pipeline step for selected IPs |

## 9. RTL Coding Conventions

| Rule | Convention |
|---|---|
| Language | SystemVerilog (`always_ff` / `always_comb` only) |
| IP-level | Avoid SV `interface` / `package` (Icarus Verilog compat) |
| SoC-level | SV `package` permitted (simulated with Verilator) |
| Module names | `snake_case` (e.g., `axi_sram`) |
| Parameters | `UPPER_CASE` (e.g., `ADDR_WIDTH`) |
| Active-low | `_n` suffix (e.g., `rst_n`) |
| Registers | `_q` (output), `_d` (next-state) |
| Reset | Asynchronous assert, synchronous deassert, active-low |
| Assignments | Blocking (`=`) for comb, non-blocking (`<=`) for sequential |
| File lists | Direct paths only (no nested `-f`); `-I` for includes |

## 10. Limitations & Known Constraints

- This is a **learning project**; the SoC is not silicon-proven.
- Open-source tools have limitations compared to commercial EDA suites:
  - **Icarus Verilog**: limited SystemVerilog support (no DPI-C, no packages)
  - **Verilator**: cycle-based only (no event-driven timing simulation)
  - **Yosys**: targets FPGA / ASIC generic cells; no foundry-specific PDK
- No formal verification, DFT, STA, or physical design is performed.
- The Ibex core is used as-is from lowRISC; no modifications are made.
