`timescale 1ps/1ps
module sim_spi_st7735r_host #(
    parameter SCK_MHZ = 16,
    parameter DEBUG_CMD = 1'b0
)(
    output  wire    o_sck,
    output  wire    o_mosi,
    output  wire    o_cs_n,
    output  wire    o_dc
);
    localparam WAIT_BYTE_INTERVAL = 50;
    localparam WAIT_CMD_INTERVAL = 100;

    bit r_dc;
    initial begin
        r_dc = 1'B0;
    end
    assign o_dc = r_dc;

    sim_spi_host #(
        .SCK_MHZ(25)
    ) u_sim_spi_host(
        .o_sck(o_sck),
        .o_mosi(o_mosi),
        .i_miso(1'b1), // unused
        .o_cs_n(o_cs_n)
    );

    task send_begin();
        $display("ST7735R: Begin");
        u_sim_spi_host.select_cs(0);
    endtask

    task send_end();
        $display("ST7735R: End");
        u_sim_spi_host.release_cs();
    endtask

    task send_command(input byte cmd, input string cmd_name);
    byte tmp;
    begin
        if (DEBUG_CMD) $write("cmd: %02x (%s)", cmd, cmd_name);
        r_dc = 1'b0;
        u_sim_spi_host.transact_word(cmd, tmp);
        #(WAIT_BYTE_INTERVAL);
        if (DEBUG_CMD) $write("\n");
    end
    endtask

    task send_command_data(input byte cmd, input string cmd_name, input byte data[]);
    byte tmp;
    begin
        if (DEBUG_CMD) $write("cmd: %02x (%s)", cmd, cmd_name);
        r_dc = 1'b0;
        u_sim_spi_host.transact_word(cmd, tmp);
        #(WAIT_BYTE_INTERVAL);

        r_dc = 1'b1;
        if (DEBUG_CMD) $write(" data:");
        for (int i = 0; i < $size(data); i++) begin
            if (DEBUG_CMD) $write("%x ", data[i]);
            u_sim_spi_host.transact_word(data[i], tmp);
            #(WAIT_BYTE_INTERVAL);
        end
        if (DEBUG_CMD) $write("\n");
    end
    endtask

    // common instructions
    task send_cmd_nop();
        $display("ST7735R: Send no operation");
        send_command(8'h00, "NOP");
    endtask

    task send_cmd_swreset();
        $display("ST7735R: Send software teset");
        send_command(8'h01, "SWRESET");
    endtask

    task send_cmd_dispoff();
        $display("ST7735R: Send display off");
        send_command(8'h28, "DISOFF");
    endtask

    task send_cmd_dispon();
        $display("ST7735R: Send display on");
        send_command(8'h29, "DISON");
    endtask

    task send_cmd_caset(input [15:0] start_col, input [15:0] end_col);
        $display("ST7735R: Send set COL: begin=%0d, end=%0d", start_col, end_col);
        send_command_data(8'h2a, "CASET", { start_col[15:8], start_col[7:0], end_col[15:8], end_col[7:0]} );
    endtask

    task send_cmd_raset(input [15:0] start_row, input [15:0] end_row);
        $display("ST7735R: Send set ROW: begin=%0d, end=%0d", start_row, end_row);
        send_command_data(8'h2b, "RASET", { start_row[15:8], start_row[7:0], end_row[15:8], end_row[7:0]} );
    endtask

    task fill_pixels(input int rect_right, input int rect_top, input int rect_left, input int rect_bottom, input bit [15:0] color);
    byte tmp;
    int len;
    begin
        len = (rect_left - rect_right + 1) * (rect_bottom - rect_top + 1);
        if (len < 0)
            $error("invalid length: len=%0d < 0", len);

        $display("ST7735R: Fill pixels (%0d, %0d)-(%0d, %0d) len:%0d", rect_right, rect_top, rect_left, rect_bottom, len);

        send_cmd_caset(rect_right[15:0], rect_left[15:0]);
        #(WAIT_CMD_INTERVAL);
        send_cmd_raset(rect_top[15:0], rect_bottom[15:0]);
        #(WAIT_CMD_INTERVAL);

        // 2C
        $display("ST7735R: Send write RAM");
        r_dc = 1'b0;
        u_sim_spi_host.transact_word(8'h2c, tmp);
        #(WAIT_BYTE_INTERVAL);

        r_dc = 1'b1;
        for (int i = 0; i < len; i++) begin
            u_sim_spi_host.transact_word(color[15:8], tmp);
            #(WAIT_BYTE_INTERVAL);
            u_sim_spi_host.transact_word(color[7:0], tmp);
            #(WAIT_BYTE_INTERVAL);
        end
        $display("ST7735R: Write RAM done");
    end
    endtask
endmodule
