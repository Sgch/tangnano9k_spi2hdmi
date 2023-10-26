set_false_path -from [get_ports {ONB_SW[*]}]
set_false_path -to   [get_ports {ONB_LED[*]}]

# SPI (fsck=16MHz)
create_clock -name spi_clk -period 62.5 -waveform {0 31.25} [get_ports {SPI_SCK}]
set_false_path -from [get_ports {SPI_CS}]

# SPI Data Path
set_false_path -from [get_pins {u_spi_slave/o_data_*/Q}]
set_false_path -from [get_pins {u_spi_slave/r_mosi_8bit_rx_done_*/Q}]
set_false_path -from [get_pins {u_spi_slave/r_cs_hold_*/Q}]