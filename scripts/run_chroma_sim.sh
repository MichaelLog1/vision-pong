#!/usr/bin/env bash
# usage: scripts/run_chroma_sim.sh [WIDTH] [HEIGHT] [N]
set -e
cd "$(dirname "$0")/.."
source /apps/reconfig/enable > /dev/null

W=${1:-320}; H=${2:-240}; N=${3:-4}

/apps/anaconda/bin/python math_model/chroma_extraction.py $W $H $N
vlib -quiet questa/work
vlog -quiet -sv -work questa/work rtl/chroma_extraction.sv sim/chroma_extraction_tb.sv
vsim -c -work questa/work -gWIDTH=$W -gHEIGHT=$H -gN=$N -do "run -all; quit" chroma_extraction_tb
