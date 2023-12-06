`timescale 1ns/1ps
module tb_framebuffer_writer;
    reg rst_n;
    wire XTAL27M;
    sim_clkgen #(.FREQ_MHZ(27)) u_clk_27m(.clk(XTAL27M));

    wire psram_mem_clk;
    sim_clkgen #(.FREQ_MHZ(148.5)) u_clk_74m(.clk(psram_mem_clk));

    wire w_spi_sck;
    wire w_spi_cs;
    wire w_spi_mosi;
    sim_spi_st7735r_host #(
        .SCK_MHZ(25)
    ) u_spi_host (
        .o_sck(w_spi_sck),
        .o_mosi(w_spi_mosi),
        .o_cs_n(w_spi_cs),
        .o_dc()
    );

    wire [7:0] w_spi_data;
    wire       w_spi_csreleased;
    wire       w_spi_rxdone;
    spi_slave u_dut_spi_slave(
        .i_clk(XTAL27M),
        .i_rst_n(rst_n),

        .i_spi_clk(w_spi_sck),
        .i_spi_cs(w_spi_cs),
        .i_spi_mosi(w_spi_mosi),

        // output
        .o_data(w_spi_data),
        .o_csreleased(w_spi_csreleased),
        .o_rxdone(w_spi_rxdone)
    );

    wire [31:0] w_col_addr;
    wire [31:0] w_row_addr;
    wire [15:0] w_pixel_data;
    wire w_sram_clr_req;
    wire w_sram_write_req;
    wire w_sram_waddr_set_req;
    inst_dec_reg u_dut_command_dec(
        .i_clk(XTAL27M),
        .i_rst_n(rst_n),

        .i_spi_data(w_spi_data),
        .i_spi_csreleased(w_spi_csreleased),
        .i_spi_rxdone(w_spi_rxdone),

        .o_pixel_data(w_pixel_data),   // 画素データ
        .o_col_addr(w_col_addr),     // XS15:0[31:16], XE15:0[15:0]
        .o_row_addr(w_row_addr),     // YS15:0[31:16], YE15:0[15:0]

        .o_sram_clr_req(w_sram_clr_req),         // SRAM ALLクリアリクエスト
        .o_sram_write_req(w_sram_write_req),       // SRAM画素データ書き込みリクエスト
        .o_sram_waddr_set_req(w_sram_waddr_set_req),   // SRAM書き込みアドレス設定リクエスト
        .o_dispOn()
    );

    wire        w_psram_cmd;
    wire        w_psram_cmd_en;
    wire [20:0] w_psram_addr;
    wire [63:0] w_psram_wr_data;
    wire [ 7:0] w_psram_data_mask;
    wire        w_psram_clk;
    wire        w_psram_init_calib;
    PSRAM_Memory_Interface_HS_Top u_psram(
		.clk(XTAL27M),
		.memory_clk(psram_mem_clk),
		.pll_lock(1'b1),
		.rst_n(rst_n),

		.wr_data(w_psram_wr_data),
		.rd_data(),
		.rd_data_valid(),
		.addr(w_psram_addr),
		.cmd(w_psram_cmd),
		.cmd_en(w_psram_cmd_en),
		.init_calib(w_psram_init_calib),
		.clk_out(w_psram_clk),
		.data_mask(w_psram_data_mask)
	);

    wire        w_write_req;
    wire        w_write_gnt;
    wire [20:0] w_write_addr;
    wire [63:0] w_write_data;
    wire [ 7:0] w_write_mask;
    psram_arb u_psram_arb(
        .i_clk(w_psram_clk),
        .i_rst_n(rst_n),

        .i_write_req(w_write_req),
        .o_write_gnt(w_write_gnt),
        .i_write_addr(w_write_addr),
        .i_write_data(w_write_data),
        .i_write_data_mask(w_write_mask),

        .i_read_req(1'b0),
        .o_read_gnt(),
        .i_read_addr(21'd0),
        .o_read_data(),
        .o_read_data_valid(),

        .i_psram_init_calib(w_psram_init_calib),
        .o_psram_cmd(w_psram_cmd),
        .o_psram_cmd_en(w_psram_cmd_en),
        .o_psram_addr(w_psram_addr),
        .o_psram_wr_data(w_psram_wr_data),
        .o_psram_data_mask(w_psram_data_mask),
        .i_psram_rd_data(64'd0),
        .i_psram_rd_data_valid(1'b0)
    );

    framebuffer_writer u_dut(
        .i_clk(XTAL27M),
        .i_rst_n(rst_n),

        .i_sram_clr_req(w_sram_clr_req),

        .i_col_addr(w_col_addr),
        .i_row_addr(w_row_addr),
        .i_sram_waddr_set_req(w_sram_waddr_set_req),

        .i_pixel_data(w_pixel_data),
        .i_sram_write_req(w_sram_write_req),
        .o_fifo_full(),

        .i_psram_clk(w_psram_clk),
        .i_psram_rst_n(rst_n),
        .o_psram_req(w_write_req),
        .i_psram_gnt(w_write_gnt),
        .o_psram_addr(w_write_addr),
        .o_psram_data(w_write_data),
        .o_psram_data_mask(w_write_mask)
    );

    reg [7:0] w_tmp;
    initial begin
        rst_n = 1'b0;
        #(1000);
        rst_n = 1'b1;

        u_spi_host.send_begin();
            u_spi_host.send_cmd_nop();
            u_spi_host.send_cmd_swreset();
            #(1000);
            u_spi_host.fill_pixels(0, 0, 1279, 0, 16'hffff);
            // #(1000);
            // u_spi_host.fill_pixels(0, 0, 10, 0, 16'hf00f);
        u_spi_host.send_end();
    end

endmodule
