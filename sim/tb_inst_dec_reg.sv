`timescale 1ns/1ps
module tb_inst_dec_reg;
    reg rst_n;
    wire XTAL27M;
    sim_clkgen #(.FREQ_MHZ(27)) u_clk_27m(.clk(XTAL27M));

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

    reg [7:0] w_tmp;
    initial begin
        rst_n = 1'b0;
        #(1000);
        rst_n = 1'b1;

        u_spi_host.send_begin();
            u_spi_host.send_cmd_nop();
            u_spi_host.send_cmd_swreset();
            #(1000);
            u_spi_host.fill_pixels(0, 0, 0, 10, 16'hffff);
            #(1000);
            u_spi_host.fill_pixels(0, 0, 10, 0, 16'hf00f);
        u_spi_host.send_end();
    end

endmodule
