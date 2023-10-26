`timescale 1ns/1ps
module tb_framebuffer_reader;

    reg r_rst_n;

    wire w_clk;
    sim_clkgen #(.FREQ_MHZ(27)) u_clkgen(w_clk);

    wire w_pixel_clk;
    sim_clkgen #(.FREQ_MHZ(74.25)) u_clkgen_pixel (w_pixel_clk);

    wire w_mem_clk;
    sim_clkgen #(.FREQ_MHZ(120)) u_clkgen_mem (w_mem_clk);

    wire    w_out_de;
    wire    w_hsync;
    wire    w_vsync;
    wire    w_hblank;
    wire    w_vblank;
    syn_gen u_syn_gen (
        .I_pxl_clk   (w_pixel_clk ),//40MHz      //65MHz      //74.25MHz    // 148.5MHz
        .I_rst_n     (r_rst_n    ),//800x600    //1024x768   //1280x720    // 1920x1080
        .I_h_total   (16'd1650        ),// 16'd1056  // 16'd1344  // 16'd1650   // 16'd2200
        .I_h_sync    (16'd40          ),// 16'd128   // 16'd136   // 16'd40     // 16'd44
        .I_h_bporch  (16'd220         ),// 16'd88    // 16'd160   // 16'd220    // 16'd148
        .I_h_res     (16'd1280        ),// 16'd800   // 16'd1024  // 16'd1280   // 16'd1920
        .I_v_total   (16'd750         ),// 16'd628   // 16'd806   // 16'd750    // 16'd1125
        .I_v_sync    (16'd5           ),// 16'd4     // 16'd6     // 16'd5      // 16'd5
        .I_v_bporch  (16'd20          ),// 16'd23    // 16'd29    // 16'd20     // 16'd36
        .I_v_res     (16'd720         ),// 16'd600   // 16'd768   // 16'd720    // 16'd1080
        .I_hs_pol    (1'b1            ),// HS polarity, 0:Neg, 1:Pos
        .I_vs_pol    (1'b1            ),// VS polarity, 0:Neg, 1:Pos
        .O_de        (w_out_de        ),
        .O_hs        (w_hsync         ),// deアサート中にはアサートされない？
        .O_vs        (w_vsync         ),
        .O_hb(w_hblank),
        .O_vb(w_vblank)
    );

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

    wire        w_psram_read_req;
    wire        w_psram_read_gnt;
    wire [20:0] w_psram_read_addr;
    wire [63:0] w_psram_read_data;
    wire        w_psram_read_data_valid;
    psram_arb u_psram_arb(
        .i_clk(w_psram_clk),
        .i_rst_n(r_rst_n),

        .i_write_req(1'b0),
        .o_write_gnt(),
        .i_write_addr(21'd12345),
        .i_write_data(64'h0123_4567_89ab_cdef),
        .i_write_data_mask(8'h5a),

        .i_read_req(w_psram_read_req),
        .o_read_gnt(w_psram_read_gnt),
        .i_read_addr(w_psram_read_addr),
        .o_read_data(w_psram_read_data),
        .o_read_data_valid(w_psram_read_data_valid),

        .i_psram_init_calib(w_psram_init_calib),
        .o_psram_cmd(w_psram_cmd),
        .o_psram_cmd_en(w_psram_cmd_en),
        .o_psram_addr(w_psram_addr),
        .o_psram_wr_data(w_psram_wr_data),
        .o_psram_data_mask(w_psram_data_mask),
        .i_psram_rd_data(w_psram_rd_data),
        .i_psram_rd_data_valid(w_psram_rd_data_valid)
    );


    framebuffer_reader u_dut(
        .i_clk(w_psram_clk),
        .i_rst_n(r_rst_n),

    // Registers
        .i_reg_width(11'd1280),
        .i_reg_end_line(11'd20 + 11'd720),
        .i_reg_start_line(11'd20),

    // PSARM
        .o_psram_cmd_req(w_psram_read_req),
        .i_psram_cmd_gnt(w_psram_read_gnt),
        .o_psram_addr(w_psram_read_addr),
        .i_psram_rd_data(64'h0123_4567_89ab_cdef/*w_psram_read_data*/),
        .i_psram_rd_data_valid(w_psram_read_data_valid),

    // Video sync in
        .i_pixel_clk(w_pixel_clk),
        .i_pixel_rst_n(r_rst_n),
        .i_hsync(w_hsync),
        .i_vsync(w_vsync),
        .i_active(w_out_de),

    // Video sync/data out
        .o_rgb_data(),
        .o_hsync(),
        .o_vsync(),
        .o_active()
);

    initial begin
        r_rst_n = 1'b0;
        #(1000);
        r_rst_n = 1'b1;
    end


endmodule