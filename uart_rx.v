// ============================================================
// uart_rx.v  (FIXED)
// 115200 baud, 8N1, 100 MHz clock
// Baud divisor = 100_000_000 / 115200 = 868
//
// rx_valid pulses HIGH for exactly one clock cycle when
// a valid byte has been received in rx_data.
//
// FIX (Issue 4): Stop bit is now validated.
//   Previously S_STOP transitioned unconditionally to S_DONE,
//   silently accepting framing errors (stop bit = 0) and
//   asserting rx_valid with corrupted data.
//   Now: if rxd == 0 at the stop-bit sample point the frame
//   is discarded and the FSM returns to S_IDLE.
// ============================================================
module uart_rx (
    input  wire       clk,
    input  wire       rst,
    input  wire       uart_rxd,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);

    localparam CLKS_PER_BIT = 868;
    localparam HALF_BIT     = 434;

    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;
    localparam S_DATA  = 3'd2;
    localparam S_STOP  = 3'd3;
    localparam S_DONE  = 3'd4;

    // 2-FF synchroniser on RX input
    reg rxd_ff1, rxd_ff2;
    always @(posedge clk) begin
        rxd_ff1 <= uart_rxd;
        rxd_ff2 <= rxd_ff1;
    end
    wire rxd = rxd_ff2;

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
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    clk_cnt <= 10'd0;
                    bit_idx <= 3'd0;
                    if (rxd == 1'b0) state <= S_START;
                end
                S_START: begin
                    if (clk_cnt == HALF_BIT - 1) begin
                        clk_cnt <= 10'd0;
                        if (rxd == 1'b0) state <= S_DATA;
                        else             state <= S_IDLE;
                    end else clk_cnt <= clk_cnt + 10'd1;
                end
                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt            <= 10'd0;
                        shift_reg[bit_idx] <= rxd;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= S_STOP;
                        end else bit_idx <= bit_idx + 3'd1;
                    end else clk_cnt <= clk_cnt + 10'd1;
                end
                // FIX: validate stop bit — discard frame on framing error
                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 10'd0;
                        if (rxd == 1'b1)
                            state <= S_DONE;   // valid stop bit
                        else
                            state <= S_IDLE;   // framing error: discard byte
                    end else clk_cnt <= clk_cnt + 10'd1;
                end
                S_DONE: begin
                    rx_data  <= shift_reg;
                    rx_valid <= 1'b1;
                    state    <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
