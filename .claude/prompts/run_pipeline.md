# Run Full Agent Pipeline

Execute the RTL agent pipeline for the specified IPs. Follow CLAUDE.md for model preferences.

## Target IPs
- ip/axi_sram
- ip/axi_dma
- ip/axi_uart_lite
- ip/axi_timer

## Pipeline Steps

Run each step in order. Within each step, spawn one subagent per IP **in parallel**.
If any step finds issues, fix only that IP and re-run that step for it before moving on.

### Step 1 — Design Spec (design-spec-agent, sonnet)
For each IP, read existing `doc/` spec. Validate completeness (interface, registers, timing).
Skip if spec already exists and is complete.

### Step 2 — RTL Design (rtl-designer, opus)
For each IP, generate RTL based on spec. Generate filelist (`rtl.f`, `sim.f`), TB, and Makefile.
After all IPs done, spawn one more rtl-designer for `soc/rtl/soc_top.sv` integration.

### Step 3 — Code Review (rtl-code-reviewer, sonnet)
For each IP, review RTL for coding style, synthesizability, and bugs per CLAUDE.md conventions.
Report findings. If critical issues found, go back to Step 2 for that IP only.

### Step 4 — Lint (lint-synthesis-agent, haiku)
For each IP, run: `docker compose run --rm eda bash scripts/lint/run_lint.sh <filelist> <ip_dir>`
Parse report. If errors, report and fix (spawn rtl-designer for that IP), then re-lint.
After all IPs pass, run SoC-level lint.

### Step 5 — Simulation (lint-synthesis-agent, haiku)
For each IP, run: `docker compose run --rm eda bash scripts/sim/run_sim.sh <sim.f> <tb_name> <ip_dir>`
Parse report. If failures:
  1. Spawn sim-debug-agent (sonnet) for that IP to analyze log and run targeted re-sim
  2. sim-debug-agent produces root-cause report
  3. Spawn rtl-designer (opus) for that IP with the root-cause report to fix RTL
  4. Re-run sim via lint-synthesis-agent to verify fix
After all IPs pass, run SoC-level sim.

### Step 6 — Synthesis (lint-synthesis-agent, haiku)
Run SoC-level synthesis:
`docker compose run --rm eda bash scripts/syn/run_syn.sh soc/filelist/rtl.f soc_top soc`
Report area/timing results.

## Rules
- One subagent per IP per step (save tokens)
- Parallel within step, sequential across steps
- Never modify RTL in lint/sim agents — spawn rtl-designer to fix
- Summarize results after each step before proceeding
