#!/usr/bin/env bash
# usage: scripts/run_erode_sim.sh
set -e
cd "$(dirname "$0")/.."
source /apps/reconfig/enable > /dev/null

vlib -quiet questa/work
vlog -quiet -sv -work questa/work rtl/erode.sv sim/erode_tb.sv

# default test
/apps/anaconda/bin/python math_model/erode.py
vsim -c -work questa/work -gWIDTH=320 -gHEIGHT=240 -gN=4 -do "run -all; quit" erode_tb

# large frame
/apps/anaconda/bin/python math_model/erode.py 1000 1000 2 1
vsim -c -work questa/work -gWIDTH=1000 -gHEIGHT=1000 -gN=2 -do "run -all; quit" erode_tb

# erode disabled frame
/apps/anaconda/bin/python math_model/erode.py 320 240 2 0
vsim -c -work questa/work -gWIDTH=320 -gHEIGHT=240 -gN=2 -do "run -all; quit" erode_tb

