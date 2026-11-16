#!/bin/bash
set -e

# uart config
config-pin P9_11 uart
config-pin P9_13 uart

# pin configuration
config-pin P8_27 pruin
config-pin P8_28 pruin
config-pin P8_29 pruin
config-pin P8_39 pruin
config-pin P8_40 pruin
config-pin P8_41 pruin
config-pin P8_42 pruin
config-pin P8_43 pruin
config-pin P8_44 pruin
config-pin P8_45 pruin
config-pin P8_46 pruin


# release camera reset
config-pin P8_13 gpio
echo high | tee /sys/class/gpio/gpio23/direction

# release camera de (enables buffers)
config-pin P8_30 gpio
echo low | tee /sys/class/gpio/gpio89/direction

# run init script
python3 ov5640_init.py

for i in {1..120}; do
    [[ -e /sys/class/remoteproc/remoteproc2/state ]] && break
    sleep 0.5
done

if [[ ! -e "/sys/class/remoteproc/remoteproc2/state" ]]; then
    echo "Timed out after 20 s waiting for /sys/class/remoteproc/remoteproc2/state" >&2
    exit 1
fi

if [[ "$(< /sys/class/remoteproc/remoteproc2/state)" != "running" ]]; then
    echo start > /sys/class/remoteproc/remoteproc2/state
fi
