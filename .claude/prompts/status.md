# Project Status

Show the current status of all IPs in the project: file completeness and latest report results.

## Usage

```
/status
```

## What It Does

1. Scans all IP directories under `ip/`
2. For each IP, checks:
   - **RTL**: exists in `rtl/` directory
   - **TB**: exists in `tb/` directory
   - **Filelist**: `rtl.f` and `sim.f` exist in `filelist/`
   - **Makefile**: exists at IP root
   - **Lint report**: latest result in `reports/lint/` (pass/fail/not run)
   - **Sim report**: latest result in `reports/sim/` (pass/fail/not run)
3. For SoC level, additionally checks:
   - `soc/rtl/soc_top.sv` integration
   - `soc/fw/` firmware files (boot.S, main.c, link.ld)
   - SoC-level lint/sim/syn reports
4. Outputs a summary table

## Output Format

```
IP                 RTL  TB  Filelist  Makefile  Lint    Sim
─────────────────────────────────────────────────────────────
axi_sram           ✅   ✅   ✅        ✅       PASS    PASS
axi_dma            ✅   ✅   ✅        ✅       —       —
obi_mux            ✅   ✅   ✅        ✅       —       —
...
SoC                ✅   ✅   ✅        —        —       —
```

## Notes

- Does **not** run any EDA tools — only reads existing files and reports
- `—` means no report found (not yet run)
- Use `/check <ip>` to run lint + sim for a specific IP
- Use `/run_pipeline` to run the full pipeline for all IPs
