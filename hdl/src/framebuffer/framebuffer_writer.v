module framebuffer_writer (
    input   wire            i_clk,
    input   wire            i_rst_n,

    input   wire            i_sram_clr_req,

    input   wire    [31:0]  i_col_addr,
    input   wire    [31:0]  i_row_addr,
    input   wire            i_sram_waddr_set_req,

    input   wire    [15:0]  i_pixel_data,
    input   wire            i_sram_write_req,
    output  wire            o_fifo_full,

    input   wire            i_psram_clk,
    input   wire            i_psram_rst_n,

    output  wire            o_psram_req,
    input   wire            i_psram_gnt,
    output  wire    [20:0]  o_psram_addr,
    output  wire    [63:0]  o_psram_data,
    output  wire    [ 7:0]  o_psram_data_mask
);
    localparam COLUMN_MAX = 2048;
    localparam ROW_MAX    = 2048;

    wire [$clog2(COLUMN_MAX)-1:0] w_sx;
    wire [$clog2(COLUMN_MAX)-1:0] w_ex;
    wire [$clog2(ROW_MAX)-1:0] w_sy;
    wire [$clog2(ROW_MAX)-1:0] w_ey;
    assign w_sx = i_col_addr[16+$clog2(COLUMN_MAX)-1:16];
    assign w_ex = i_col_addr[   $clog2(COLUMN_MAX)-1: 0];
    assign w_sy = i_row_addr[16+$clog2(ROW_MAX)-1:16];
    assign w_ey = i_row_addr[   $clog2(ROW_MAX)-1: 0];

    reg [$clog2(COLUMN_MAX)-1:0] r_col;
    reg [$clog2(ROW_MAX)-1:0] r_row;
    reg [20:0] r_sram_addr;
    reg        r_fifo_write;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_col <= 0;
            r_row <= 0;
            r_sram_addr <= 21'd0;
            r_fifo_write <= 1'b0;
        end else if (i_sram_waddr_set_req) begin
            r_col <= w_sx;
            r_row <= w_sy;
            r_fifo_write <= 1'b0;
        end else if (i_sram_write_req) begin
            r_col <= r_col + 1;
            if (r_col >= w_ex) begin
                r_col <= w_sx;

                r_row <= r_row + 1;
                if (r_row >= w_ey) begin
                    r_row <= w_sy;
                end
            end
            r_sram_addr <= (r_row * 21'd1280) + { 10'd0, r_col };
            r_fifo_write <= 1'b1;
        end else begin
            r_fifo_write <= 1'b0;
        end
    end

    reg  r_fifo_rd_en;
    wire [20:0] w_fifo_rd_addr;
    wire [15:0] w_fifo_rd_pixel;
    wire w_fifo_empty;
    framebuffer_writer_fifo u_fifo (
        .WrClk(i_clk),
        .WrReset(~i_rst_n),
        .Data({ r_sram_addr, i_pixel_data }),
        .WrEn(r_fifo_write),
        .Full(o_fifo_full),

        .RdClk(i_psram_clk),
        .RdReset(~i_psram_rst_n),
        .RdEn(r_fifo_rd_en),
        .Q({ w_fifo_rd_addr, w_fifo_rd_pixel }),
        .Empty(w_fifo_empty)
	);

    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_FIFO_WAIT = 3'd1;
    localparam [2:0] ST_WRITE_0   = 3'd2;
    localparam [2:0] ST_WRITE_1   = 3'd3;
    localparam [2:0] ST_WRITE     = 3'd4;
    reg [2:0]  r_state;

    reg        r_psram_req;
    reg [15:0] r_psram_addr;
    reg [15:0] r_psram_data;
    reg [63:0] r_psram_data_mask;
    reg [ 7:0] r_psram_burst_cnt;
    always @(posedge i_psram_clk or negedge i_psram_rst_n) begin
        if (!i_psram_rst_n) begin
            r_state <= ST_IDLE;

            r_psram_req <= 1'b0;
            r_psram_addr <= 16'd0;
            r_psram_data <= 16'h0000;
            r_psram_data_mask <= 64'd0;

            r_psram_burst_cnt <= 8'd0;

            r_fifo_rd_en <= 1'b0;
        end else begin
            case (r_state)
            ST_IDLE: begin
                if (!w_fifo_empty) begin
                    r_state <= ST_FIFO_WAIT;

                    r_fifo_rd_en <= 1'b1;
                end else begin
                    r_fifo_rd_en <= 1'b0;
                end
                r_psram_req <= 1'b0;
            end
            ST_FIFO_WAIT: begin
                r_fifo_rd_en <= 1'b0;
                r_state <= ST_WRITE_0;
            end
            ST_WRITE_0: begin
                r_state <= ST_WRITE_1;

                // burst #0
                r_psram_req <= 1'b1;
                r_psram_addr <= w_fifo_rd_addr[20:5];
                r_psram_data <= w_fifo_rd_pixel;
                r_psram_data_mask <= MaskTable(w_fifo_rd_addr[4:0]);

                r_psram_burst_cnt <= 8'd1;
            end
            ST_WRITE_1: begin
                if (i_psram_gnt) begin
                    r_state <= ST_WRITE;

                    // burst #1
                    r_psram_req <= 1'b0;
                    r_psram_data_mask <= { 8'h00, r_psram_data_mask[63:8] };
                    r_psram_burst_cnt <= { r_psram_burst_cnt[6:0], 1'b0 };
                end
            end
            ST_WRITE: begin
                // burst #2~7
                r_psram_data_mask <= { 8'h00, r_psram_data_mask[63:8] };
                r_psram_burst_cnt <= { r_psram_burst_cnt[6:0], 1'b0 };

                if (r_psram_burst_cnt[7]) begin
                    r_state <= ST_IDLE;
                end
            end
            default: r_state <= ST_IDLE;
            endcase
        end
    end
    assign o_psram_req  = r_psram_req;
    assign o_psram_addr = { r_psram_addr, 5'd0 };
    assign o_psram_data = { r_psram_data, r_psram_data, r_psram_data, r_psram_data};
    assign o_psram_data_mask = ~r_psram_data_mask[7:0];

    function [63:0] MaskTable(input [4:0] addr);
    begin
        case (addr)
        5'd0 :   MaskTable = 64'h00_00_00_00_00_00_00_11;
        5'd1 :   MaskTable = 64'h00_00_00_00_00_00_00_22;
        5'd2 :   MaskTable = 64'h00_00_00_00_00_00_00_44;
        5'd3 :   MaskTable = 64'h00_00_00_00_00_00_00_88;
        5'd4 :   MaskTable = 64'h00_00_00_00_00_00_11_00;
        5'd5 :   MaskTable = 64'h00_00_00_00_00_00_22_00;
        5'd6 :   MaskTable = 64'h00_00_00_00_00_00_44_00;
        5'd7 :   MaskTable = 64'h00_00_00_00_00_00_88_00;
        5'd8 :   MaskTable = 64'h00_00_00_00_00_11_00_00;
        5'd9 :   MaskTable = 64'h00_00_00_00_00_22_00_00;
        5'd10:   MaskTable = 64'h00_00_00_00_00_44_00_00;
        5'd11:   MaskTable = 64'h00_00_00_00_00_88_00_00;
        5'd12:   MaskTable = 64'h00_00_00_00_11_00_00_00;
        5'd13:   MaskTable = 64'h00_00_00_00_22_00_00_00;
        5'd14:   MaskTable = 64'h00_00_00_00_44_00_00_00;
        5'd15:   MaskTable = 64'h00_00_00_00_88_00_00_00;
        5'd16:   MaskTable = 64'h00_00_00_11_00_00_00_00;
        5'd17:   MaskTable = 64'h00_00_00_22_00_00_00_00;
        5'd18:   MaskTable = 64'h00_00_00_44_00_00_00_00;
        5'd19:   MaskTable = 64'h00_00_00_88_00_00_00_00;
        5'd20:   MaskTable = 64'h00_00_11_00_00_00_00_00;
        5'd21:   MaskTable = 64'h00_00_22_00_00_00_00_00;
        5'd22:   MaskTable = 64'h00_00_44_00_00_00_00_00;
        5'd23:   MaskTable = 64'h00_00_88_00_00_00_00_00;
        5'd24:   MaskTable = 64'h00_11_00_00_00_00_00_00;
        5'd25:   MaskTable = 64'h00_22_00_00_00_00_00_00;
        5'd26:   MaskTable = 64'h00_44_00_00_00_00_00_00;
        5'd27:   MaskTable = 64'h00_88_00_00_00_00_00_00;
        5'd28:   MaskTable = 64'h11_00_00_00_00_00_00_00;
        5'd29:   MaskTable = 64'h22_00_00_00_00_00_00_00;
        5'd30:   MaskTable = 64'h44_00_00_00_00_00_00_00;
        5'd31:   MaskTable = 64'h88_00_00_00_00_00_00_00;
        default: MaskTable = 64'h00_00_00_00_00_00_00_00;
        endcase
    end
    endfunction

endmodule
