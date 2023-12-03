`timescale 1ps/1ps
module sim_spi_host #(
    SCK_MHZ = 8,
    WORD = 8,
    DEVICES = 1
) (
    output  logic               o_sck,
    output  logic               o_mosi,
    input   wire                i_miso,
    output  logic [DEVICES-1:0] o_cs_n
);
    real half_period_ps = (1.0 / (SCK_MHZ * 1e6) * 1e12) / 2;

    initial begin
        o_sck  = 1'b0;
        o_mosi = 1'b0;
        o_cs_n = '1;
    end

    task transact_word(input [WORD-1:0] send, output [WORD-1:0] recv);
        for (int i = WORD-1; i >= 0; i=i-1) begin
            o_mosi = send[i];
            #(half_period_ps);
            o_sck = 1'b1;
            recv[i] = i_miso;

            #(half_period_ps);
            o_sck = 1'b0;
        end
        #(500*1000);
    endtask

    task select_cs(input int index);
        o_cs_n[index] = 1'b0;
    endtask

    task release_cs();
        o_cs_n = '1;
    endtask

endmodule
