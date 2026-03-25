# Simulate Single IP

Run Icarus Verilog simulation on a single IP module's testbench.

## Usage

```
/sim <ip_name>
```

Examples:
- `/sim obi_mux`
- `/sim axi_dma`
- `/sim axi_timer`

## What It Does

1. Spawns a **lint-synthesis-agent** (model: haiku)
2. Executes: `docker compose run --rm eda make -C ip/<ip_name> sim`
3. Parses the simulation log for TB_CHECK pass/fail results
4. Summarizes: total pass/fail count, error messages, test names

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `ip_name` | Yes | IP directory name under `ip/` (e.g., `axi_dma`, `obi_mux`) |

## Notes

- Requires Docker Desktop to be running
- The agent will **not** modify RTL — it only reports findings
- If sim fails, follow up with `/sim_debug` or spawn sim-debug-agent for root-cause analysis
- VCD dump is enabled by default; pass `+NO_DUMP` via Makefile override to disable
- For SoC-level sim (Verilator), use: `/run_step sim soc`
