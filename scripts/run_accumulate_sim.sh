#!/usr/bin/env bash
# usage: scripts/run_erode_sim.sh
set -e
cd "$(dirname "$0")/.."
source /apps/reconfig/enable > /dev/null

vlib -quiet questa/work
vlog -quiet -sv -work questa/work rtl/accumulate.sv sim/accumulate_tb.sv

# default test
/apps/anaconda/bin/python math_model/accumulate.py
vsim -c -work questa/work -gWIDTH=320 -gHEIGHT=240 -gN=4 -do "run -all; quit" accumulate_tb

# bigger frame test
/apps/anaconda/bin/python math_model/accumulate.py 1000 1000 3 0 0
vsim -c -work questa/work -gWIDTH=1000 -gHEIGHT=1000 -gN=3 -do "run -all; quit" accumulate_tb

# all ones frame test
/apps/anaconda/bin/python math_model/accumulate.py 320 240 5 1 0
vsim -c -work questa/work -gWIDTH=320 -gHEIGHT=240 -gN=5 -do "run -all; quit" accumulate_tb

# all zeros frame test
/apps/anaconda/bin/python math_model/accumulate.py 320 240 5 0 1
vsim -c -work questa/work -gWIDTH=320 -gHEIGHT=240 -gN=5 -do "run -all; quit" accumulate_tb
