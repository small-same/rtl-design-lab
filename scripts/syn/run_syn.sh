#!/bin/bash
# Yosys Synthesis Script — AXI DMA Project
# Usage: bash scripts/syn/run_syn.sh <filelist> [top_module] [output_root]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <filelist> [top_module] [output_root]"
    echo "  e.g.: $0 ip/axi_dma/filelist/rtl.f AXI_DMA_Core ip/axi_dma"
    exit 1
fi
FILELIST="$1"
TOP_MODULE="${2:-AXI_DMA_Core}"
OUTPUT_ROOT="${3:-$PROJECT_ROOT}"
REPORT_DIR="$OUTPUT_ROOT/reports/syn"

if [[ ! -f "$FILELIST" ]]; then
    echo "ERROR: Filelist not found: $FILELIST"
    exit 1
fi

mkdir -p "$REPORT_DIR"

REPORT_FILE="$REPORT_DIR/yosys_syn.rpt"

# Build Yosys script
YOSYS_SCRIPT=$(mktemp /tmp/yosys_syn.XXXXXX.ys)
trap "rm -f $YOSYS_SCRIPT" EXIT

# Read source files from filelist (supports -f includes)
parse_filelist() {
    local flist="$1"
    while IFS= read -r line; do
        line="$(echo "$line" | sed 's/#.*//' | xargs)"
        [[ -z "$line" ]] && continue
        if [[ "$line" == -f\ * ]]; then
            local inc_file="${line#-f }"
            parse_filelist "$PROJECT_ROOT/$inc_file"
        elif [[ "$line" == -* ]]; then
            continue  # skip other flags
        else
            echo "read_verilog -sv $PROJECT_ROOT/$line" >> "$YOSYS_SCRIPT"
        fi
    done < "$flist"
}
parse_filelist "$FILELIST"

cat >> "$YOSYS_SCRIPT" <<EOF
hierarchy -top $TOP_MODULE
proc; opt; fsm; opt; memory; opt
techmap; opt
stat
EOF

echo "Running Yosys synthesis (top=$TOP_MODULE) ..."
if yosys -s "$YOSYS_SCRIPT" 2>&1 | tee "$REPORT_FILE"; then
    echo "Synthesis completed — see $REPORT_FILE"
else
    EXIT_CODE=$?
    echo "Synthesis FAILED — see $REPORT_FILE"
    exit $EXIT_CODE
fi
