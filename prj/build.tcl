set HDL_DIR ../hdl
set IP_DIR  ${HDL_DIR}/ip
set SRC_DIR ${HDL_DIR}/src

set_option -output_base_name spilcd-to-hdmi
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5

set_option -print_all_synthesis_warning 1

set_option -top_module top

set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1

add_file -type verilog [file normalize ${IP_DIR}/dvi_tx/dvi_tx.v]
add_file -type verilog [file normalize ${IP_DIR}/linebuffer_fifo_hs/linebuffer_fifo_hs.v]
add_file -type verilog [file normalize ${IP_DIR}/psram_memory_interface_hs/psram_memory_interface_hs.v]
add_file -type verilog [file normalize ${IP_DIR}/sram_write_fifo_hs/sram_write_fifo_hs.v]
add_file -type verilog [file normalize ${IP_DIR}/dvi_rpll/dvi_rpll.v]
add_file -type verilog [file normalize ${IP_DIR}/psram_rpll/psram_rpll.v]

add_file -type verilog [file normalize ${SRC_DIR}/framebuffer/framebuffer_reader.v]
add_file -type verilog [file normalize ${SRC_DIR}/framebuffer/framebuffer_writer.v]
add_file -type verilog [file normalize ${SRC_DIR}/framebuffer/fifo_writer.v]
add_file -type verilog [file normalize ${SRC_DIR}/framebuffer/packer.v]

add_file -type verilog [file normalize ${SRC_DIR}/spi/inst_dec_reg.v]
add_file -type verilog [file normalize ${SRC_DIR}/spi/spi_slave.v]

add_file -type verilog [file normalize ${SRC_DIR}/psram_arb.v]
add_file -type verilog [file normalize ${SRC_DIR}/syn_gen.v]
add_file -type verilog [file normalize ${SRC_DIR}/top.v]

add_file -type cst [file normalize ${HDL_DIR}/top.cst]
add_file -type sdc [file normalize ${HDL_DIR}/top.sdc]

run all