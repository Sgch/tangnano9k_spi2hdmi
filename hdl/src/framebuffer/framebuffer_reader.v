module framebuffer_reader (
    input   wire            i_clk,
    input   wire            i_rst_n,

    input   wire            i_active,
    input   wire            i_hsync,
    input   wire            i_vsync,
    input   wire            i_hblank,
    input   wire            i_vblank,

    output  wire    [15:0]  o_rgb_data,
    output  wire            o_active,
    output  wire            o_hsync,
    output  wire            o_vsync,
    output  wire            o_hblank,
    output  wire            o_vblank,

    // Memory if
    input   wire            i_psram_clk, // i_clk <= i_psram_clk
    output  wire            o_psram_read_req,
    input   wire            i_psram_read_gnt,
    output  wire    [20:0]  o_psram_addr,
    input   wire    [63:0]  i_psram_data,
    input   wire            i_psram_data_valid
);
    parameter H_ACTIVE = 11'd1280;

    parameter PSRAM_BURST = 21'd32;           // PSRAM バースト数
    parameter PSRAM_ADDR = 21'h00_0000;

    localparam PSRAM_READ_COUNT = {10'd0, H_ACTIVE} / PSRAM_BURST;

    // 同期化 Pixel clk => PSRAM clk
    reg [1:0] r_psram_vblank_ff;
    reg [1:0] r_psram_hsync_ff;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_vblank_ff <= 2'b00;
            r_psram_hsync_ff <= 2'b00;
        end
        else begin
            r_psram_vblank_ff <= {r_psram_vblank_ff[0], i_vblank};
            r_psram_hsync_ff <= {r_psram_hsync_ff[0], i_hsync};
        end
    end
    wire w_psram_vblank;
    wire w_psram_hsync;
    assign w_psram_vblank = r_psram_vblank_ff[1];
    assign w_psram_hsync = r_psram_hsync_ff[1];

    // gnt dly
    reg r_gnt_dly, r_gnt_dly2;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_gnt_dly <= 1'b0;
            r_gnt_dly2 <= 1'b0;
        end
        else begin
            r_gnt_dly <= i_psram_read_gnt;
            r_gnt_dly2 <= r_gnt_dly;
        end
    end

    // 有効ラインのhsyncよりpsram読み出しパルス生成
    reg [1:0] r_psram_start_pls_ff;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_start_pls_ff <= 2'b00;
        end
        else begin
            r_psram_start_pls_ff <= {r_psram_start_pls_ff[0], (~w_psram_vblank & w_psram_hsync)};
        end
    end
    wire w_psram_start_pls;
    assign w_psram_start_pls = (r_psram_start_pls_ff == 2'b01);

    // PSRAM読み出しアドレス
    reg [20:0] r_psram_addr;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_addr <= 21'd0;
        end
        else if (w_psram_vblank) begin
            r_psram_addr <= PSRAM_ADDR;
        end
        else if (r_gnt_dly2) begin
            r_psram_addr <= r_psram_addr + PSRAM_BURST;
        end
    end
    assign o_psram_addr = r_psram_addr;

    // PSRAM 1ライン分のカウンタ
    reg [21:0] r_psram_read_count;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_read_count <= 0;
        end
        else if (r_psram_read_count >= PSRAM_READ_COUNT) begin
            r_psram_read_count <= 0;
        end
        else if (r_gnt_dly2) begin
            r_psram_read_count <= r_psram_read_count + 22'd1;
        end
    end

    // PSRAM読み出しリクエスト
    reg r_psram_req;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_req <= 1'b0;
        end
        else if (r_psram_req) begin
            r_psram_req <= 1'b0;
        end
        else if ((w_psram_start_pls || r_gnt_dly2) && (r_psram_read_count < PSRAM_READ_COUNT-1)) begin
            r_psram_req <= 1'b1;
        end
    end
    assign o_psram_read_req = r_psram_req;

    // fifo
    wire [63:0] w_rd_data;
    assign w_rd_data = i_psram_data;
    linebuffer_fifo_hs u_fifo(
		.Data(w_rd_data), //input [63:0] Data
		.WrReset(~i_rst_n), //input WrReset
		.RdReset(~i_rst_n), //input RdReset
		.WrClk(i_psram_clk), //input WrClk
		.RdClk(i_clk), //input RdClk
		.WrEn(i_psram_data_valid), //input WrEn
		.RdEn(i_active), //input RdEn
		.Q(o_rgb_data), //output [15:0] Q
		.Empty(), //output Empty
		.Full() //output Full
	);

    // fifo 読み出し遅延分 syncを遅らせる
    reg [4:0] r_dly;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_dly <= 5'd0;
        end
        else begin
            r_dly <= {i_active, i_hsync, i_vsync, i_hblank, i_vblank};
        end
    end
    assign {o_active, o_hsync, o_vsync, o_hblank, o_vblank} = r_dly;

endmodule