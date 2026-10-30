#!/bin/bash

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
echo high | sudo tee /sys/class/gpio/gpio23/direction

# release camera de
config-pin P8_30 gpio
echo low | sudo tee /sys/class/gpio/gpio89/direction

# run init script
python3 ov5640_init.py
