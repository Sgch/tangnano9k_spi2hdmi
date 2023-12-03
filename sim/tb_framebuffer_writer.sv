`timescale 1ns/1ps
module tb_framebuffer_writer;
    reg rst_n;
    wire XTAL27M;
    sim_clkgen #(.FREQ_MHZ(27)) u_clk_27m(.clk(XTAL27M));

    wire psram_clk;
    sim_clkgen #(.FREQ_MHZ(74)) u_clk_74m(.clk(psram_clk));

    wire w_spi_sck;
    wire w_spi_cs;
    wire w_spi_mosi;
    sim_spi_host #(
        .SCK_MHZ(25)
    ) u_spi_host(
        .o_sck(w_spi_sck),
        .o_mosi(w_spi_mosi),
        .i_miso(1'b1), // unused
        .o_cs_n(w_spi_cs)
    );

    wire [7:0] w_spi_data;
    wire       w_spi_dc;
    wire       w_spi_rxdone;
    spi_slave u_spi_slave(
        .i_clk(XTAL27M),
        .i_rst_n(rst_n),

        .i_spi_clk(w_spi_sck),
        .i_spi_cs(w_spi_cs),
        .i_spi_mosi(w_spi_mosi),

        // output
        .o_data(w_spi_data),
        .o_dc(w_spi_dc),
        .o_rxdone(w_spi_rxdone)
    );

    wire [31:0] w_col_addr;
    wire [31:0] w_row_addr;
    wire [15:0] w_pixel_data;
    wire w_sram_clr_req;
    wire w_sram_write_req;
    wire w_sram_waddr_set_req;
    inst_dec_reg u_command_dec(
        .i_clk(XTAL27M),
        .i_rst_n(rst_n),

        .i_spi_data(w_spi_data),
        .i_spi_dc(w_spi_dc),
        .i_spi_rxdone(w_spi_rxdone),

        .o_pixel_data(w_pixel_data),   // 画素データ
        .o_col_addr(w_col_addr),     // XS15:0[31:16], XE15:0[15:0]
        .o_row_addr(w_row_addr),     // YS15:0[31:16], YE15:0[15:0]

        .o_sram_clr_req(w_sram_clr_req),         // SRAM ALLクリアリクエスト
        .o_sram_write_req(w_sram_write_req),       // SRAM画素データ書き込みリクエスト
        .o_sram_waddr_set_req(w_sram_waddr_set_req),   // SRAM書き込みアドレス設定リクエスト
        .o_dispOn(),

        .o_pwm_duty()
    );

    wire w_req;
    reg gnt;
    wire [20:0] w_psram_addr;
    wire [63:0] w_psram_data;
    wire  [7:0] w_psram_data_mask;
    framebuffer_writer u_dut(
        .i_clk(XTAL27M),
        .i_rst_n(rst_n),

        .i_pixel_data(w_pixel_data),   // 画素データ
        .i_col_addr(w_col_addr),     // XS15:0[31:16], XE15:0[15:0]
        .i_row_addr(w_row_addr),     // YS15:0[31:16], YE15:0[15:0]
        .i_sram_clr_req(w_sram_clr_req),
        .i_sram_write_req(w_sram_write_req),
        .i_sram_waddr_set_req(w_sram_waddr_set_req),

        .i_psram_clk(psram_clk),
        .o_psram_addr(w_psram_addr),
        .o_psram_data(w_psram_data),
        .o_psram_data_mask(w_psram_data_mask),
        .o_psram_write_req(w_req),
        .i_psram_write_gnt(gnt)
    );

    always @(posedge psram_clk) begin
        gnt <= w_req;
    end

    initial forever begin
        wait (gnt == 1'b1);
        $display("PSRAM Write: addr=%010x", w_psram_addr);
        for (int i=0; i < 8; i++) begin
            @(posedge psram_clk);
            $display(" [%0d] data=%016x mask=%02x", i, w_psram_data, w_psram_data_mask);
        end
    end

    initial begin
        rst_n = 1'b0;
        #(1000);
        rst_n = 1'b1;

        #(1000);
        write_spi({ 8'h00 }); // NOP
        #(1000);
        write_spi({ 8'h2a, 8'h00, 8'h01, 8'h00, 8'h02 }); // column address set
        #(1000);
        write_spi({ 8'h2b, 8'h00, 8'h01, 8'h00, 8'h02 }); // row address set
        #(1000);
        fill(16'h55aa, 4); // write

        #(1000);
    end

    task fill(input [15:0] color565, input integer len);
    reg [7:0] tmp;
    begin
        u_spi_host.select_cs(0);
        u_spi_host.transact_word(8'h2C, tmp);
        for (int i = 0; len > i; i = i + 1) begin
            u_spi_host.transact_word(color565[15:8], tmp);
            u_spi_host.transact_word(color565[7:0], tmp);
        end
        #(10);
        u_spi_host.release_cs();
    end
    endtask

    task write_spi(input [7:0] data[]);
    reg [7:0] tmp;
    begin
        u_spi_host.select_cs(0);
        $write("Write: ");
        for (int i = 0; $size(data) > i; i = i + 1) begin
            u_spi_host.transact_word(data[i], tmp);
            $write("%x ", data[i]);
        end
        $write("\n");
        #(10);
        u_spi_host.release_cs();
    end
    endtask

endmodule
