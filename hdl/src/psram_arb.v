module psram_arb #(
    parameter TCMD = 19
)(
    input   wire            i_clk,
    input   wire            i_rst_n,

    // PSRAM IF
    output  wire  [20:0]    o_psram_addr,
    output  wire            o_psram_cmd,
    output  wire            o_psram_cmd_en,
    output  wire  [63:0]    o_psram_wr_data,
    output  wire  [ 7:0]    o_psram_data_mask,
    input   wire  [63:0]    i_psram_rd_data,
    input   wire            i_psram_rd_data_valid,
    input   wire            i_psram_init_calib,

    // Read
    input   wire            i_read_req,
    output  wire            o_read_gnt,
    input   wire    [20:0]  i_read_addr,
    output  wire    [63:0]  o_read_data,
    output  wire            o_read_data_valid,

    // Write
    input   wire            i_write_req,
    output  wire            o_write_gnt,
    input   wire    [20:0]  i_write_addr,
    input   wire    [63:0]  i_write_data,
    input   wire    [ 7:0]  i_write_data_mask
);
    localparam SERVICE_NONE  = 2'd0;
    localparam SERVICE_READ  = 2'd1;
    localparam SERVICE_WRITE = 2'd2;

    wire w_psram_free;

    wire w_gnt;
    reg r_read_gnt;
    reg r_write_gnt;

    wire w_req;
    wire w_read_req;
    wire w_write_req;
    assign w_read_req  = (i_psram_init_calib) & i_read_req;
    assign w_write_req = (i_psram_init_calib) & i_write_req;
    assign w_req = w_read_req | w_write_req;

    // 今使用中のトランザクション
    reg [1:0] r_using_service;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_using_service <= SERVICE_NONE;
        end
        else if (w_psram_free) begin
            r_using_service <= (r_read_gnt) ? SERVICE_READ :
                                (r_write_gnt) ? SERVICE_WRITE :
                                SERVICE_NONE;
        end
    end

    // 優先されるトランザクション
    // NONE  => READ
    // READ  => WRITE
    // WRITE => READ

    // ペンディングされたトランザクション
    reg r_pending_done;
    reg [1:0] r_pending_service;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_pending_service <= SERVICE_NONE;
        end
        else if (!w_psram_free) begin
            if (i_read_req & i_write_req) begin // 競合
                case (r_using_service)
                    SERVICE_READ:  r_pending_service <= SERVICE_WRITE;
                    SERVICE_WRITE: r_pending_service <= SERVICE_READ;
                    default: r_pending_service <= SERVICE_READ;
                endcase
            end
            else if (i_write_req) begin
                r_pending_service <= SERVICE_WRITE;
            end
            else if (i_read_req) begin
                r_pending_service <= SERVICE_READ;
            end
        end
        else if (r_pending_done) begin
            r_pending_service <= SERVICE_NONE;
        end
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_pending_done <= 1'b0;
        end
        else if(r_using_service == SERVICE_NONE && r_pending_service != SERVICE_NONE) begin
            r_pending_done <= 1'b1;
        end else begin
            r_pending_done <= 1'b0;
        end
    end

    // 許可信号
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_read_gnt  <= 1'b0;
        end
        else if (w_gnt) begin
            r_read_gnt  <= 1'b0;
        end
        else if (w_read_req & w_psram_free) begin
            r_read_gnt  <= ((r_pending_service == SERVICE_READ) | ( r_pending_service == SERVICE_NONE));
        end
        else if (r_using_service == SERVICE_NONE && r_pending_service == SERVICE_READ) begin
            r_read_gnt <= 1'b1;
        end
    end
    assign o_read_gnt = r_read_gnt;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_write_gnt <= 1'b0;
        end
        else if (w_gnt) begin
            r_write_gnt <= 1'b0;
        end
        else if (w_write_req & w_psram_free) begin
            r_write_gnt <= ((r_pending_service == SERVICE_WRITE) | ( r_pending_service == SERVICE_NONE && !w_read_req));
        end
        else if (r_using_service == SERVICE_NONE && r_pending_service == SERVICE_WRITE) begin
            r_write_gnt <= 1'b1;
        end
    end
    assign o_write_gnt = r_write_gnt;

    assign w_gnt = r_read_gnt | r_write_gnt;

    // TCMDカウンタ
    reg [4:0] r_tcmd_cnt;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_tcmd_cnt <= 5'd0;
        end
        else if (w_gnt || (r_tcmd_cnt != 0 && r_tcmd_cnt < TCMD-2)) begin
            r_tcmd_cnt <= r_tcmd_cnt + 5'd1;
        end
        else begin
            r_tcmd_cnt <= 5'd0;
        end
    end
    assign w_psram_free = i_psram_init_calib & (r_tcmd_cnt == 0);

    // PSRAM CMD信号
    reg r_psram_cmd;
    reg r_psram_cmd_en;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_cmd    <= 1'b0;
            r_psram_cmd_en <= 1'b0;
        end
        else if (w_gnt) begin
            r_psram_cmd    <= 1'b1;
            r_psram_cmd_en <= r_write_gnt;
        end
        else begin
            r_psram_cmd    <= 1'b0;
            r_psram_cmd_en <= 1'b0;
        end
    end
    assign o_psram_cmd = r_psram_cmd;
    assign o_psram_cmd_en = r_psram_cmd_en;

    // PSRAM アドレス
    reg [20:0] r_psram_addr;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_addr <= 21'd0;
        end
        else if (r_read_gnt) begin
            r_psram_addr <= i_read_addr;
        end
        else if (r_write_gnt) begin
            r_psram_addr <= i_write_addr;
        end
    end
    assign o_psram_addr = r_psram_addr;

    assign o_read_data = i_psram_rd_data;
    assign o_read_data_valid = i_psram_rd_data_valid;
    assign o_psram_wr_data = i_write_data;
    assign o_psram_data_mask = i_write_data_mask;

endmodule
