# Run Single Pipeline Step

Run a single step of the agent pipeline for specified IPs.

## Usage
Provide two arguments:
1. **Step**: spec | rtl | review | lint | sim | syn
2. **IPs**: comma-separated list, or "all" for all IPs

Examples:
- "Run lint for axi_dma"
- "Run sim for all"
- "Run rtl for axi_timer,axi_uart_lite"

## Step Definitions

| Step   | Agent               | Model  | Command |
|--------|---------------------|--------|---------|
| spec   | design-spec-agent   | sonnet | Review/write doc/spec |
| rtl    | rtl-designer        | opus   | Generate RTL + filelist + TB |
| review | rtl-code-reviewer   | sonnet | Review RTL quality |
| lint   | lint-synthesis-agent| haiku  | `run_lint.sh <rtl.f> <ip_dir>` |
| sim    | lint-synthesis-agent| haiku  | `run_sim.sh <sim.f> <tb> <ip_dir>` |
| sim-debug | sim-debug-agent | sonnet | Analyze sim log, targeted re-sim, root-cause report |
| syn    | lint-synthesis-agent| haiku  | `run_syn.sh` (SoC-level only) |

## Rules
- Spawn one subagent per IP, in parallel
- Summarize results when all subagents complete
- If issues found, report and ask user before fixing
