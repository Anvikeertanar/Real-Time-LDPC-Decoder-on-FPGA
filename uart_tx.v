// ============================================================
// uart_tx.v
// 115200 baud, 8N1, 100 MHz clock
//
// Assert tx_start for one cycle with tx_data valid.
// tx_busy stays HIGH until the stop bit is complete.
// Do not assert tx_start while tx_busy is HIGH.
// ============================================================
module uart_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx_busy,
    output reg        uart_txd
);

    localparam CLKS_PER_BIT = 868;

    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;
    localparam S_DATA  = 3'd2;
    localparam S_STOP  = 3'd3;

    reg [9:0] clk_cnt;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;
    reg [2:0] state;

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            clk_cnt   <= 10'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            tx_busy   <= 1'b0;
            uart_txd  <= 1'b1;   // idle HIGH
        end else begin
            case (state)
                S_IDLE: begin
                    uart_txd <= 1'b1;
                    clk_cnt  <= 10'd0;
                    bit_idx  <= 3'd0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tx_busy   <= 1'b1;
                        state     <= S_START;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end
                // Send start bit (LOW)
                S_START: begin
                    uart_txd <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 10'd0;
                        state   <= S_DATA;
                    end else clk_cnt <= clk_cnt + 10'd1;
                end
                // Send 8 data bits LSB first
                S_DATA: begin
                    uart_txd <= shift_reg[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 10'd0;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= S_STOP;
                        end else bit_idx <= bit_idx + 3'd1;
                    end else clk_cnt <= clk_cnt + 10'd1;
                end
                // Send stop bit (HIGH)
                S_STOP: begin
                    uart_txd <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 10'd0;
                        tx_busy <= 1'b0;
                        state   <= S_IDLE;
                    end else clk_cnt <= clk_cnt + 10'd1;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
