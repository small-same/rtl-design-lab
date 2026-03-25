# Check Single IP (Lint + Sim)

Run both lint and simulation on a single IP in parallel. This is the most common workflow after modifying RTL.

## Usage

```
/check <ip_name>
```

Examples:
- `/check obi_mux`
- `/check axi_dma`

## What It Does

1. Spawns **two lint-synthesis-agents** (model: haiku) in parallel:
   - Agent 1: `docker compose run --rm eda make -C ip/<ip_name> lint`
   - Agent 2: `docker compose run --rm eda make -C ip/<ip_name> sim`
2. Waits for both to complete
3. Summarizes combined results: lint warnings/errors + sim pass/fail

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `ip_name` | Yes | IP directory name under `ip/` (e.g., `axi_dma`, `obi_mux`) |

## Notes

- Requires Docker Desktop to be running
- Neither agent modifies RTL — they only report findings
- If either fails, the summary will indicate which step failed and why
- Typical workflow: edit RTL → `/check <ip>` → fix issues → repeat
