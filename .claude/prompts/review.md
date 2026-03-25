# Review Single IP

Run an RTL code review on a single IP module. Checks coding style, synthesizability, and common bugs.

## Usage

```
/review <ip_name>
```

Examples:
- `/review obi_mux`
- `/review axi_dma`
- `/review axi_interconnect`

## What It Does

1. Spawns an **rtl-code-reviewer** (model: sonnet)
2. Reads all RTL files in `ip/<ip_name>/rtl/`
3. Reviews against CLAUDE.md conventions:
   - `always_ff`/`always_comb` usage (no `always @(*)`)
   - Naming: `snake_case` modules, `UPPER_CASE` params, `_n` active-low, `_q`/`_d` registers
   - Reset: async assert, sync deassert, active-low (`rst_n`)
   - Blocking `=` for combinational, non-blocking `<=` for sequential
   - No SV `interface`/`package` at IP level (iverilog compatibility)
4. Reports findings with severity (critical / warning / info)

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `ip_name` | Yes | IP directory name under `ip/` (e.g., `axi_dma`, `obi_mux`) |

## Notes

- This agent is **read-only** — it will not modify any files
- If critical issues are found, use rtl-designer to fix them
- For SoC-level review (including integration checks), specify `soc` as ip_name
