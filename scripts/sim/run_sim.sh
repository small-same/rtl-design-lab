#!/bin/bash
# Icarus Verilog Simulation Script — AXI DMA Project
# Usage: bash scripts/sim/run_sim.sh <filelist> [top_module] [output_root] [+plusargs...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <filelist> [top_module]"
    echo "  e.g.: $0 ip/axi_dma/filelist/sim.f tb_axi_dma"
    exit 1
fi
FILELIST="$1"
TOP_MODULE="${2:-tb_top}"
OUTPUT_ROOT="${3:-$PROJECT_ROOT}"
REPORT_DIR="$OUTPUT_ROOT/reports/sim"
OUT_DIR="$OUTPUT_ROOT/sim_out"

if [[ ! -f "$FILELIST" ]]; then
    echo "ERROR: Filelist not found: $FILELIST"
    exit 1
fi

mkdir -p "$REPORT_DIR" "$OUT_DIR"

VVP_FILE="$OUT_DIR/${TOP_MODULE}.vvp"
REPORT_FILE="$REPORT_DIR/iverilog_sim.log"

INCLUDE_DIR="$PROJECT_ROOT/ip/common/tb"

echo "Compiling with Icarus Verilog ..."
if iverilog -g2012 -I"$INCLUDE_DIR" -o "$VVP_FILE" -f "$FILELIST" -s "$TOP_MODULE" 2>&1 | tee "$REPORT_FILE"; then
    echo "Compilation succeeded"
else
    EXIT_CODE=$?
    echo "Compilation FAILED — see $REPORT_FILE"
    exit $EXIT_CODE
fi

# Args after the first 3 positional params are passed as plusargs to vvp
PLUSARGS="${@:4}"

echo "Running simulation ..."
if vvp "$VVP_FILE" $PLUSARGS 2>&1 | tee -a "$REPORT_FILE"; then
    echo "Simulation completed — see $REPORT_FILE"
    # Open waveform if VCD was generated
    if ls *.vcd 1>/dev/null 2>&1; then
        echo "VCD waveform generated. Open with: gtkwave *.vcd"
    fi
else
    EXIT_CODE=$?
    echo "Simulation FAILED — see $REPORT_FILE"
    exit $EXIT_CODE
fi
