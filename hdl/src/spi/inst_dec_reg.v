/*************************************************************
 * Title : Instruction Decoder & Registers
 * Date  : 2019/9/22
 *************************************************************/
module inst_dec_reg (
    input   wire            i_clk,          // FPGA内部CLK
    input   wire            i_rst_n,        // RESET

    // From SPI Slave
    input	wire    [ 7:0]  i_spi_data,
    input   wire            i_spi_dc,
    input   wire            i_spi_rxdone,

    // 
    output  wire    [15:0]  o_pixel_data,   // 画素データ
    output  reg     [31:0]  o_col_addr,     // XS15:0[31:16], XE15:0[15:0]
    output  reg     [31:0]  o_row_addr,     // YS15:0[31:16], YE15:0[15:0]

    output  wire            o_sram_clr_req,         // SRAM ALLクリアリクエスト
    output  wire            o_sram_write_req,       // SRAM画素データ書き込みリクエスト
    output  wire            o_sram_waddr_set_req,   // SRAM書き込みアドレス設定リクエスト
    output  reg             o_dispOn,

    output  reg     [ 7:0]  o_pwm_duty      // PWM Duty(0:MIN / 255:MAX)
    );

    /**************************************************************
     *  ST7735R Instruction
     *************************************************************/
    localparam CMD_NOP      = 8'h00;    // No Operation
    localparam CMD_SWRESET  = 8'h01;    // Software reset
    localparam CMD_DISPOFF  = 8'h28;    // Display Off
    localparam CMD_DISPON   = 8'h29;    // Display On
    localparam CMD_CASET    = 8'h2A;    // Column Address Set
    localparam CMD_RASET    = 8'h2B;    // Row Address Set
    localparam CMD_RAMWR    = 8'h2C;    // Memory Write

    /**************************************************************
     *  Special Instruction
     *************************************************************/
    localparam CMD_PWMDS    = 8'h02;    // PWM Duty Set


    /**************************************************************
     *  SPI受信データ処理 / データ書き込み要求処理
     *************************************************************/
    reg [15:0]  r_mosi_16_pixel_data;
    reg         r_pixel_data_fin;
    reg [1:0]   r_inst_byte_cnt;
    reg [ 7:0]  r_inst_data;                // Instruction Data
    reg [3:0]   r_sram_clr_req;
    reg [3:0]   r_sram_write_req;
    reg [3:0]   r_sram_waddr_set_req;
    
    //reg         r_inst_en;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            r_inst_data[7:0] <= 8'd0;
            r_pixel_data_fin <= 1'b0;
            o_col_addr[31:0] <= 32'd0;
            r_inst_byte_cnt[1:0] <= 2'd0;
            o_row_addr[31:0] <= 32'd0;
            o_pwm_duty <= 8'd255;
            o_dispOn <= 1'b0;
            r_sram_clr_req[3:0] <= 4'd0;
            r_sram_write_req[3:0] <= 4'd0;
            r_sram_waddr_set_req[3:0] <= 4'd0;
        end else begin
            if (i_spi_rxdone & ~i_spi_dc) begin
                // dc:low = Command
                r_inst_data[7:0] <= i_spi_data[7:0];
                r_pixel_data_fin <= 1'b0;
                r_inst_byte_cnt[1:0] <= 2'd0;

                // 1Byteで完結するコマンドは即時実行可能
                // Instruction分岐
                case (i_spi_data[7:0])
                    CMD_NOP : ;

                    CMD_SWRESET : begin
                            // Software reset
                            o_pwm_duty[7:0] <= 8'd255;
                            r_sram_clr_req[3:0] <= 4'd1;      // SRAMクリア
                            o_dispOn <= 1'b0;                 // Display OFF
                        end
                    CMD_DISPOFF : begin
                            o_dispOn <= 1'b0;
                        end
                    CMD_DISPON  : begin
                            o_dispOn <= 1'b1;
                        end
                    default : ;
                endcase
            end else if (i_spi_rxdone & i_spi_dc) begin

                // Instruction分岐
                case (r_inst_data[7:0])
                    CMD_RAMWR : begin
                            // ピクセルデータ取得
                            r_mosi_16_pixel_data[15:0] <= {r_mosi_16_pixel_data[7:0], i_spi_data[7:0]};
                            r_pixel_data_fin <= ~r_pixel_data_fin;
                            if (r_pixel_data_fin) begin
                                r_sram_write_req[3:0] <= 4'd1;
                            end
                        end
                    CMD_CASET : begin
                            // Column Address Set
                            o_col_addr[31:0] <= {o_col_addr[23:0], i_spi_data[7:0]};
                            r_inst_byte_cnt[1:0] <= r_inst_byte_cnt[1:0] + 2'd1;
                            if (r_inst_byte_cnt[1:0] == 2'd3) begin
                                r_sram_waddr_set_req[3:0] <= 4'd1;
                            end
                        end
                    CMD_RASET : begin
                            // Row Address Set
                            o_row_addr[31:0] <= {o_row_addr[23:0], i_spi_data[7:0]};
                            r_inst_byte_cnt[1:0] <= r_inst_byte_cnt[1:0] + 2'd1;
                            if (r_inst_byte_cnt[1:0] == 2'd3) begin
                                r_sram_waddr_set_req[3:0] <= 4'd1;
                            end
                        end
                    CMD_PWMDS : begin
                            // PWM Duty Set
                            o_pwm_duty[7:0] <= i_spi_data[7:0];
                        end
                    default : ;
                endcase
            
            end else begin
                r_sram_clr_req[3:0] <= {r_sram_clr_req[2:0], 1'b0};
                r_sram_write_req[3:0] <= {r_sram_write_req[2:0], 1'b0};
                r_sram_waddr_set_req[3:0] <= {r_sram_waddr_set_req[2:0], 1'b0};
            end
        end
    end

    assign o_pixel_data[15:0]   = r_mosi_16_pixel_data[15:0];
    // 4 x i_clk伸長
    assign o_sram_clr_req       = |r_sram_clr_req[3:0];
    assign o_sram_write_req     = |r_sram_write_req[3:0];
    assign o_sram_waddr_set_req = |r_sram_waddr_set_req[3:0];

endmodule