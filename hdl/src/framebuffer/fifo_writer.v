module fifo_writer (
    input   wire            i_clk,
    input   wire            i_rst_n,

    input   wire    [15:0]  i_start_x,
    input   wire    [15:0]  i_end_x,
    input   wire            i_sram_write_req,
    input   wire            i_sram_waddr_set_req,

    output  wire            o_fifo_write,
    output  wire            o_line_write_done
);

    reg r_sram_write_req_dly;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_sram_write_req_dly <= 1'b0;
        end
        else begin
            r_sram_write_req_dly <= i_sram_write_req;
        end
    end

    wire w_sram_write_req_pls;
    assign w_sram_write_req_pls = i_sram_write_req & ~r_sram_write_req_dly;

    reg r_fifo_write;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_fifo_write <= 1'b0;
        end
        else begin
            r_fifo_write <= w_sram_write_req_pls;
        end
    end
    assign o_fifo_write = r_fifo_write;

    reg r_sram_waddr_set_req_dly;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_sram_waddr_set_req_dly <= 1'b0;
        end
        else begin
            r_sram_waddr_set_req_dly <= i_sram_waddr_set_req;
        end
    end

    wire w_sram_waddr_set_req_pls;
    assign w_sram_waddr_set_req_pls = i_sram_waddr_set_req & ~r_sram_waddr_set_req_dly;

    reg [10:0] r_line_data_cnt_max;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_line_data_cnt_max <= 11'd0;
        end
        else if (w_sram_waddr_set_req_pls) begin
            r_line_data_cnt_max <= i_end_x[10:0] - i_start_x[10:0] + 11'd1;
        end
    end

    reg [10:0] r_line_data_cnt;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_line_data_cnt <= 11'd0;
        end
        else if (w_sram_waddr_set_req_pls) begin
            r_line_data_cnt <= 11'd0;
        end
        else if (w_sram_write_req_pls) begin
            if (r_line_data_cnt == r_line_data_cnt_max) begin
                r_line_data_cnt <= 11'd1;
            end
            else begin
                r_line_data_cnt <= r_line_data_cnt + 11'd1;
            end
        end
    end

    reg r_line_write_done;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_line_write_done <= 1'b0;
        end
        else if (r_line_data_cnt_max != 11'd0 && r_line_data_cnt == r_line_data_cnt_max) begin
            r_line_write_done <= 1'b1;
        end
        else begin
            r_line_write_done <= 1'b0;
        end
    end
    assign o_line_write_done = r_line_write_done;

endmodule
