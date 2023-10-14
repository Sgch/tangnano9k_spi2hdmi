/*************************************************************
 * Title : SPI Slave for RasPi SPI Display (ST7735R)
 * Date  : 2019/8/6
 *************************************************************/
 // DC信号なし版
module spi_slave (
    input   wire            i_clk,          // FPGA内部CLK
    input   wire            i_rst_n,        // RESET
    input   wire            i_spi_clk,      // SPI_CLK
    input   wire            i_spi_cs,       // SPI_CS
    input   wire            i_spi_mosi,     // SPI_MOSI
//    input   wire            i_dc,           // DC(H:Data / L:Command)

    // output
    output  reg     [ 7:0]  o_data,
    output  reg             o_dc,
    output  reg             o_rxdone
    );

    /**************************************************************
     * SPI受信(DC状態はLSBのサンプリングと同時に行う）
     *************************************************************/
    reg [ 7:0]  r_mosi_shift_8;     // 受信データ
    reg [ 2:0]  r_mosi_8bitCnt;     // 受信bit数検知用
    wire        w_mosi_8bit_rx_fin = &r_mosi_8bitCnt[2:0];
    reg         r_mosi_8bit_rx_done;
    reg [ 1:0]  r_mosi_byte_cnt;

    // SPI_CLKでデータ受信
    always @(posedge i_spi_clk or posedge i_spi_cs) begin
        if (i_spi_cs) begin
            r_mosi_8bitCnt[2:0] <= 3'd0;
            r_mosi_8bit_rx_done <= 1'b0;
            r_mosi_byte_cnt <= 2'd0;
            o_dc <= 1'b0;
        end else begin
            // データ受信
            r_mosi_shift_8[7:0] <= {r_mosi_shift_8[6:0], i_spi_mosi};

            // 受信bit数カウント
            if (w_mosi_8bit_rx_fin) begin
                r_mosi_8bitCnt[2:0] <= 3'd0;
            end else begin
                r_mosi_8bitCnt[2:0] <= r_mosi_8bitCnt[2:0] + 3'd1;
            end

            // 受信データとDC状態ラッチ
            if (w_mosi_8bit_rx_fin) begin
                o_data[7:0] <= {r_mosi_shift_8[6:0], i_spi_mosi};
                r_mosi_8bit_rx_done <= 1'b1;

                if (r_mosi_byte_cnt == 2'd1) begin
                    o_dc <= 1'b1;
                end
                else if (r_mosi_byte_cnt < 2'd2) begin
                    r_mosi_byte_cnt <= r_mosi_byte_cnt + 2'd1;
                end
            end else if (r_mosi_8bitCnt[2:0] == 3'd3) begin
                r_mosi_8bit_rx_done <= 1'b0;
            end
        end
    end

    /**************************************************************
     * 受信完了フラグのクロック載せ替え(i_spi_clk => i_clk)
     *************************************************************/
    // r_mosi_8bit_rx_doneの立ち上がり検出
    reg [ 1:0]  r_mosi_8bit_rx_fin_ff;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            r_mosi_8bit_rx_fin_ff[1:0] <= 2'd0;
            o_rxdone <= 1'b0;
        end else begin
            r_mosi_8bit_rx_fin_ff[1:0] <= {r_mosi_8bit_rx_fin_ff[0], r_mosi_8bit_rx_done};
            o_rxdone <= (r_mosi_8bit_rx_fin_ff[1:0] == 2'b01);
        end
    end

endmodule