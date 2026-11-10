# sclk -> 1_P
set_property PACKAGE_PIN H16 [get_ports spi_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports spi_sclk]
set_false_path -from [get_ports spi_sclk]
# mosi -> 1_N
set_property PACKAGE_PIN H17 [get_ports spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi]
set_false_path -from [get_ports spi_mosi]
# miso -> 2_P
set_property PACKAGE_PIN J18 [get_ports spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]
set_false_path -to [get_ports spi_miso]
set_property SLEW SLOW [get_ports spi_miso]
set_property DRIVE 4 [get_ports spi_miso]
# cs -> 2_N
set_property PACKAGE_PIN H18 [get_ports spi_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports spi_cs_n]
set_property PULLUP TRUE [get_ports spi_cs_n]
set_false_path -from [get_ports spi_cs_n]
# drdy -> 3_P
set_property PACKAGE_PIN K17 [get_ports drdy]
set_property IOSTANDARD LVCMOS33 [get_ports drdy]
set_false_path -to [get_ports drdy]
set_property SLEW SLOW [get_ports drdy]
set_property DRIVE 4 [get_ports drdy]
# D2 -> 5_P
set_property PACKAGE_PIN L16 [get_ports cam_d2]
set_property IOSTANDARD LVCMOS33 [get_ports cam_d2]
set_property IOB TRUE [get_ports cam_d2]
set_false_path -from [get_ports cam_d2]
# D3 -> 5_N
set_property PACKAGE_PIN L17 [get_ports cam_d3]
set_property IOSTANDARD LVCMOS33 [get_ports cam_d3]
set_property IOB TRUE [get_ports cam_d3]
set_false_path -from [get_ports cam_d3]
# D4 -> 6_P
set_property PACKAGE_PIN K16 [get_ports cam_d4]
set_property IOSTANDARD LVCMOS33 [get_ports cam_d4]
set_property IOB TRUE [get_ports cam_d4]
set_false_path -from [get_ports cam_d4]
# D5 -> 6_N
set_property PACKAGE_PIN J16 [get_ports cam_d5]
set_property IOSTANDARD LVCMOS33 [get_ports cam_d5]
set_property IOB TRUE [get_ports cam_d5]
set_false_path -from [get_ports cam_d5]
# D6 -> 7_P
set_property PACKAGE_PIN M14 [get_ports cam_d6]
set_property IOSTANDARD LVCMOS33 [get_ports cam_d6]
set_property IOB TRUE [get_ports cam_d6]
set_false_path -from [get_ports cam_d6]
# D7 -> 7_N
set_property PACKAGE_PIN M15 [get_ports cam_d7]
set_property IOSTANDARD LVCMOS33 [get_ports cam_d7]
set_property IOB TRUE [get_ports cam_d7]
set_false_path -from [get_ports cam_d7]
# D8 -> 8_P
set_property PACKAGE_PIN Y9 [get_ports cam_d8]
set_property IOSTANDARD LVCMOS33 [get_ports cam_d8]
set_property IOB TRUE [get_ports cam_d8]
set_false_path -from [get_ports cam_d8]
# D9 -> 8_N
set_property PACKAGE_PIN Y8 [get_ports cam_d9]
set_property IOSTANDARD LVCMOS33 [get_ports cam_d9]
set_property IOB TRUE [get_ports cam_d9]
set_false_path -from [get_ports cam_d9]
# VS -> 9_P
set_property PACKAGE_PIN Y12 [get_ports cam_vs]
set_property IOSTANDARD LVCMOS33 [get_ports cam_vs]
set_property IOB TRUE [get_ports cam_vs]
set_false_path -from [get_ports cam_vs]
# HS -> 9_N
set_property PACKAGE_PIN Y13 [get_ports cam_hs]
set_property IOSTANDARD LVCMOS33 [get_ports cam_hs]
set_property IOB TRUE [get_ports cam_hs]
set_false_path -from [get_ports cam_hs]
# PC -> 10_P
set_property PACKAGE_PIN Y7 [get_ports cam_pc]
set_property IOSTANDARD LVCMOS33 [get_ports cam_pc]
set_property IOB TRUE [get_ports cam_pc]
set_false_path -from [get_ports cam_pc]
# led
set_property PACKAGE_PIN F16 [get_ports led_o]
set_property IOSTANDARD LVCMOS33 [get_ports led_o]
set_property SLEW SLOW [get_ports led_o]
set_property DRIVE 4 [get_ports led_o]
