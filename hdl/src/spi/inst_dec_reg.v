/*************************************************************
 * Title : Instruction Decoder & Registers
 * Date  : 2019/9/22
 *************************************************************/
module inst_dec_reg (
    input   wire            i_clk,          // FPGA内部CLK
    input   wire            i_rst_n,        // RESET

    // From SPI Slave
    input	wire    [ 7:0]  i_spi_data,
    input   wire            i_spi_csreleased,
    input   wire            i_spi_rxdone,

    // 
    output  wire    [15:0]  o_pixel_data,   // 画素データ
    output  reg     [31:0]  o_col_addr,     // XS15:0[31:16], XE15:0[15:0]
    output  reg     [31:0]  o_row_addr,     // YS15:0[31:16], YE15:0[15:0]

    output  wire            o_sram_clr_req,         // SRAM ALLクリアリクエスト
    output  wire            o_sram_write_req,       // SRAM画素データ書き込みリクエスト
    output  wire            o_sram_waddr_set_req,   // SRAM書き込みアドレス設定リクエスト
    output  reg             o_dispOn
    );

    /**************************************************************
     *  Common Instructions
     *************************************************************/
    localparam CMD_NOP         = 8'h00;
    localparam CMD_SWRESET     = 8'h01;
    //localparam CMD_RDDID       = 8'h04;
    //localparam CMD_RDDST       = 8'h09;
    localparam CMD_SLPIN       = 8'h10;
    localparam CMD_SLPOUT      = 8'h11;
    localparam CMD_PTLON       = 8'h12;
    localparam CMD_NORON       = 8'h13;
    localparam CMD_INVOFF      = 8'h20;
    localparam CMD_INVON       = 8'h21;
    localparam CMD_GAMMASET    = 8'h26;
    localparam CMD_DISPOFF     = 8'h28;
    localparam CMD_DISPON      = 8'h29;
    localparam CMD_CASET       = 8'h2A;
    localparam CMD_RASET       = 8'h2B;
    localparam CMD_PASET       = 8'h2B;
    localparam CMD_RAMWR       = 8'h2C;
    //localparam CMD_RAMRD       = 8'h2E;
    localparam CMD_MADCTL      = 8'h36;
    localparam CMD_IDMOFF      = 8'h38;
    localparam CMD_IDMON       = 8'h39;
    localparam CMD_COLMOD      = 8'h3A;

    /**************************************************************
     *  ST7735R Instruction
     *************************************************************/
    localparam CMD_ACTION_CODE  = 8'hA5;
    localparam CMD_FRMCTR1      = 8'hB1;
    localparam CMD_FRMCTR2      = 8'hB2;
    localparam CMD_FRMCTR3      = 8'hB3;
    localparam CMD_INVCTR       = 8'hB4;

    localparam CMD_PWCTR1       = 8'hC0;
    localparam CMD_PWCTR2       = 8'hC1;
    localparam CMD_PWCTR3       = 8'hC2;
    localparam CMD_PWCTR4       = 8'hC3;
    localparam CMD_PWCTR5       = 8'hC4;
    localparam CMD_VMCTR1       = 8'hC5;
    localparam CMD_VMOFCTR      = 8'hC7;

    localparam CMD_WRID2        = 8'hD1;
    localparam CMD_WRID3        = 8'hD2;

    localparam CMD_NVCTR1       = 8'hD9;
    localparam CMD_NVCTR2       = 8'hDE;
    localparam CMD_NVCTR3       = 8'hDF;

    localparam CMD_GAMCTRP1     = 8'hE0;
    localparam CMD_GAMCTRN1     = 8'hE1;

    // instruction args length ROM
    function [4:0] InstArgsLengthROM(input [7:0] inst_code);
    begin
        case(inst_code)
        CMD_GAMMASET: InstArgsLengthROM = 5'd1;
        CMD_CASET:    InstArgsLengthROM = 5'd4;
        CMD_RASET:    InstArgsLengthROM = 5'd4;
        CMD_RAMWR:    InstArgsLengthROM = 5'd16; // 可変長
        CMD_MADCTL:   InstArgsLengthROM = 5'd1;
        CMD_COLMOD:   InstArgsLengthROM = 5'd1;
        CMD_FRMCTR1:  InstArgsLengthROM = 5'd3;
        CMD_FRMCTR2:  InstArgsLengthROM = 5'd3;
        CMD_FRMCTR3:  InstArgsLengthROM = 5'd6;
        CMD_INVCTR:   InstArgsLengthROM = 5'd1;
        CMD_PWCTR1:   InstArgsLengthROM = 5'd3;
        CMD_PWCTR2:   InstArgsLengthROM = 5'd1;
        CMD_PWCTR3:   InstArgsLengthROM = 5'd2;
        CMD_PWCTR4:   InstArgsLengthROM = 5'd2;
        CMD_PWCTR5:   InstArgsLengthROM = 5'd2;
        CMD_VMCTR1:   InstArgsLengthROM = 5'd1;
        CMD_VMOFCTR:  InstArgsLengthROM = 5'd1;
        CMD_WRID2:    InstArgsLengthROM = 5'd1;
        CMD_WRID3:    InstArgsLengthROM = 5'd1;
        CMD_NVCTR1:   InstArgsLengthROM = 5'd1;
        CMD_NVCTR3:   InstArgsLengthROM = 5'd2;
        CMD_GAMCTRP1: InstArgsLengthROM = 5'd16;
        CMD_GAMCTRN1: InstArgsLengthROM = 5'd16;

        default: InstArgsLengthROM = 5'd0;
        endcase
    end
    endfunction

    /**************************************************************
     *  SPI受信データ処理 / データ書き込み要求処理
     *************************************************************/
    reg         r_dc;
    reg [15:0]  r_mosi_16_pixel_data;
    reg         r_pixel_data_fin;
    reg [4:0]   r_inst_byte_cnt;
    reg [4:0]   r_inst_args_cnt;
    reg [ 7:0]  r_inst_data;                // Instruction Data
    reg [3:0]   r_sram_clr_req;
    reg [3:0]   r_sram_write_req;
    reg [3:0]   r_sram_waddr_set_req;

    //reg         r_inst_en;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            r_dc <= 1'b0;
            r_inst_data[7:0] <= 8'd0;
            r_pixel_data_fin <= 1'b0;
            o_col_addr[31:0] <= 32'd0;
            r_inst_byte_cnt[4:0] <= 5'd0;
            r_inst_args_cnt <= 5'd0;
            o_row_addr[31:0] <= 32'd0;
            r_sram_clr_req[3:0] <= 4'd0;
            r_sram_write_req[3:0] <= 4'd0;
            r_sram_waddr_set_req[3:0] <= 4'd0;
            r_mosi_16_pixel_data <= 16'd0;
            o_dispOn <= 1'b0;
        end else if (i_spi_csreleased) begin
            r_dc <= 1'b0;
            r_inst_data[7:0] <= 8'd0;
            r_pixel_data_fin <= 1'b0;
            r_inst_byte_cnt[4:0] <= 5'd0;
            r_inst_args_cnt <= 5'd0;
        end else begin
            if (i_spi_rxdone & ~r_dc) begin
                // dc:low = Command
                r_inst_data[7:0] <= i_spi_data[7:0];
                r_pixel_data_fin <= 1'b0;
                r_inst_byte_cnt[4:0] <= 5'd0;
                r_dc <= (InstArgsLengthROM(i_spi_data) > 0); // パラメータ(データ)ありコマンド
                r_inst_args_cnt <= InstArgsLengthROM(i_spi_data) - 5'd1;

                // 1Byteで完結するコマンドは即時実行可能
                // Instruction分岐
                case (i_spi_data[7:0])
                    CMD_NOP : ;

                    CMD_SWRESET : begin
                            // Software reset
                            r_sram_clr_req[3:0] <= 4'd1;      // SRAMクリア
                            o_dispOn <= 1'b0;                 // Display OFF
                        end
                    CMD_DISPOFF : begin
                            o_dispOn <= 1'b0;
                        end
                    CMD_DISPON  : begin
                            o_dispOn <= 1'b1;
                        end
                    default :;
                endcase

            end else if (i_spi_rxdone & r_dc) begin

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
                            if (r_inst_byte_cnt[1:0] == 2'd3) begin
                                r_sram_waddr_set_req[3:0] <= 4'd1;
                            end
                        end
                    CMD_RASET : begin
                            // Row Address Set
                            o_row_addr[31:0] <= {o_row_addr[23:0], i_spi_data[7:0]};
                            if (r_inst_byte_cnt[1:0] == 2'd3) begin
                                r_sram_waddr_set_req[3:0] <= 4'd1;
                            end
                        end
                    default : ;
                endcase

                r_inst_byte_cnt <= r_inst_byte_cnt + 5'd1;
                if (r_inst_byte_cnt == r_inst_args_cnt && (r_inst_data != CMD_RAMWR)) begin
                    r_dc <= 1'b0;
                end
            
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