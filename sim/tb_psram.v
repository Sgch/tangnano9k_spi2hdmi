`timescale 1ns/1ps
module tb_psram;
    reg rst_n;
    wire w_clk_i;
    sim_clkgen #(.FREQ_MHZ(27)) u_clk_27m(.clk(w_clk_i));

    wire    pll_lock_i = 1'b1;
    wire    memory_clk_i;
    sim_clkgen #(.FREQ_MHZ(148.5)) u_clk_148_5m(.clk(memory_clk_i));
    // pll_psram u_pll_psram (
    //     .reset ( ~rst_n ),       // input reset
    //     .clkin ( w_clk_i ),             // 27MHz
    //     .clkout ( memory_clk_i ),         // 148.5MHz
    //     .lock  ( pll_lock_i )   // output lock
    // );

    reg  [20:0] addr_i;
    reg         addr_en_i;
    reg         cmd_i;
    reg         cmd_en_i;
    reg  [63:0] wr_data_i;
    reg  [ 7:0] data_mask_i;
    wire [63:0] rd_data_o;
    wire        rd_data_valid_o;
    wire        clk_out;
    wire        init_calib_o;
    PSRAM_Memory_Interface_HS_Top u_dut(
		.clk(w_clk_i), //input clk
		.memory_clk(memory_clk_i), //input memory_clk
		.pll_lock(pll_lock_i), //input pll_lock
		.rst_n(rst_n), //input rst_n

		.wr_data(wr_data_i), //input [63:0] wr_data
		.rd_data(rd_data_o), //output [63:0] rd_data
		.rd_data_valid(rd_data_valid_o), //output rd_data_valid
		.addr(addr_i), //input [20:0] addr
		.cmd(cmd_i), //input cmd
		.cmd_en(cmd_en_i), //input cmd_en
		.init_calib(init_calib_o), //output init_calib
		.clk_out(clk_out),
		.data_mask(data_mask_i)
	);

    initial begin
        rst_n = 1'b0;

        cmd_i     = 1'b0;
        cmd_en_i  = 1'b0;
        addr_i    = 21'd0;
        wr_data_i = 64'hzzzz_zzzz_zzzz_zzzz;
        data_mask_i = 8'hzz;

        #(1000);
        rst_n = 1'b1;

        wait (init_calib_o == 1'b1);

        @(posedge clk_out);
        cmd_i    = 1'b1;
        cmd_en_i = 1'b1;
        addr_i   = 21'd0;
        wr_data_i = 64'hfedc_ba98_7654_3210;
        data_mask_i = ~8'b001_0001;

        @(posedge clk_out);
        cmd_i    = 1'b0;
        cmd_en_i = 1'b0;
 	    wr_data_i = 64'h0f0e_0d0c_0b0a_0908;
        // data_mask_i = 8'h32;

        @(posedge clk_out);
 	    wr_data_i = 64'h1716_1514_1312_1110;
        // data_mask_i = 8'h54;

        @(posedge clk_out);
 	    wr_data_i = 64'h1f1e_1d1c_1b1a_1918;
        // data_mask_i = 8'h76;

        @(posedge clk_out);
 	    wr_data_i = 64'h2726_2524_2322_2120;
        // data_mask_i = 8'h98;

        @(posedge clk_out);
 	    wr_data_i = 64'h2f2e_2d2c_2b2a_2928;
        // data_mask_i = 8'hba;

        @(posedge clk_out);
 	    wr_data_i = 64'h3736_3534_3332_3130;
        // data_mask_i = 8'hdc;

        @(posedge clk_out);
 	    wr_data_i = 64'h3f3e_3d3c_3b3a_3938;
        // data_mask_i = 8'hfe;

        @(posedge clk_out);
        wr_data_i = 64'hzzzz_zzzz_zzzz_zzzz;
        // data_mask_i = 8'hzz;

        @(posedge clk_out);
        @(posedge clk_out);
        @(posedge clk_out);
        @(posedge clk_out);
        @(posedge clk_out);
        @(posedge clk_out);
        @(posedge clk_out);
        @(posedge clk_out);
        @(posedge clk_out);
        @(posedge clk_out);

        @(posedge clk_out);
        cmd_i    = 1'b0;
        cmd_en_i = 1'b1;
        addr_i   = 21'd0;
        @(posedge clk_out);
        cmd_en_i = 1'b0;
        @(posedge clk_out);

    end

endmodule
