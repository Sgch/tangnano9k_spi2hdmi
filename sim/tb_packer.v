`timescale 1ns/1ps
module tb_packer;
    reg rst_n;
    wire clk;
    sim_clkgen tb_clkgen_video( .clk(clk) );

    reg [4:0]   index_start;
    reg [4:0]   index_end;
    reg         start;
    reg [15:0]  data;
    reg [15:0]  data_q;
    wire        data_read;
    wire        done;
    wire        req;
    reg         gnt;
    packer u_packer(
        .i_clk(clk),
        .i_rst_n(rst_n),

        .i_start_index(index_start), // set before data_write assrted
        .i_end_index(index_end),   // set before data_write assrted

        .i_start(start),
        .o_done(done),

        .o_data_read(data_read),
        .i_data(data_q),

        .o_psram_write_req(req),
        .i_psram_write_gnt(gnt),
        .o_psram_data(),
        .o_psram_data_mask()
    );


    always @(posedge clk) begin
        data_q <= data;
    end

    always @(posedge clk) begin
        // gnt <= #(1000) req;
        gnt <= req;
    end
    event evt;
    integer i;
    initial begin
        rst_n = 0;
        index_start = 5'd1;
        index_end   = 5'd27;
        start = 1'b0;
        data = 16'hxxxx;
        #(222);
        rst_n = 1;

        @(posedge clk);
        start = 1;

        @(posedge clk);
        start = 0;
        for (i=0; i < (index_end - index_start)+1; i = i + 1) begin
            wait (data_read == 1'b1);
            data = {i[7:0]+i[7:0]+8'd1, i[7:0]+i[7:0] };
            @(posedge clk);
        end
        data = 16'hxxxx;

        wait (done == 1);
        @(posedge clk);

        // output ram
        $write("RAM0: ");
        for (i=0; i < 8; i = i + 1) begin
            $write("%04x ", u_packer.r_data_ram_0[i]);
        end
        $display("");

        $write("RAM1: ");
        for (i=0; i < 8; i = i + 1) begin
            $write("%04x ", u_packer.r_data_ram_1[i]);
        end
        $display("");

        $write("RAM2: ");
        for (i=0; i < 8; i = i + 1) begin
            $write("%04x ", u_packer.r_data_ram_2[i]);
        end
        $display("");

        $write("RAM3: ");
        for (i=0; i < 8; i = i + 1) begin
            $write("%04x ", u_packer.r_data_ram_3[i]);
        end
        $display("");

        $write("VALI: ");
        for (i=0; i < 8; i = i + 1) begin
            $write("%02x   ", u_packer.r_valid_ram[i]);
        end
        $display("");

        @(posedge clk);

    end

endmodule
