`timescale 1ns/1ps
module tb_syn_gen;
    reg rst_n;

    wire clk;
    sim_clkgen sim_clk( .clk(clk) );

    wire    w_de;
    wire    w_hsync;
    wire    w_vsync;
    syn_gen u_dut (
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
        .O_vs        (w_vsync )
    );

    initial begin
        rst_n = 0;
        #(199);
        rst_n = 1;
    end
endmodule
