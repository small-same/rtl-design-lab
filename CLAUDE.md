# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IC design (RTL) project using SystemVerilog. EDA tools (Verilator, Yosys, Icarus Verilog) run inside Docker — they are **not** installed on the Windows host.

The project implements an Ibex (RISC-V RV32IMC, lowRISC, Apache 2.0) based SoC subsystem with AXI4-Lite interconnect, SRAM, DMA, UART, and Timer peripherals.

## SoC Architecture

```
Ibex CPU (ibex_core + ibex_register_file_ff)
    │ instr port          │ data port
    └────────┐   ┌────────┘
             ▼   ▼
          obi_mux (data-priority arbiter)
              │
              ▼
       obi_axil_adapter (OBI → AXI4-Lite)
              │
              ▼
       axi_interconnect (1-to-4 address decode)
         │         │          │         │
         ▼         ▼          ▼         ▼
     axi_sram  axi_dma_regs  axi_uart  axi_timer
      (4KB)     + dma_core    _lite
```

**IRQ mapping**: `irq_timer_i` ← timer, `irq_external_i` ← UART|DMA, `irq_software_i` ← tied off.

## EDA Commands (all via Docker)

```bash
# Build the EDA Docker image (required once; includes RISC-V toolchain)
docker compose build

# Lint (Verilator)
docker compose run --rm eda bash scripts/lint/run_lint.sh ip/axi_dma/filelist/rtl.f ip/axi_dma

# Synthesis (Yosys)
docker compose run --rm eda bash scripts/syn/run_syn.sh soc/filelist/rtl.f soc_top soc

# IP-level simulation (Icarus Verilog — for peripherals without SV packages)
docker compose run --rm eda bash scripts/sim/run_sim.sh ip/axi_dma/filelist/sim.f tb_axi_dma ip/axi_dma

# SoC-level simulation (Verilator — required because Ibex uses SV packages)
docker compose run --rm eda bash scripts/sim/run_sim_verilator.sh soc/filelist/sim.f tb_soc_top soc

# SoC-level lint
docker compose run --rm eda bash scripts/lint/run_lint.sh soc/filelist/rtl.f soc

# Per-IP Makefile shortcuts (also run inside Docker)
docker compose run --rm eda make -C ip/axi_dma lint
docker compose run --rm eda make -C ip/axi_dma sim

# Firmware build (RISC-V RV32IMC)
docker compose run --rm eda make -C soc/fw

# VCD dump control (plusargs passed after positional args)
# Default: full dump. +NO_DUMP: disable. +DUMP_START=N +DUMP_DURATION=M: windowed dump.
docker compose run --rm eda bash scripts/sim/run_sim.sh ip/axi_dma/filelist/sim.f tb_axi_dma ip/axi_dma +NO_DUMP
```

Reports are written to `{ip_dir}/reports/{lint,syn,sim}/` (git-ignored).

## Simulation Strategy

- **IP-level**: Icarus Verilog via `run_sim.sh` — all peripheral TBs use this
- **SoC-level**: Verilator via `run_sim_verilator.sh` — required because Ibex uses SV `package`
- Both use standardized TB macros from `ip/common/tb/tb_macros.vh`

## Repository Layout

```
ip/
  common/
    rtl/                    — shared components (async_fifo, sync_ff)
    tb/tb_macros.vh         — standardized TB logging + VCD dump control macros
  ibex/rtl/                 — Ibex RISC-V CPU (external IP, Apache 2.0)
  picorv32/rtl/             — PicoRV32 (legacy, kept for rollback)
  obi_mux/rtl/              — 2-to-1 OBI arbiter (merges Ibex instr+data ports)
  obi_axil_adapter/rtl/     — OBI to AXI4-Lite bridge
  axi_sram/                 — AXI4-Lite SRAM slave (4KB)
  axi_interconnect/         — 1-to-4 AXI4-Lite address decoder/mux
  axi_dma/                  — DMA core + register wrapper
  axi_uart_lite/            — Simple UART with loopback for sim
  axi_timer/                — 32-bit timer with compare match IRQ
  {module}/
    rtl/                    — RTL source
    tb/                     — testbenches
    filelist/rtl.f, sim.f   — filelists
    Makefile                — per-IP build targets (lint, sim)
soc/
  rtl/soc_top.sv            — SoC top-level integration
  tb/tb_soc_top.sv          — SoC testbench (Verilator)
  fw/                       — firmware (boot.S, main.c, link.ld, Makefile)
  filelist/                 — SoC-level filelists
scripts/{lint,syn,sim}/     — shared wrapper scripts
.claude/
  agents/                   — Claude Code Agent definitions
  prompts/                  — Pipeline orchestration prompts
```

## SoC Address Map

| Base Address  | Size | Module           | Description             |
|---------------|------|------------------|-------------------------|
| `0x0000_0000` | 4 KB | `axi_sram`       | Main SRAM (boot + data) |
| `0x0001_0000` | 32 B | `axi_dma_regs`   | DMA control/status      |
| `0x0002_0000` | 16 B | `axi_uart_lite`  | UART TX/RX              |
| `0x0003_0000` | 16 B | `axi_timer`      | Timer + IRQ             |

## Agent Workflow

The project uses a multi-agent pipeline defined in `.claude/agents/`. Spawn one subagent per IP per step (parallel within step, sequential across steps).

1. **design-spec-agent** — writes specs in `doc/` (IP and SoC level)
2. **rtl-designer** — generates RTL, filelists, SoC integration
3. **rtl-code-reviewer** — reviews RTL (read-only), including SoC-level checks
4. **lint-synthesis-agent** — runs EDA tools via Docker, parses reports (**never modifies RTL**)
5. **verification-reviewer** / **script-reviewer** — review testbenches, scripts, firmware builds
5b. **sim-debug-agent** — analyzes sim failures, runs targeted VCD re-sims, produces root-cause analysis for rtl-designer

Orchestration prompts in `.claude/prompts/run_pipeline.md` (full pipeline) and `run_step.md` (single step).

## Agent Model Preferences

When spawning agents, use the `model` parameter to control cost and quality:

| Agent | Model | Rationale |
|-------|-------|-----------|
| rtl-designer | opus | RTL generation needs highest quality |
| design-spec-agent | sonnet | Spec writing, sonnet is sufficient |
| rtl-code-reviewer | sonnet | Code review, sonnet is sufficient |
| verification-reviewer | sonnet | TB review, sonnet is sufficient |
| sim-debug-agent | sonnet | Log analysis and root-cause diagnosis |
| lint-synthesis-agent | haiku | Runs commands and parses reports only |
| script-reviewer | haiku | Script review, relatively simple |

## RTL Conventions

- SystemVerilog: `always_ff`/`always_comb` only (no `always @(*)`)
- Naming: modules `snake_case`, parameters `UPPER_CASE`, active-low `_n`, register output/input `_q`/`_d`
- Reset: async assert, sync deassert, active-low (`rst_n`)
- Blocking `=` for combinational, non-blocking `<=` for sequential
- IP-level RTL: avoid SV `interface`/`package` (iverilog compatibility)
- Ibex and SoC-level: SV `package` is OK (uses Verilator for sim)
- Filelists: direct file paths only (no nested `-f`); use `-I` for include dirs

## TB Macros (`ip/common/tb/tb_macros.vh`)

All TBs include standardized macros for structured logging:
- `` `TB_CHECK(cond, msg) `` — pass/fail with `[%0t] ERROR: ... (%m)` format
- `` `TB_CHECK_EQ(actual, expected, msg) `` — with expected/actual values
- `` `TB_DUMP_CONTROL(scope) `` — VCD dump via plusargs (+NO_DUMP, +DUMP_START, +DUMP_DURATION)
- `` `TB_SUMMARY(name) `` — end-of-sim report

These structured logs enable sim-debug-agent to automatically parse failure locations.
