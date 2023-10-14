`timescale 1ns/1ps
module tb_psram_arb;
    reg rst_n;
    wire clk;
    sim_clkgen tb_clkgen( .clk(clk) );

    reg r_read_req;
    reg r_write_req;
    wire w_write_gnt;
    wire w_read_gnt;
    psram_arb u_dut(
        .i_clk(clk),
        .i_rst_n(rst_n),

    // PSRAM IF
        .o_psram_addr(),
        .o_psram_cmd(),
        .o_psram_cmd_en(),
        .o_psram_wr_data(),
        .o_psram_data_mask(),
        .i_psram_rd_data(),
        .i_psram_rd_data_valid(),
        .i_psram_init_calib(1'b1),

    // Read
        .i_read_req(r_read_req),
        .o_read_gnt(w_read_gnt),
        .i_read_addr(),
        .o_read_data(),
        .o_read_data_valid(),

    // Write
        .i_write_req(r_write_req),
        .o_write_gnt(w_write_gnt),
        .i_write_addr(),
        .i_write_data(),
        .i_write_data_mask(),

        .o_busy()
    );

    initial begin
        rst_n = 0;
        r_read_req = 0;
        r_write_req = 0;

        #(222);
        rst_n = 1;

        // 競合状態
        // Read => Write => Read => Write => ... と繰り返しリクエストが発生する(Read優先)
        @(posedge clk);
        r_read_req = 1;
        r_write_req = 1;

        // Read中にRead
        // Read => Read => ... と繰り返しリクエストが発生する
        //@(posedge clk);
        //r_read_req = 1;

        // Write中にWrite
        // Write => Write => ... と繰り返しリクエストが発生する
        // @(posedge clk);
        // r_write_req = 1;

        // Read中にWrite
        // Read => Write とリクエストが発生
        // @(posedge clk);
        // r_read_req = 1;
        // @(posedge clk);
        // r_read_req = 0;

        // @(posedge clk);
        // r_write_req = 1;
        // @(posedge clk);
        // r_write_req = 0;

        // Write中にRead
        // Write => Read とリクエストが発生
        // @(posedge clk);
        // r_write_req = 1;
        // @(posedge clk);
        // r_write_req = 0;

        // @(posedge clk);
        // r_read_req = 1;
        // @(posedge clk);
        // r_read_req = 0;

    end


endmodule
