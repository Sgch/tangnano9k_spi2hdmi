`default_nettype none
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
    localparam CMD_READ  = 1'b0;
    localparam CMD_WRITE = 1'b1;

    wire w_request_available;
    assign w_request_available = (i_psram_init_calib & (i_read_req | i_write_req));

    localparam ST_IDLE  = 1'd0;
    localparam ST_CMD   = 1'd1;
    reg [0:0] r_state;
    reg [4:0] r_tcmd_cnt;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state <= ST_IDLE;
        end
        else begin
            case (r_state)
                ST_IDLE: begin
                    r_tcmd_cnt <= 5'd0;

                    if (w_request_available) begin
                        r_state <= ST_CMD;
                    end
                end
                ST_CMD: begin
                    r_tcmd_cnt <= r_tcmd_cnt + 4'd1;

                    if (r_tcmd_cnt > TCMD) begin
                        r_state <= ST_IDLE;
                    end
                end
                default: r_state <= ST_IDLE;
            endcase
        end
    end

    wire w_state_idling;
    assign w_state_idling = (i_psram_init_calib & (r_state == ST_IDLE));

    reg r_write_gnt;
    reg r_read_gnt;
    always @(posedge i_clk) begin
        r_write_gnt <= (w_state_idling & ~i_read_req & i_write_req);
        r_read_gnt  <= (w_state_idling & i_read_req);
    end
    assign o_write_gnt = r_write_gnt;
    assign o_read_gnt  = r_read_gnt;

    reg [20:0] r_addr;
    reg        r_cmd;
    always @(posedge i_clk) begin
        if (w_state_idling & w_request_available) begin
            if (i_read_req) begin
                r_addr <= i_read_addr;
                r_cmd  <= CMD_READ;
            end
            else if (i_write_req) begin
                r_addr <= i_write_addr;
                r_cmd  <= CMD_WRITE;
            end
        end
    end
    assign o_psram_addr = r_addr;
    assign o_psram_cmd  = r_cmd;

    reg r_cmd_en;
    always @(posedge i_clk) begin
        r_cmd_en <= (w_state_idling & w_request_available);
    end
    assign o_psram_cmd_en = r_cmd_en;

    assign o_read_data = i_psram_rd_data;
    assign o_read_data_valid = i_psram_rd_data_valid;
    assign o_psram_wr_data = i_write_data;
    assign o_psram_data_mask = i_write_data_mask;

endmodule
`default_nettype wire
