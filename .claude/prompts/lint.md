# Lint Single IP

Run Verilator lint on a single IP module.

## Usage

```
/lint <ip_name>
```

Examples:
- `/lint obi_mux`
- `/lint axi_dma`
- `/lint axi_sram`

## What It Does

1. Spawns a **lint-synthesis-agent** (model: haiku)
2. Executes: `docker compose run --rm eda make -C ip/<ip_name> lint`
3. Parses the Verilator lint report from `ip/<ip_name>/reports/lint/`
4. Summarizes: pass/fail, warnings count, error details

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `ip_name` | Yes | IP directory name under `ip/` (e.g., `axi_dma`, `obi_mux`) |

## Notes

- Requires Docker Desktop to be running
- The agent will **not** modify RTL — it only reports findings
- If lint fails, use `/review` or spawn rtl-designer to fix, then re-lint
- For SoC-level lint, use: `/run_step lint soc`
