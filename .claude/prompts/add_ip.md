# Add New IP

Scaffold a new IP module with the standard directory structure, filelist, Makefile, and optional TB stub.

## Usage

```
/add_ip <ip_name>
```

Examples:
- `/add_ip axi_gpio`
- `/add_ip axi_spi_master`

## What It Does

1. Creates the standard IP directory structure:
   ```
   ip/<ip_name>/
     rtl/              — (empty, ready for RTL files)
     tb/               — TB stub file: tb_<ip_name>.sv
     filelist/
       rtl.f           — RTL filelist (initially empty)
       sim.f           — Sim filelist (includes tb_macros.vh path, RTL, and TB)
     Makefile          — Standard lint/sim targets
   ```
2. Generates a **TB stub** (`tb/tb_<ip_name>.sv`) with:
   - Standard `tb_macros.vh` include
   - `TB_COUNTERS`, `TB_SUMMARY`, `TB_DUMP_CONTROL` macros
   - Clock/reset boilerplate
   - Placeholder DUT instantiation
3. Generates **Makefile** with `make lint` and `make sim` targets matching project conventions

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `ip_name` | Yes | New IP name in `snake_case` (e.g., `axi_gpio`) |

## Notes

- Will **not** overwrite if `ip/<ip_name>/` already exists
- RTL file must be added manually or via rtl-designer agent
- After adding RTL, update `filelist/rtl.f` and `filelist/sim.f` accordingly
- Remember to add the new IP to `soc/rtl/soc_top.sv` and SoC filelists if it's part of the SoC
- Follow CLAUDE.md naming conventions: `snake_case` module names, `UPPER_CASE` parameters
