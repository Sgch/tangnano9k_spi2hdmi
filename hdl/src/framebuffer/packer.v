module packer (
    input   wire            i_clk,
    input   wire            i_rst_n,

    input   wire    [ 4:0]  i_start_index,
    input   wire    [ 4:0]  i_end_index,

    input   wire            i_start,
    output  wire            o_done,

    output  wire            o_data_read,
    input   wire    [15:0]  i_data,

    output  wire            o_psram_write_req,
    input   wire            i_psram_write_gnt,
    output  wire    [63:0]  o_psram_data,
    output  wire    [ 7:0]  o_psram_data_mask
);

    reg [5:0] r_counter;
    reg       r_run, r_dly, r_dly2;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_counter <= 6'd0;
        end
        else if (r_run) begin
            r_counter <= r_counter + 6'd1;
        end
        else begin
            r_counter <= 6'd0;
        end
    end
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_run <= 1'b0;
        end
        else if (i_start) begin
            r_run <= 1'b1;
        end
        else if (r_counter == 6'd32) begin
            r_run <= 1'b0;
        end
    end
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_dly <= 1'b0;
            r_dly2 <= 1'b0;
        end
        else begin
            r_dly <= r_run;
            r_dly2 <= r_dly;
        end
    end

    // ram書き込み 完了通知
    reg r_ram_write_done;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_ram_write_done <= 1'b0;
        end
        else if (i_start | r_ram_write_done) begin
            r_ram_write_done <= 1'b0;
        end
        else if (r_counter == 6'd31+2) begin // req遅延(1) + FIFO読み出し遅延(1)
            r_ram_write_done <= 1'b1;
        end
    end

    // data要求
    wire w_data_in_valid;
    assign w_data_in_valid = ({1'b0, i_start_index} <= r_counter) && (r_counter <= {1'b0, i_end_index});

    reg r_data_read;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_data_read <= 1'b0;
        end
        else if (i_start) begin
            r_data_read <= 1'b0;
        end
        else if (r_run && w_data_in_valid) begin
            r_data_read <= 1'b1;
        end
        else begin
            r_data_read <= 1'b0;
        end
    end
    assign o_data_read = r_data_read;

    // ram書き込みアドレス
    reg [4:0] r_data_count;
    wire [1:0] w_ram_select;
    wire [2:0] w_ram_addr;
    assign w_ram_select = r_data_count[1:0];
    assign w_ram_addr   = r_data_count[4:2];
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_data_count <= 5'd0;
        end
        else if (i_start) begin
            r_data_count <= 5'd0;
        end
        else if (r_run && r_dly2) begin
            r_data_count <= r_data_count + 5'd1;
        end
    end

    // data
    reg [15:0] r_data_ram_0[0:7];
    reg [15:0] r_data_ram_1[0:7];
    reg [15:0] r_data_ram_2[0:7];
    reg [15:0] r_data_ram_3[0:7];

    always @(posedge i_clk) begin
        if (r_run || r_dly) begin
            case (w_ram_select)
                2'd0: r_data_ram_0[w_ram_addr] <= i_data;
                2'd1: r_data_ram_1[w_ram_addr] <= i_data;
                2'd2: r_data_ram_2[w_ram_addr] <= i_data;
                2'd3: r_data_ram_3[w_ram_addr] <= i_data;
                default: ; // notning to do
            endcase
        end
    end

    // valid
    reg [7:0] r_valid_ram[0:7];

    reg r_valid_dly, r_valid_dly2;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_valid_dly <= 1'b0;
            r_valid_dly2 <= 1'b0;
        end
        else begin
            r_valid_dly <= w_data_in_valid;
            r_valid_dly2 <= r_valid_dly;
        end
    end

    reg [3:0] r_valid;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_valid <= 4'h0;
        end
        else if (i_start) begin
            r_valid <= 4'h0;
        end
        else if (r_run) begin
            r_valid <= { r_valid_dly, r_valid[3:1] };
        end
    end

    always @(posedge i_clk) begin
        if (r_run || r_dly) begin
            if (w_ram_select == 2'd3) begin
                r_valid_ram[w_ram_addr] <= { r_valid[3], r_valid[3], r_valid[2], r_valid[2], r_valid[1], r_valid[1], r_valid[0], r_valid[0] };
            end
        end
    end

    // PSRAM書き込み
    reg r_ram_read;
    reg [2:0] r_ram_read_addr;
    reg r_psram_write_req;
    reg r_psram_write_done;

    // 書き込みステート
    reg [1:0] r_psram_write_state;
    localparam [1:0] PSRAM_STATE_IDLE     = 2'd0;
    localparam [1:0] PSRAM_STATE_WAIT_GNT = 2'd1;
    localparam [1:0] PSRAM_STATE_WRITING  = 2'd2;
    localparam [1:0] PSRAM_STATE_DONE     = 2'd3;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_write_state <= PSRAM_STATE_IDLE;

            r_ram_read <= 1'b0;
            r_psram_write_req <= 1'b0;
            r_ram_read_addr <= 3'd0;
            r_psram_write_done <= 1'b0;
        end
        else begin
            case (r_psram_write_state)
            PSRAM_STATE_IDLE: begin
                if (r_ram_write_done) begin
                    r_psram_write_state <= PSRAM_STATE_WAIT_GNT;

                    r_psram_write_req <= 1'b1;
                    r_ram_read <= 1'b1;
                end
                else begin
                    r_psram_write_req <= 1'b0;
                    r_ram_read <= 1'b0;
                end
                r_ram_read_addr <= 3'd0;
                r_psram_write_done <= 1'b0;
            end
            PSRAM_STATE_WAIT_GNT: begin
                if (i_psram_write_gnt) begin
                    r_psram_write_state <= PSRAM_STATE_WRITING;

                    r_psram_write_req <= 1'b0;
                    r_ram_read <= 1'b1;
                    r_ram_read_addr <= r_ram_read_addr + 3'd1;
                end
            end
            PSRAM_STATE_WRITING: begin
                r_ram_read_addr <= r_ram_read_addr + 3'd1;
                if (r_ram_read_addr == 3'd7) begin
                    r_psram_write_state <= PSRAM_STATE_DONE;

                    r_ram_read <= 1'b0;
                end
            end
            PSRAM_STATE_DONE: begin
                r_psram_write_done <= 1'b1;
                r_psram_write_state <= PSRAM_STATE_IDLE;
            end
            default: begin
                r_psram_write_state <= PSRAM_STATE_IDLE;
            end
            endcase
        end
    end
    assign o_psram_write_req = r_psram_write_req;

    // ram 読み出し
    reg [63:0] r_psram_data;
    reg [ 7:0] r_psram_data_mask;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_psram_data      <= 64'd0;
            r_psram_data_mask <= 8'd0;
        end
        else if (r_ram_read) begin
            r_psram_data      <= {r_data_ram_3[r_ram_read_addr],r_data_ram_2[r_ram_read_addr],r_data_ram_1[r_ram_read_addr],r_data_ram_0[r_ram_read_addr] };
            r_psram_data_mask <= ~r_valid_ram[r_ram_read_addr];
        end
    end
    assign o_psram_data      = r_psram_data;
    assign o_psram_data_mask = r_psram_data_mask;

    assign o_done = r_psram_write_done;

endmodule
