`timescale 1ns/1ps
module tb_psram_arb;
    reg r_rst_n;

    wire w_clk;
    sim_clkgen #(.FREQ_MHZ(27)) u_clkgen(w_clk);

    wire w_mem_clk;
    sim_clkgen #(.FREQ_MHZ(148.5)) u_clkgen_mem(w_mem_clk);

    wire        w_psram_clk;
    wire        w_psram_cmd;
    wire        w_psram_cmd_en;
    wire [20:0] w_psram_addr;
    wire [63:0] w_psram_wr_data;
    wire [ 7:0] w_psram_data_mask;
    wire [63:0] w_psram_rd_data;
    wire        w_psram_rd_data_valid;
    wire        w_psram_init_calib;
    PSRAM_Memory_Interface_HS_Top u_psram_if(
        .clk(w_clk),
        .memory_clk(w_mem_clk),
        .pll_lock(1'b1),
        .rst_n(r_rst_n),
        .wr_data(w_psram_wr_data),
        .addr(w_psram_addr),
        .cmd(w_psram_cmd),
        .cmd_en(w_psram_cmd_en),
        .data_mask(w_psram_data_mask),
        .rd_data(w_psram_rd_data),
        .rd_data_valid(w_psram_rd_data_valid),
        .init_calib(w_psram_init_calib),
        .clk_out(w_psram_clk)
    );

    reg  r_write_req;
    wire w_write_gnt;
    reg  r_read_req;
    wire w_read_gnt;
    psram_arb u_dut(
        .i_clk(w_psram_clk),
        .i_rst_n(r_rst_n),

        .i_write_req(r_write_req),
        .o_write_gnt(w_write_gnt),
        .i_write_addr(21'd12345),
        .i_write_data(64'h0123_4567_89ab_cdef),
        .i_write_data_mask(8'h5a),

        .i_read_req(r_read_req),
        .o_read_gnt(w_read_gnt),
        .i_read_addr(),
        .o_read_data(),
        .o_read_data_valid(),

        .i_psram_init_calib(w_psram_init_calib),
        .o_psram_cmd(w_psram_cmd),
        .o_psram_cmd_en(w_psram_cmd_en),
        .o_psram_addr(w_psram_addr),
        .o_psram_wr_data(w_psram_wr_data),
        .o_psram_data_mask(w_psram_data_mask),
        .i_psram_rd_data(w_psram_rd_data),
        .i_psram_rd_data_valid(w_psram_rd_data_valid)
    );

    initial begin
        r_rst_n = 1'b0;

        r_write_req = 1'b0;
        r_read_req  = 1'b0;
        #1234;

        r_rst_n = 1'b1;

        //wait (w_psram_init_calib == 1'b1);
        #1000;

        @(posedge w_psram_clk);
        r_read_req = 1'b1;
        r_write_req = 1'b1;
        wait (w_read_gnt == 1'b1);
        @(posedge w_psram_clk);
        r_read_req = 1'b0;

        wait (w_write_gnt == 1'b1);
        @(posedge w_psram_clk);
        //r_write_req = 1'b0;

        @(posedge w_psram_clk);

        r_read_req = 1'b1;
        wait (w_read_gnt == 1'b1);
        @(posedge w_psram_clk);
        r_read_req = 1'b0;
    end

endmodule
