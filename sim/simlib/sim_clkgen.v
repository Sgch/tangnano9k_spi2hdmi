`timescale 1ps/1ps
module sim_clkgen (
    output reg clk
);
    parameter FREQ_MHZ = 50;
    parameter INIT = 1'b0;

    real half_period_ps = (1.0 / (FREQ_MHZ * 1e6) * 1e12) / 2;

    initial clk = INIT;
    always #(half_period_ps) clk <= ~clk;

endmodule
