module framebuffer_writer (
    input   wire            i_clk,
    input   wire            i_rst_n,

    input   wire    [15:0]  i_pixel_data,   // 画素データ
    input   wire    [31:0]  i_col_addr,     // XS15:0[31:16], XE15:0[15:0]
    input   wire    [31:0]  i_row_addr,     // YS15:0[31:16], YE15:0[15:0]
    input   wire            i_sram_clr_req,
    input   wire            i_sram_write_req,
    input   wire            i_sram_waddr_set_req,

    input   wire            i_psram_clk,
    output  wire            o_psram_write_req,
    input   wire            i_psram_write_gnt,
    output  wire    [20:0]  o_psram_addr,
    output  wire    [63:0]  o_psram_data,
    output  wire    [ 7:0]  o_psram_data_mask
);
    wire w_fifo_write;
    wire w_line_write_done;
    fifo_writer u_fifo_writer(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),

        .i_start_x(i_col_addr[31:16]),
        .i_end_x(i_col_addr[15:0]),
        .i_sram_write_req(i_sram_write_req),
        .i_sram_waddr_set_req(i_sram_waddr_set_req),
        .o_fifo_write(w_fifo_write),
        .o_line_write_done(w_line_write_done)
    );

    // FIFO
    wire [15:0] w_fifo_read_data;
    wire w_fifo_read;
    sram_write_fifo_hs u_sram_fifo ( // 2048分のバッファー
		.WrClk(i_clk),
		.WrReset(~i_rst_n),
		.Data(i_pixel_data),
		.WrEn(w_fifo_write),

		.RdClk(i_psram_clk),
		.RdReset(~i_rst_n),
		.RdEn(w_fifo_read),
		.Q(w_fifo_read_data),

		.Empty(),
		.Full()
	);

    // CDC
    reg [2:0] r_cdc_sram_waddr_set_ff;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_cdc_sram_waddr_set_ff <= 3'd0;
        end
        else begin
            r_cdc_sram_waddr_set_ff <= { r_cdc_sram_waddr_set_ff[1:0], i_sram_waddr_set_req };
        end
    end

    reg [2:0] r_cdc_line_write_done_ff;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_cdc_line_write_done_ff <= 3'd0;
        end
        else begin
            r_cdc_line_write_done_ff <= { r_cdc_line_write_done_ff[1:0], w_line_write_done };
        end
    end

    // PSRAM clock domain
    wire w_sram_waddr_set_pls;
    assign w_sram_waddr_set_pls =  r_cdc_sram_waddr_set_ff[1] & ~r_cdc_sram_waddr_set_ff[2];

    wire w_line_write_done_pls;
    assign w_line_write_done_pls =  r_cdc_line_write_done_ff[1] & ~r_cdc_line_write_done_ff[2];

    // register latch
    reg [10:0] r_sx;
    reg [10:0] r_ex;
    reg [10:0] r_sy;
    reg [10:0] r_ey;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_sx <= 11'd0;
            r_ex <= 11'd0;
            r_sy <= 11'd0;
            r_ey <= 11'd0;
        end
        else if (w_sram_waddr_set_pls) begin
            r_sx <= i_col_addr[26:16];
            r_ex <= i_col_addr[10: 0];
            r_sy <= i_row_addr[26:16];
            r_ey <= i_row_addr[10: 0];
        end
    end

    // packer
    wire [5:0] w_packer_block_start_index; // 32区切りにおける先頭ブロックのindex (0〜39)
    wire [5:0] w_packer_block_end_index;   // 32区切りにおける終端ブロックのindex (0〜39)
    wire [4:0] w_packer_first_start_index; // 32区切りにおける先頭ブロック内の開始index
    wire [4:0] w_packer_first_end_index;   // 32区切りにおける先頭ブロック内の終了index
    wire [4:0] w_packer_last_end_index;    // 32区切りにおける終端ブロック内の終了index
    assign w_packer_block_start_index = r_sx[10:5]; // div 32  (1280: 16'b0000_0101_0000_0000 => /32 => 40: 16'b0000_0000_0010_1000 => 6'b10_1000)
    assign w_packer_block_end_index   = r_ex[10:5]; // div 32
    assign w_packer_first_start_index = r_sx[ 4:0]; // mod 32
    assign w_packer_last_end_index    = r_ex[ 4:0]; // mod 32
    assign w_packer_first_end_index   = (w_packer_block_start_index == w_packer_block_end_index) ? w_packer_last_end_index : 5'd31;

    // calc some registers
    reg [3:0] r_step;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_step <= 4'b0000;
        end
        else if (w_sram_waddr_set_pls) begin
            r_step <= 4'b0001;
        end
        else begin
            r_step <= { r_step[2:0], 1'b0 };
        end
    end

    reg [20:0] r_psram_line_head_base_addr; // PSRAMにおける先頭行のアドレス
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_line_head_base_addr <= 21'd0;
        end
        else begin
            case (r_step)
            4'b0001: begin
                r_psram_line_head_base_addr <= { r_sy, 10'd0 } + { 2'd0, r_sy, 8'd0 }; // NOTE: n*1280 = n*1024 + n*256
            end
            4'b0010: begin
                r_psram_line_head_base_addr <= r_psram_line_head_base_addr + { 10'd0, w_packer_block_start_index, 5'd0 }; // addr = sy*1280 + floor(sx/32)*32;
            end
            default: ; // nothing to do
            endcase
        end
    end

    // Packer
    wire w_packer_done;

    reg [5:0] r_packer_count; // 32区分けカウント
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_packer_count <= 6'd0;
        end
        else if (w_line_write_done_pls) begin
            r_packer_count <= w_packer_block_start_index;
        end
        else if (w_packer_done) begin
            r_packer_count <= r_packer_count + 6'd1;
        end
    end

    reg r_packer_start;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_packer_start <= 1'b0;
        end
        else if (w_line_write_done_pls) begin // 始動のキッカケ
            r_packer_start <= 1'b1;
        end
        else if (w_packer_done && r_packer_count < w_packer_block_end_index) begin
            r_packer_start <= 1'b1;
        end
         else begin
            r_packer_start <= 1'b0;
        end
    end

    reg [4:0] r_packer_start_index;
    reg [4:0] r_packer_end_index;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_packer_start_index <= 5'd0;
            r_packer_end_index <= 5'd0;
        end
        else if (r_packer_count == 0 && w_line_write_done_pls) begin // 先頭ブロック
            r_packer_start_index <= w_packer_first_start_index;
            r_packer_end_index   <= w_packer_first_end_index;
        end else if (w_packer_done) begin
            if (r_packer_count == w_packer_block_end_index) begin // 後尾ブロック
                r_packer_start_index <= 5'd0;
                r_packer_end_index   <= w_packer_last_end_index;
            end else begin // 途中ブロック
                r_packer_start_index <= 5'd0;
                r_packer_end_index   <= 5'd31;
            end
        end
    end

    packer u_packer (
        .i_clk(i_psram_clk),
        .i_rst_n(i_rst_n),

        .i_start_index(r_packer_start_index),
        .i_end_index(r_packer_end_index),

        .i_start(r_packer_start),
        .o_done(w_packer_done),

        .o_data_read(w_fifo_read),
        .i_data(w_fifo_read_data),

        .o_psram_write_req(o_psram_write_req),
        .i_psram_write_gnt(i_psram_write_gnt),
        .o_psram_data(o_psram_data),
        .o_psram_data_mask(o_psram_data_mask)
    );

    // PSRAM 書き込み
    reg [20:0] r_psram_addr;
    always @(posedge i_psram_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_addr <= 21'd0;
        end
        else if (r_packer_count == 0 && w_line_write_done_pls) begin // ライン 先頭ブロック
            r_psram_addr <= r_psram_line_head_base_addr;
        end
        else if (w_packer_done && r_packer_count == w_packer_block_end_index) begin
            r_psram_addr <= r_psram_addr + 21'd1280;
        end
        else if (w_packer_done) begin
            r_psram_addr <= r_psram_addr + 21'd32; // 1バースト分進める
        end
    end
    assign o_psram_addr = r_psram_addr;


endmodule
