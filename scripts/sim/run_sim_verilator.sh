#!/bin/bash
# Verilator Simulation Script — SoC level (Ibex requires SV packages)
# Usage: bash scripts/sim/run_sim_verilator.sh <filelist> [top_module] [output_root]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <filelist> [top_module] [output_root]"
    echo "  e.g.: $0 soc/filelist/sim.f tb_soc_top soc"
    exit 1
fi
FILELIST="$1"
TOP_MODULE="${2:-tb_soc_top}"
OUTPUT_ROOT="${3:-$PROJECT_ROOT}"
REPORT_DIR="$OUTPUT_ROOT/reports/sim"

if [[ ! -f "$FILELIST" ]]; then
    echo "ERROR: Filelist not found: $FILELIST"
    exit 1
fi

mkdir -p "$REPORT_DIR"

REPORT_FILE="$REPORT_DIR/verilator_sim.log"
OBJ_DIR="$OUTPUT_ROOT/sim_out/verilator_obj"

INCLUDE_DIR="$PROJECT_ROOT/ip/common/tb"
IBEX_INC_DIR="$PROJECT_ROOT/ip/ibex/rtl"

echo "Compiling with Verilator ..."
if verilator --cc --exe --build \
    -f "$FILELIST" \
    --top-module "$TOP_MODULE" \
    -I"$INCLUDE_DIR" \
    -I"$IBEX_INC_DIR" \
    --Mdir "$OBJ_DIR" \
    --trace \
    -Wno-fatal \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    -Wno-UNUSEDSIGNAL \
    -Wno-UNDRIVEN \
    --timescale 1ns/1ps \
    2>&1 | tee "$REPORT_FILE"; then
    echo "Compilation succeeded"
else
    EXIT_CODE=$?
    echo "Compilation FAILED — see $REPORT_FILE"
    exit $EXIT_CODE
fi

echo "Running simulation ..."
if "$OBJ_DIR/V${TOP_MODULE}" 2>&1 | tee -a "$REPORT_FILE"; then
    echo "Simulation completed — see $REPORT_FILE"
else
    EXIT_CODE=$?
    echo "Simulation FAILED — see $REPORT_FILE"
    exit $EXIT_CODE
fi
