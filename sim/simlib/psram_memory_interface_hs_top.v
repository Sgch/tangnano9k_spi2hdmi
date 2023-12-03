`timescale 1ns/1ps
// TODO: remove magic numbers, do refactoring
module PSRAM_Memory_Interface_HS_Top(
    input   wire            clk,
    input   wire            memory_clk,
    input   wire            pll_lock,
    input   wire            rst_n,
    input   wire    [63:0]  wr_data,
    input   wire    [20:0]  addr,
    input   wire            cmd,
    input   wire            cmd_en,
    input   wire    [ 7:0]  data_mask,
    output  wire    [63:0]  rd_data,
    output  wire            rd_data_valid,
    output  wire            init_calib,
    output  wire            clk_out
);
    localparam CLK_DIV_START = 20; // 20clk
    localparam INIT_CALIB = 3*1000; // 15ms

    // internal clock (memory_clk / 2)
    integer r_clk_cnt;
    reg r_clk_ok;
    always @(posedge memory_clk or negedge rst_n) begin
        if (!rst_n) begin
            r_clk_cnt <= 0;
            r_clk_ok <= 1'b0;
        end
        else if (r_clk_cnt < 20) begin
            r_clk_cnt <= r_clk_cnt + 1;
            r_clk_ok <= 1'b0;
        end
        else begin
            r_clk_ok <= 1'b1;
        end
    end

    reg r_clk;
    always @(posedge memory_clk or negedge rst_n) begin
        if (!rst_n) begin
            r_clk <= 1'b0;
        end
        else if (!r_clk_ok) begin
            r_clk <= 1'b0;
        end
        else begin
            r_clk <= ~r_clk;
        end
    end
    assign clk_out = r_clk;

    // internal reset
    wire w_rst_n;
    assign w_rst_n = rst_n & pll_lock;

    // init_calib
    real r_init_calib_done_time;
    always @(posedge r_clk or negedge w_rst_n) begin
        if (!w_rst_n) begin
            r_init_calib_done_time <= 0.0;
        end
        else if (r_clk_ok && r_init_calib_done_time == 0.0) begin
            r_init_calib_done_time <= $realtime + INIT_CALIB;
        end
    end
    reg r_init_calib;
    always @(posedge r_clk or negedge w_rst_n) begin
        if (!w_rst_n) begin
            r_init_calib <= 1'b0;
        end
        else if (r_init_calib_done_time != 0.0 && r_init_calib_done_time < $realtime) begin
            r_init_calib <= 1'b1;
        end
    end
    assign init_calib = r_init_calib;

    // memory
    wire w_rd_data_valid;
    wire [63:0] w_rd_data;
    PSRAM_Memory_Interface_HS_core mem_core(
        .clk(memory_clk),
        .rst_n(w_rst_n & r_init_calib),
        .addr(addr),
        .wr_data(wr_data),
        .data_mask(data_mask),
        .rd_data(w_rd_data),
        .rd_data_valid(w_rd_data_valid),
        .cmd_en(cmd_en),
        .cmd(cmd)
    );

    reg r_rd_data_valid_sync;
    reg [63:0] r_rd_data_sync;
    always @(posedge clk_out) begin
        r_rd_data_valid_sync <= w_rd_data_valid;
        r_rd_data_sync <= w_rd_data;
    end
    assign rd_data_valid = r_rd_data_valid_sync;
    assign rd_data = r_rd_data_sync;

endmodule

module PSRAM_Memory_Interface_HS_core(
    input   wire            clk,
    input   wire            rst_n,

    input   wire    [20:0]  addr,
    input   wire    [63:0]  wr_data,
    input   wire    [ 7:0]  data_mask,
    output  wire    [63:0]  rd_data,
    output  wire            rd_data_valid,
    input   wire            cmd_en,
    input   wire            cmd
);
    parameter ADDR_WIDTH = 21;

    parameter TCMD = 19;
    parameter BURST = 32;
    localparam TCMD_CLKS = 19 * 2 - 1;
    localparam BURST_COUNT = (BURST / 4) * 2;

    reg r_cmd_en_dly;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_cmd_en_dly <= 1'b0;
        end
        else begin
            r_cmd_en_dly <= cmd_en;
        end
    end
    wire w_rising_cmd_en;
    assign w_rising_cmd_en = cmd_en & ~r_cmd_en_dly;

    reg [7:0] r_tcmd_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_tcmd_cnt <= 8'd0;
        end
        else if (w_rising_cmd_en) begin
            if (r_tcmd_cnt != 0) begin
                $warning("Tcmd timig violation.");
            end
            r_tcmd_cnt <= 8'd1;
        end
        else if (r_tcmd_cnt > 0 && r_tcmd_cnt < TCMD_CLKS) begin
            r_tcmd_cnt <= r_tcmd_cnt + 8'd1;
        end
        else begin
            r_tcmd_cnt <= 8'd0;
        end
    end

    reg r_write;
    reg r_read;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_write <= 1'b0;
            r_read  <= 1'b0;
        end
        else if (w_rising_cmd_en) begin
            r_write <=  cmd;
            r_read  <= ~cmd;
        end
        else if (r_tcmd_cnt == TCMD_CLKS) begin
            r_write <= 1'b0;
            r_read  <= 1'b0;
        end
    end

    wire w_ram_addr_gen;
    assign w_ram_addr_gen = (r_tcmd_cnt > 8'd0 && r_tcmd_cnt <= BURST_COUNT);

    // address (wrapped burst)
    reg [3:0] r_addr_low4;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_addr_low4 <= 4'd0;
        end
        else if (w_rising_cmd_en) begin
            r_addr_low4 <= addr[3:0]; // capture base address
        end
        else if (w_ram_addr_gen) begin
            r_addr_low4 <= r_addr_low4 + 4'd1;
        end
    end
    wire [ADDR_WIDTH-1:0] w_ram_addr;
    assign w_ram_addr = { addr[20:4], r_addr_low4 };

    // write
    // data: 64'hHHGG_FFEE_DDCC_BBAA
    // mask:  8'bHFDB_GECA
    reg [3:0]  r_data_mask_lower_dly;
    reg [31:0] r_wr_data_lower_dly;
    always @(posedge clk) begin
        r_data_mask_lower_dly <= { data_mask[5], data_mask[1], data_mask[4], data_mask[0] };
        r_wr_data_lower_dly  <= wr_data[31:0];
    end
    wire [3:0]  w_ram_data_mask;
    wire [31:0] w_ram_wr_data;
    assign w_ram_data_mask = r_tcmd_cnt[0] ? { data_mask[7], data_mask[3], data_mask[6], data_mask[2] } : r_data_mask_lower_dly;
    assign w_ram_wr_data   = r_tcmd_cnt[0] ? wr_data[63:32] : r_wr_data_lower_dly;

    wire [31:0] w_ram_rd_data;
    PSRAM_Memory_Interface_HS_memory ram(
        .clk(clk),

        .addr(w_ram_addr),
        .write(r_write && w_ram_addr_gen),
        .wr_data(w_ram_wr_data),
        .byte_mask(w_ram_data_mask),
        .rd_data(w_ram_rd_data)
    );

    // read
    wire w_fifo_read;
    wire [63:0] w_fifo_rd_data;
    PSRAM_Memory_Interface_HS_fifo fifo(
        .clk(clk),
        .rst_n(rst_n),

        .write(r_read && w_ram_addr_gen),
        .wr_data(w_ram_rd_data),

        .read(w_fifo_read),
        .rd_data(w_fifo_rd_data)
    );

    reg [4:0] r_fifo_read_count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_fifo_read_count <= 5'd0;
        end
        else if (r_tcmd_cnt == 31 && r_read) begin
            r_fifo_read_count <= 5'd1;
        end
        else if (r_fifo_read_count >= 5'd16) begin
            r_fifo_read_count <= 5'd0;
        end
        else if (r_fifo_read_count > 0) begin
            r_fifo_read_count <= r_fifo_read_count + 1;
        end
    end
    assign w_fifo_read = (r_fifo_read_count > 0) && !r_fifo_read_count[0];

    assign rd_data_valid = (r_fifo_read_count != 5'd0);
    assign rd_data = w_fifo_rd_data;

endmodule

module PSRAM_Memory_Interface_HS_memory #(
    parameter ADDR_WIDTH = 21
) (
    input   wire                      clk,

    input   wire    [ADDR_WIDTH-1:0]  addr,
    input   wire                      write,
    input   wire    [31:0]            wr_data,
    input   wire    [ 3:0]            byte_mask,
    output  wire    [31:0]            rd_data
);

    localparam WORDS = 2 ** ADDR_WIDTH;

    reg [7:0] r_mem_3[0:WORDS-1]; // mask[3] data[31:24]
    reg [7:0] r_mem_2[0:WORDS-1]; // mask[2] data[23:16]
    reg [7:0] r_mem_1[0:WORDS-1]; // mask[1] data[15: 8]
    reg [7:0] r_mem_0[0:WORDS-1]; // mask[0] data[ 7: 0]

    always @(posedge clk) begin
        if (write) begin
            if (!byte_mask[3])
                r_mem_3[addr] <= wr_data[31:24];

            if (!byte_mask[2])
                r_mem_2[addr] <= wr_data[23:16];

            if (!byte_mask[1])
                r_mem_1[addr] <= wr_data[15:8];

            if (!byte_mask[0])
                r_mem_0[addr] <= wr_data[7:0];
        end
    end

    assign rd_data = { r_mem_3[addr], r_mem_2[addr], r_mem_1[addr], r_mem_0[addr] };

endmodule

module PSRAM_Memory_Interface_HS_fifo #(
    parameter READ_DEPTH = 8 // power of 2
) (
    input   wire            clk,
    input   wire            rst_n,

    input   wire            write,
    input   wire    [31:0]  wr_data,
    input   wire            read,
    output  wire    [63:0]  rd_data
);
    localparam RD_WIDTH = $clog2(READ_DEPTH);

    reg [31:0] r_mem_0[0:READ_DEPTH-1];
    reg [31:0] r_mem_1[0:READ_DEPTH-1];

    reg [RD_WIDTH:0] r_wd_addr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_wd_addr <= {(RD_WIDTH+1){1'b0}};
        end
        else if (write) begin
            r_wd_addr <= r_wd_addr + 1'd1;
            if (r_wd_addr[0]) begin
                r_mem_1[r_wd_addr[RD_WIDTH:1]] <= wr_data;
            end
            else begin
                r_mem_0[r_wd_addr[RD_WIDTH:1]] <= wr_data;
            end
        end
    end

    reg [RD_WIDTH-1:0] r_rd_addr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_rd_addr <= {RD_WIDTH{1'b0}};
        end
        else if (read) begin
            r_rd_addr <= r_rd_addr + 1'd1;
        end
    end

    assign rd_data = { r_mem_0[r_rd_addr], r_mem_1[r_rd_addr] };

endmodule
