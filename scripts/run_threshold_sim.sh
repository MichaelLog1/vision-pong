#!/usr/bin/env bash
# usage: scripts/run_threshold_sim.sh
set -e
cd "$(dirname "$0")/.."
source /apps/reconfig/enable > /dev/null

vlib -quiet questa/work
vlog -quiet -sv -work questa/work rtl/threshold.sv sim/threshold_tb.sv

# default test
/apps/anaconda/bin/python math_model/threshold.py
vsim -c -work questa/work -gWIDTH=320 -gHEIGHT=240 -gN=4 -do "run -all; quit" threshold_tb

# full mask test
/apps/anaconda/bin/python math_model/threshold.py 320 240 20 0 255 0 255
vsim -c -work questa/work -gWIDTH=320 -gHEIGHT=240 -gN=20 -do "run -all; quit" threshold_tb

# luma gate test
/apps/anaconda/bin/python math_model/threshold.py 320 240 20 50 80 140 160 60
vsim -c -work questa/work -gWIDTH=320 -gHEIGHT=240 -gN=20 -do "run -all; quit" threshold_tb
