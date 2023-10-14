`timescale 1ns/1ps
module tb_linebuffer;

    reg rst_n;
    wire clk;
    sim_clkgen tb_clkgen_video( .clk(clk) );

    wire psram_clk;
    sim_clkgen #(.FREQ_MHZ(75)) tb_clkgen_psram( .clk(psram_clk) );

    initial begin
        rst_n = 0;
        #(222);
        rst_n = 1;
    end

    wire    w_de;
    wire    w_hsync;
    wire    w_vsync;
    wire    w_hblank;
    wire    w_vblank;
    syn_gen u_syncgen (
        .I_pxl_clk   (clk     ),//40MHz      //65MHz      //74.25MHz    // 148.5MHz
        .I_rst_n     (rst_n   ),//800x600    //1024x768   //1280x720    // 1920x1080
        .I_h_total   (16'd1650),// 16'd1056  // 16'd1344  // 16'd1650   // 16'd2200
        .I_h_sync    (16'd40  ),// 16'd128   // 16'd136   // 16'd40     // 16'd44
        .I_h_bporch  (16'd220 ),// 16'd88    // 16'd160   // 16'd220    // 16'd148
        .I_h_res     (16'd1280),// 16'd800   // 16'd1024  // 16'd1280   // 16'd1920
        .I_v_total   (16'd750 ),// 16'd628   // 16'd806   // 16'd750    // 16'd1125
        .I_v_sync    (16'd5   ),// 16'd4     // 16'd6     // 16'd5      // 16'd5
        .I_v_bporch  (16'd20  ),// 16'd23    // 16'd29    // 16'd20     // 16'd36
        .I_v_res     (16'd720 ),// 16'd600   // 16'd768   // 16'd720    // 16'd1080
        .I_hs_pol    (1'b1    ),// HS polarity, 0:Neg, 1:Pos
        .I_vs_pol    (1'b1    ),// VS polarity, 0:Neg, 1:Pos
        .O_de        (w_de    ),
        .O_hs        (w_hsync ),
        .O_vs        (w_vsync ),
        .O_hb        (w_hblank),
        .O_vb        (w_vblank)
    );

    wire        w_busy;
    wire        w_cmd_en;
    wire [63:0] w_psram_data;
    wire        w_psram_data_valid;
    wire        w_done;
    moc_psram u_moc_psram(
        .i_clk(psram_clk),
        .i_rst_n(rst_n),

        .i_cmd_en(w_cmd_en),
        .o_rd_data(w_psram_data),
        .o_rd_data_valid(w_psram_data_valid),
        .o_busy(w_busy),
        .o_done(w_done)
    );

    framebuffer_reader u_dut(
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_hsync(w_hsync),
        .i_vsync(w_vsync),
        .i_hblank(w_hblank),
        .i_vblank(w_vblank),
        .i_active(w_de),
        .o_rgb_data(),
        .o_hsync(),
        .o_vsync(),
        .o_hblank(),
        .o_vblank(),
        .o_active(),

    // Memory if
        .i_psram_clk(psram_clk),
        .i_psram_busy(w_busy),
        .o_psram_req(w_cmd_en),
        .o_psram_addr(),
        .i_psram_data(w_psram_data),
        .i_psram_data_valid(w_psram_data_valid),
        .i_psram_done(w_done)
    );

endmodule

module moc_psram(
    input   wire            i_clk,
    input   wire            i_rst_n,

    input   wire            i_cmd_en,
    output  wire    [63:0]  o_rd_data,
    output  wire            o_rd_data_valid,
    output  wire            o_busy,
    output  wire            o_done
);
    localparam TCMD = 19;
    localparam READ_T = 17;

    reg [63:0] r_data;
    reg        r_data_valid;
    integer tcmd_count;
    integer read_count;
    initial begin
        r_data       = 64'hxxxx_xxxx_xxxx_xxxx;
        r_data_valid = 1'b0;
        tcmd_count = 0;
        read_count = 0;
    end

    always @(posedge i_clk) begin
        if (tcmd_count != 0 && i_cmd_en) begin
            $warning("tcmd!!!!");
        end
    end

    always @(posedge i_clk) begin
        if (i_cmd_en) begin
            tcmd_count <= 1;
        end
        else if (tcmd_count >= TCMD) begin
            tcmd_count <= 0;
        end
        else if (tcmd_count > 0) begin
            tcmd_count <= tcmd_count + 1;
        end
    end

    assign o_busy = (tcmd_count != 0);
    assign o_done = (tcmd_count == TCMD);


    always @(posedge i_clk) begin
        if (tcmd_count == READ_T-1) begin
            read_count <= 1;
        end
        else if (read_count >= 8) begin
            read_count <= 0;
        end
        else if (read_count > 0) begin
            read_count <= read_count + 1;
        end
    end
    assign o_rd_data_valid = (read_count != 0);

    assign o_rd_data = (read_count !=0) ? {$random(), $random()} : 64'h0000_0000_0000_0000;

endmodule

