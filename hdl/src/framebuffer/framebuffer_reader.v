module framebuffer_reader (
    // Registers
    input   wire    [10:0]  i_reg_width,       // 横有効ピクセル(Max 2048, 32 align)
    input   wire    [10:0]  i_reg_start_line,  // 読み取り開始ライン(-1)
    input   wire    [10:0]  i_reg_end_line,    // 読み取り終了ライン(-1)

    // PSRAM domain
    input   wire            i_psram_clk,
    input   wire            i_psram_rst_n,

    output  wire            o_psram_req,
    input   wire            i_psram_gnt,
    output  wire    [20:0]  o_psram_addr,
    input   wire    [63:0]  i_psram_data,
    input   wire            i_psram_data_valid,

    // Video domain
    input   wire            i_video_clk,
    input   wire            i_video_rst_n,

    input   wire            i_video_hsync,
    input   wire            i_video_vsync,
    input   wire            i_video_active,

    output  wire            o_video_hsync,
    output  wire            o_video_vsync,
    output  wire            o_video_active,
    output  wire    [15:0]  o_video_data
);

    reg [2:0] r_sync_hsync;
    reg [2:0] r_sync_vsync;
    always @(posedge i_psram_clk) begin
        r_sync_hsync <= { r_sync_hsync[1:0], i_video_hsync };
        r_sync_vsync <= { r_sync_vsync[1:0], i_video_vsync };
    end

    wire   w_hsync_pls;
    assign w_hsync_pls = (r_sync_hsync[2:1] == 2'b01);
    wire   w_vsync_pls;
    assign w_vsync_pls = (r_sync_vsync[2:1] == 2'b01);
    wire   w_vsync;
    assign w_vsync = r_sync_vsync[1];

    // 読み出しラインカウント
    reg [10:0] r_line_cnt;
    always @(posedge i_psram_clk or negedge i_psram_rst_n) begin
        if (!i_psram_rst_n) begin
            r_line_cnt <= 11'd0;
        end
        else if (w_vsync) begin
            r_line_cnt <= 11'd0;
        end
        else if (w_hsync_pls) begin
            r_line_cnt <= r_line_cnt + 11'd1;
        end
    end
    wire   w_read_line;
    assign w_read_line = (r_line_cnt >= i_reg_start_line) & (r_line_cnt < i_reg_end_line);

    // PSRAM ステートマシーン
    localparam ST_IDLE      = 2'd0;
    localparam ST_READ_LINE = 2'd1;
    reg [ 1:0] r_state;
    reg [10:0] r_read_pixel_cnt;
    always @(posedge i_psram_clk) begin
        case (r_state)
        ST_IDLE: begin
            r_read_pixel_cnt <= 11'd0;

            if (w_hsync_pls & w_read_line) begin
                r_state <= ST_READ_LINE;
            end
        end
        ST_READ_LINE: begin
            if (r_read_pixel_cnt >= i_reg_width) begin
                r_state <= ST_IDLE;
            end
            else if (i_psram_gnt) begin
                r_read_pixel_cnt <= r_read_pixel_cnt + 11'd32;
            end
        end
        default: r_state <= ST_IDLE;
        endcase
    end

    // PSRAM 読み出しアドレス
    reg [20:0] r_psram_addr;
    always @(posedge i_psram_clk) begin
        if (w_vsync) begin
            r_psram_addr <= 21'd0;
        end
        else if (i_psram_gnt) begin
            r_psram_addr <= r_psram_addr + 21'd32;
        end
    end
    assign o_psram_addr = r_psram_addr;

    // PSRAM 読み出し要求
    reg r_psram_req;
    always @(posedge i_psram_clk or negedge i_psram_rst_n) begin
        if (!i_psram_rst_n) begin
            r_psram_req <= 1'b0;
        end
        else begin
            if (w_hsync_pls & w_read_line) begin
                r_psram_req <= 1'b1;
            end
            else if (r_state == ST_READ_LINE & r_psram_req == 1'b0) begin
                r_psram_req <= 1'b1;
            end
            else if (i_psram_gnt) begin
                r_psram_req <= 1'b0;
            end
        end
    end
    assign o_psram_req = r_psram_req;

    // ラインバッファ書き込みアドレス
    reg [8:0] r_dpram_write_addr;
    always @(posedge i_psram_clk or negedge i_psram_rst_n) begin
        if (!i_psram_rst_n)
            r_dpram_write_addr <= 9'd0;
        else if (w_hsync_pls)
            r_dpram_write_addr <= 9'd0;
        else if (i_psram_data_valid)
            r_dpram_write_addr <= r_dpram_write_addr + 9'd1;
    end

    // ラインバッファ
    reg  [10:0] r_dpram_read_addr;
    wire [15:0] w_dpram_read_data;
    framebuffer_reader_dpb u_dpram(
        .clka(i_psram_clk),
        .reseta(~i_psram_rst_n),
        .ada(r_dpram_write_addr),
        .dina(i_psram_data),
        .douta(),
        .wrea(i_psram_data_valid),
        .cea(1'b1),
        .ocea(1'b1),

        .clkb(i_video_clk),
        .resetb(~i_video_rst_n),
        .adb(r_dpram_read_addr),
        .dinb(16'd0),
        .doutb(w_dpram_read_data),
        .wreb(1'b0),
        .ceb(1'b1),
        .oceb(1'b1)
    );

    // ラインバッファ読み出しアドレス
    always @(posedge i_video_clk or negedge i_video_rst_n) begin
        if (!i_video_rst_n)
            r_dpram_read_addr <= 11'd0;
        else if (i_video_hsync)
            r_dpram_read_addr <= 11'd0;
        else if (i_video_active)
            r_dpram_read_addr <= r_dpram_read_addr + 11'd1;
    end

    // ラインバッファ読み出しSyncディレイ (1clk delay)
    reg [2:0] r_delay;
    always @(posedge i_video_clk) begin
        r_delay <= {i_video_hsync, i_video_vsync, i_video_active};
    end

    assign {o_video_hsync, o_video_vsync, o_video_active} = r_delay;
    assign o_video_data = w_dpram_read_data;

endmodule