module top(
    input   wire            XTAL27M,
    input   wire    [1:0]   ONB_SW,
    output  wire    [5:0]   ONB_LED,

    input   wire            SPI_SCK,
    input   wire            SPI_MOSI,
    input   wire            SPI_CS,

    output  wire            TMDS_CLK_P,
    output  wire            TMDS_CLK_N,
    output  wire    [2:0]   TMDS_DATA_P,
    output  wire    [2:0]   TMDS_DATA_N,

    output  wire    [CS_WIDTH-1:0]  O_psram_ck,       // Magic ports for PSRAM to be inferred
    output  wire    [CS_WIDTH-1:0]  O_psram_ck_n,
    inout   wire    [CS_WIDTH-1:0]  IO_psram_rwds,
    inout   wire    [DQ_WIDTH-1:0]  IO_psram_dq,
    output  wire    [CS_WIDTH-1:0]  O_psram_reset_n,
    output  wire    [CS_WIDTH-1:0]  O_psram_cs_n
);
    localparam  DQ_WIDTH = 16;
    localparam  CS_WIDTH = 2;

    wire w_rst_n;
    assign w_rst_n = ONB_SW[0];

    //assign ONB_LED = 6'b111111;

    wire w_dvitx_clk;
    wire w_pll_dvitx_locked;
    dvi_rpll u_rpll_dvitx(
        .clkout(w_dvitx_clk),
        .lock(w_pll_dvitx_locked),
        .reset(~w_rst_n),
        .clkin(XTAL27M)
    );

    wire w_psram_clk;
    // CLKDIV u_clkdiv_pixel_clk (
    //     .CLKOUT(w_psram_clk),
    //     .HCLKIN(w_dvitx_clk),
    //     .RESETN(w_rst_n),
    //     .CALIB(1'b0)
    // );
    // defparam u_clkdiv_pixel_clk.DIV_MODE = "5";
    // defparam u_clkdiv_pixel_clk.GSREN = "false";

    wire w_memory_clk;
    wire w_memory_clk_locked;
    psram_rPLL u_rpll_psram(
        .clkout(w_memory_clk), //output clkout
        .lock(w_memory_clk_locked), //output lock
        .reset(~w_rst_n), //input reset
        .clkin(XTAL27M) //input clkin
    );
    // assign w_psram_clk = w_psram_clk;

    wire [7:0] w_spi_data;
    wire       w_spi_csrelased;
    wire       w_spi_rxdone;
    spi_slave u_spi_slave(
        .i_clk(XTAL27M),
        .i_rst_n(w_rst_n),

        .i_spi_clk(SPI_SCK),
        .i_spi_cs(SPI_CS),
        .i_spi_mosi(SPI_MOSI),

        // output
        .o_data(w_spi_data),
        .o_csreleased(w_spi_csrelased),
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
        .i_rst_n(w_rst_n),

        .i_spi_data(w_spi_data),
        .i_spi_csreleased(w_spi_csrelased),
        .i_spi_rxdone(w_spi_rxdone),

        .o_pixel_data(w_pixel_data),   // 画素データ
        .o_col_addr(w_col_addr),     // XS15:0[31:16], XE15:0[15:0]
        .o_row_addr(w_row_addr),     // YS15:0[31:16], YE15:0[15:0]

        .o_sram_clr_req(w_sram_clr_req),         // SRAM ALLクリアリクエスト
        .o_sram_write_req(w_sram_write_req),       // SRAM画素データ書き込みリクエスト
        .o_sram_waddr_set_req(w_sram_waddr_set_req),   // SRAM書き込みアドレス設定リクエスト
        .o_dispOn()
    );

    wire        w_fb_write_req;
    wire        w_fb_write_gnt;
    wire [20:0] w_fb_write_addr;
    wire [63:0] w_fb_write_data;
    wire  [7:0] w_fb_write_data_mask;
    wire        w_fb_write_fifo_full;
    framebuffer_writer u_writer(
        .i_clk(XTAL27M),
        .i_rst_n(w_rst_n),

        .i_pixel_data(w_pixel_data),   // 画素データ
        .i_col_addr(w_col_addr),     // XS15:0[31:16], XE15:0[15:0]
        .i_row_addr(w_row_addr),     // YS15:0[31:16], YE15:0[15:0]
        .i_sram_clr_req(w_sram_clr_req),
        .i_sram_write_req(w_sram_write_req),
        .i_sram_waddr_set_req(w_sram_waddr_set_req),
        .o_fifo_full(w_fb_write_fifo_full),

        .i_psram_clk(w_psram_clk),
        .i_psram_rst_n(w_rst_n),
        .o_psram_addr(w_fb_write_addr),
        .o_psram_data(w_fb_write_data),
        .o_psram_data_mask(w_fb_write_data_mask),
        .o_psram_req(w_fb_write_req),
        .i_psram_gnt(w_fb_write_gnt)
    );

    wire        w_psram_cmd;
    wire        w_psram_cmd_en;
    wire [20:0] w_psram_addr;
    wire [63:0] w_psram_wr_data;
    wire [ 7:0] w_psram_data_mask;
    wire [63:0] w_psram_rd_data;
    wire        w_psram_rd_data_valid;
    wire        w_psram_init_calib;
    PSRAM_Memory_Interface_HS_Top u_psram(
        .clk(XTAL27M),
        .memory_clk(w_memory_clk),
        .pll_lock(w_memory_clk_locked),
        .rst_n(w_rst_n),
        .O_psram_ck ( O_psram_ck ),         // output [1:0] O_psram_ck
        .O_psram_ck_n ( O_psram_ck_n ),     // output [1:0] O_psram_ck_n
        .IO_psram_dq ( IO_psram_dq ),       // inout [15:0] IO_psram_dq
        .IO_psram_rwds ( IO_psram_rwds ),   // inout [1:0] IO_psram_rwds
        .O_psram_cs_n ( O_psram_cs_n ),     // output [1:0] O_psram_cs_n
        .O_psram_reset_n ( O_psram_reset_n ), // output [1:0] O_psram_reset_n

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

    wire        w_fb_read_req;
    wire        w_fb_read_gnt;
    wire [20:0] w_fb_read_addr;
    wire [63:0] w_fb_read_data;
    wire        w_fb_read_data_valid;
    psram_arb u_psram_arb(
        .i_clk(w_psram_clk),
        .i_rst_n(w_rst_n),

    // PSRAM IF
        .o_psram_addr(w_psram_addr),
        .o_psram_cmd(w_psram_cmd),
        .o_psram_cmd_en(w_psram_cmd_en),
        .o_psram_wr_data(w_psram_wr_data),
        .o_psram_data_mask(w_psram_data_mask),
        .i_psram_rd_data(w_psram_rd_data),
        .i_psram_rd_data_valid(w_psram_rd_data_valid),
        .i_psram_init_calib(w_psram_init_calib),

    // Read
        .i_read_req(w_fb_read_req),
        .o_read_gnt(w_fb_read_gnt),
        .i_read_addr(w_fb_read_addr),
        .o_read_data(w_fb_read_data),
        .o_read_data_valid(w_fb_read_data_valid),

    // Write
        .i_write_req(w_fb_write_req),
        .o_write_gnt(w_fb_write_gnt),
        .i_write_addr(w_fb_write_addr),
        .i_write_data(w_fb_write_data),
        .i_write_data_mask(w_fb_write_data_mask)
    );

    wire    w_out_de;
    wire    w_hsync;
    wire    w_vsync;
    syn_gen u_syn_gen (
        .I_pxl_clk   (w_psram_clk ),//40MHz      //65MHz      //74.25MHz    // 148.5MHz
        .I_rst_n     (w_rst_n    ),//800x600    //1024x768   //1280x720    // 1920x1080
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
        .I_rd_hres   (16'd0),
        .I_rd_vres   (16'd0),
        .O_rden      ()
    );

    wire [15:0] w_fb_reader_rgb565;
    wire w_fb_reader_hsync;
    wire w_fb_reader_vsync;
    wire w_fb_reader_vde;
    framebuffer_reader u_reader (
        .i_psram_clk(w_psram_clk),
        .i_psram_rst_n(w_rst_n),

        .i_video_clk(w_psram_clk),
        .i_video_rst_n(w_rst_n),
        .i_video_active(w_out_de),
        .i_video_hsync(w_hsync),
        .i_video_vsync(w_vsync),

        .o_video_data(w_fb_reader_rgb565),
        .o_video_active(w_fb_reader_vde),
        .o_video_hsync(w_fb_reader_hsync),
        .o_video_vsync(w_fb_reader_vsync),

        .i_reg_width(11'd1280),
        .i_reg_start_line(11'd20),
        .i_reg_end_line(11'd20 + 11'd720),

    // Memory if
        .o_psram_req(w_fb_read_req),
        .i_psram_gnt(w_fb_read_gnt),
        .o_psram_addr(w_fb_read_addr),
        .i_psram_data(w_fb_read_data),
        .i_psram_data_valid(w_fb_read_data_valid)
    );

    wire [23:0] w_rgb_data;
    assign w_rgb_data = {{w_fb_reader_rgb565[15:11], 3'b000}, {w_fb_reader_rgb565[10:5], 2'b00}, {w_fb_reader_rgb565[4:0], 3'b000}};
    DVI_TX_Top u_dvi_tx(
		.I_rst_n(w_rst_n),
		.I_serial_clk(w_dvitx_clk),
		.I_rgb_clk(w_psram_clk),

		.I_rgb_vs(w_fb_reader_vsync),
		.I_rgb_hs(w_fb_reader_hsync),
		.I_rgb_de(w_fb_reader_vde),
		.I_rgb_r(w_rgb_data[23:16]),
		.I_rgb_g(w_rgb_data[15: 8]),
		.I_rgb_b(w_rgb_data[ 7: 0]),

		.O_tmds_clk_p(TMDS_CLK_P),
		.O_tmds_clk_n(TMDS_CLK_N),
		.O_tmds_data_p(TMDS_DATA_P),
		.O_tmds_data_n(TMDS_DATA_N)
	);
    assign ONB_LED[0] = (w_pll_dvitx_locked & w_memory_clk_locked);
    assign ONB_LED[1] = ~w_sram_write_req;
    assign ONB_LED[2] = ~w_fb_write_gnt;
    assign ONB_LED[3] = ~w_fb_write_fifo_full;
    assign ONB_LED[4] = ~w_fb_read_gnt;
    assign ONB_LED[5] = 1'b1;


endmodule