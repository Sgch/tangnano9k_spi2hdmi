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

    function [5:0] InstructionROM(input [7:0] inst_code);
    begin
        case(inst_code)
        //                             { exist_arg, variable_arg_len, arg_len-1 }
        CMD_GAMMASET: InstructionROM = { 1'b1, 1'b0, 4'd0  };
        CMD_CASET:    InstructionROM = { 1'b1, 1'b0, 4'd3  };
        CMD_RASET:    InstructionROM = { 1'b1, 1'b0, 4'd3  };
        CMD_RAMWR:    InstructionROM = { 1'b1, 1'b1, 4'd0  };
        CMD_MADCTL:   InstructionROM = { 1'b1, 1'b0, 4'd0  };
        CMD_COLMOD:   InstructionROM = { 1'b1, 1'b0, 4'd0  };
        CMD_FRMCTR1:  InstructionROM = { 1'b1, 1'b0, 4'd2  };
        CMD_FRMCTR2:  InstructionROM = { 1'b1, 1'b0, 4'd2  };
        CMD_FRMCTR3:  InstructionROM = { 1'b1, 1'b0, 4'd5  };
        CMD_INVCTR:   InstructionROM = { 1'b1, 1'b0, 4'd0  };
        CMD_PWCTR1:   InstructionROM = { 1'b1, 1'b0, 4'd2  };
        CMD_PWCTR2:   InstructionROM = { 1'b1, 1'b0, 4'd0  };
        CMD_PWCTR3:   InstructionROM = { 1'b1, 1'b0, 4'd1  };
        CMD_PWCTR4:   InstructionROM = { 1'b1, 1'b0, 4'd1  };
        CMD_PWCTR5:   InstructionROM = { 1'b1, 1'b0, 4'd1  };
        CMD_VMCTR1:   InstructionROM = { 1'b1, 1'b0, 4'd0  };
        CMD_VMOFCTR:  InstructionROM = { 1'b1, 1'b0, 4'd0  };
        CMD_WRID2:    InstructionROM = { 1'b1, 1'b0, 4'd0  };
        CMD_WRID3:    InstructionROM = { 1'b1, 1'b0, 4'd0  };
        CMD_NVCTR1:   InstructionROM = { 1'b1, 1'b0, 4'd0  };
        CMD_NVCTR3:   InstructionROM = { 1'b1, 1'b0, 4'd1  };
        CMD_GAMCTRP1: InstructionROM = { 1'b1, 1'b0, 4'd15 };
        CMD_GAMCTRN1: InstructionROM = { 1'b1, 1'b0, 4'd15 };
        default:      InstructionROM = { 1'b0, 1'b0, 4'd0  };
        endcase
    end
    endfunction

    /**************************************************************
     *  SPI受信データ処理 / データ書き込み要求処理
     *************************************************************/
    reg         r_dc;
    reg [3:0]   r_inst_args_cnt;
    reg         r_inst_args_varlen;
    reg [ 7:0]  r_inst_data;                // Instruction Data
    wire        w_inst_done;

    //reg         r_inst_en;
    wire   w_on_inst;
    assign w_on_inst = i_spi_rxdone & ~r_dc;
    wire   w_on_args;
    assign w_on_args = i_spi_rxdone & r_dc;
    wire   w_on_end_args;
    assign w_on_end_args = (r_inst_args_cnt == 5'd0);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            r_dc <= 1'b0;
            r_inst_data[7:0] <= 8'd0;
            r_inst_args_cnt <= 4'd0;
            r_inst_args_varlen <= 1'b0;
        end else if (i_spi_csreleased) begin
            r_dc <= 1'b0;
            r_inst_data[7:0] <= 8'd0;
            r_inst_args_cnt <= 4'd0;
            r_inst_args_varlen <= 1'b0;
        end else begin
            if (w_on_inst) begin
                r_inst_data[7:0] <= i_spi_data[7:0];
                { r_dc, r_inst_args_varlen, r_inst_args_cnt } <= InstructionROM(i_spi_data);
            end else if (w_on_args) begin
                r_inst_args_cnt <= r_inst_args_cnt - 5'd1;
                if (w_on_end_args && !r_inst_args_varlen) begin
                    r_dc <= 1'b0;
                end
            end else if (w_inst_done && r_inst_args_varlen) begin
                r_dc <= 1'b0;
            end
        end
    end

    // sram clear
    reg r_sram_clr_req;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_sram_clr_req <= 1'b0;
        end else if (w_on_inst && (i_spi_data == CMD_SWRESET)) begin
            r_sram_clr_req <= 1'b1;
        end else begin
            r_sram_clr_req <= 1'b0;
        end
    end
    assign o_sram_clr_req = r_sram_clr_req;

    // disp on
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_dispOn <= 1'b0;
        end else if (w_on_inst) begin
            case (i_spi_data)
                CMD_SWRESET: o_dispOn <= 1'b0;
                CMD_DISPOFF: o_dispOn <= 1'b0;
                CMD_DISPON:  o_dispOn <= 1'b1;
                default: ; // hold
            endcase
        end
    end

    // column address
    reg r_sram_col_addr_set_req;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_sram_col_addr_set_req <= 1'b0;
            o_col_addr <= 32'd0;
        end else if (w_on_args && (r_inst_data == CMD_CASET)) begin
            o_col_addr <= { o_col_addr[23:0], i_spi_data };
            if (w_on_end_args) begin
                r_sram_col_addr_set_req <= 1'b1;
            end
        end else begin
            r_sram_col_addr_set_req <= 1'b0;
        end
    end
    // row address
    reg r_sram_row_addr_set_req;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_sram_row_addr_set_req <= 1'b0;
            o_row_addr <= 32'd0;
        end else if (w_on_args && (r_inst_data == CMD_RASET)) begin
            o_row_addr <= { o_row_addr[23:0], i_spi_data };
            if (w_on_end_args) begin
                r_sram_row_addr_set_req <= 1'b1;
            end
        end else begin
            r_sram_row_addr_set_req <= 1'b0;
        end
    end
    assign o_sram_waddr_set_req = r_sram_col_addr_set_req | r_sram_row_addr_set_req;

    // ram write
    reg [15:0] r_mosi_16_pixel_data;
    reg        r_pixel_data_fin;
    reg        r_sram_write_req;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_pixel_data_fin <= 1'b0;
            r_mosi_16_pixel_data <= 16'd0;
            r_sram_write_req <= 1'b0;
        end else if (w_on_args && (r_inst_data == CMD_RAMWR)) begin
            r_mosi_16_pixel_data <= { r_mosi_16_pixel_data[7:0], i_spi_data };
            r_pixel_data_fin <= ~r_pixel_data_fin;
            if (r_pixel_data_fin) begin
                r_sram_write_req <= 1'b1;
            end
        end else begin
            r_sram_write_req <= 1'b0;
        end
    end
    assign o_sram_write_req  = r_sram_write_req;
    assign o_pixel_data      = r_mosi_16_pixel_data;

    // ram write counter
    wire [31:0] w_sram_write_len;
    assign      w_sram_write_len = (o_col_addr[15:0] - o_col_addr[31:16] + 16'd1) * (o_row_addr[15:0] - o_row_addr[31:16] + 16'd1) - 32'd1;
    reg  [31:0] r_sram_write_left;
    reg         r_sram_write_done;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_sram_write_left <= 32'd0;
            r_sram_write_done <= 1'b0;
        end else if (w_on_inst && (i_spi_data == CMD_RAMWR)) begin
            r_sram_write_left <= w_sram_write_len;
            r_sram_write_done <= 1'b0;
        end else if (w_on_args && (r_inst_data == CMD_RAMWR)) begin
            if (r_pixel_data_fin) begin
                r_sram_write_left <= r_sram_write_left - 32'd1;
                if (r_sram_write_left == 32'd0) begin
                    r_sram_write_done <= 1'b1;
                end
            end
        end
        else begin
            r_sram_write_done <= 1'b0;
        end
    end
    assign w_inst_done = r_sram_write_done;

endmodule