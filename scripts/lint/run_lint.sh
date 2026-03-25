#!/bin/bash
# Verilator Lint Script — AXI DMA Project
# Usage: bash scripts/lint/run_lint.sh <filelist> [output_root]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <filelist> [output_root]"
    echo "  e.g.: $0 ip/axi_dma/filelist/rtl.f ip/axi_dma"
    exit 1
fi
FILELIST="$1"
OUTPUT_ROOT="${2:-$PROJECT_ROOT}"
TOP_MODULE="${3:-}"
REPORT_DIR="$OUTPUT_ROOT/reports/lint"

# Validate filelist exists
if [[ ! -f "$FILELIST" ]]; then
    echo "ERROR: Filelist not found: $FILELIST"
    exit 1
fi

# Create report directory
mkdir -p "$REPORT_DIR"

REPORT_FILE="$REPORT_DIR/verilator_lint.rpt"
echo "=== Verilator Lint Report ===" > "$REPORT_FILE"
echo "Date: $(date)" >> "$REPORT_FILE"
echo "Filelist: $FILELIST" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Run Verilator lint-only
echo "Running Verilator lint on $FILELIST ..."
TOP_OPT=""
[[ -n "$TOP_MODULE" ]] && TOP_OPT="--top-module $TOP_MODULE"
if verilator --lint-only -Wall $TOP_OPT -f "$FILELIST" 2>&1 | tee -a "$REPORT_FILE"; then
    echo "" >> "$REPORT_FILE"
    echo "Result: PASS (no lint errors)" >> "$REPORT_FILE"
    echo "Lint PASSED"
else
    EXIT_CODE=$?
    echo "" >> "$REPORT_FILE"
    echo "Result: FAIL (exit code $EXIT_CODE)" >> "$REPORT_FILE"
    echo "Lint FAILED — see $REPORT_FILE"
    exit $EXIT_CODE
fi
