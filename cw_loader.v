// ============================================================
// cw_loader.v  (FIXED)
//
// Parses UART input to extract the 100-bit received codeword.
//
// Expected input format (from terminal):
//   RECV:<100 bits>\n
//   e.g. RECV:1000010000000000001000...0000\n
//
// Protocol:
//   1. Waits for 'R','E','C','V',':' prefix
//   2. Reads exactly 100 ASCII '0'/'1' chars into recv_cw
//   3. Asserts load_done for EXACTLY ONE clock cycle on completion
//   4. Stays in DONE until rst or a new 'R' begins a fresh sequence
//
// Non '0'/'1' characters (including \r, \n, spaces) inside the
// 100-bit field are IGNORED and not counted - evaluator can
// backspace and retype without reset.
//
// rst clears everything and returns to WAIT_R.
//
// FIX 1 (Bug): load_done is now a genuine 1-cycle pulse.
//   Previously S_DONE looped back on itself while holding
//   load_done=1, reasserting it every cycle.  The pulse is now
//   generated on the transition cycle into S_DONE.
//
// FIX 2 (Minor): Watchdog timer.
//   If the FSM is stuck waiting for a header character for more
//   than WATCHDOG_CYCLES cycles, it resets to S_WAIT_R so a
//   partial "REC" prefix does not permanently stall the loader.
//   WATCHDOG_CYCLES = 100 MHz * 1 s = 100_000_000
// ============================================================
module cw_loader (
    input  wire        clk,
    input  wire        rst,
    // UART RX interface
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    // Outputs
    output reg  [99:0] recv_cw,
    output reg         load_done,
    // Status for TX echo / debug
    output reg  [6:0]  bit_count    // how many bits received so far (0-100)
);

    // FSM states
    localparam S_WAIT_R    = 4'd0;   // waiting for 'R'
    localparam S_WAIT_E    = 4'd1;   // waiting for 'E'
    localparam S_WAIT_C    = 4'd2;   // waiting for 'C'
    localparam S_WAIT_V    = 4'd3;   // waiting for 'V'
    localparam S_WAIT_COL  = 4'd4;   // waiting for ':'
    localparam S_READ_BITS = 4'd5;   // reading 100 bits
    localparam S_DONE      = 4'd6;   // stays quiet until rst

    // Watchdog: ~1 second at 100 MHz.  Only active during header
    // parsing states (S_WAIT_E .. S_WAIT_COL).
    localparam WATCHDOG_CYCLES = 27'd100_000_000;
    reg [26:0] watchdog;

    reg [3:0] state;

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_WAIT_R;
            recv_cw   <= 100'd0;
            load_done <= 1'b0;
            bit_count <= 7'd0;
            watchdog  <= 27'd0;
        end else begin
            // Default: deassert pulse outputs every cycle
            load_done <= 1'b0;

            case (state)

                // ---- Header parsing ----
                S_WAIT_R: begin
                    watchdog <= 27'd0;
                    if (rx_valid && rx_data == 8'h52) // 'R'
                        state <= S_WAIT_E;
                end

                S_WAIT_E: begin
                    if (rx_valid) begin
                        watchdog <= 27'd0;
                        if (rx_data == 8'h45) state <= S_WAIT_C; // 'E'
                        else                  state <= S_WAIT_R; // restart
                    end else begin
                        // Watchdog: go back to S_WAIT_R on timeout
                        if (watchdog == WATCHDOG_CYCLES - 27'd1) begin
                            watchdog <= 27'd0;
                            state    <= S_WAIT_R;
                        end else watchdog <= watchdog + 27'd1;
                    end
                end

                S_WAIT_C: begin
                    if (rx_valid) begin
                        watchdog <= 27'd0;
                        if (rx_data == 8'h43) state <= S_WAIT_V; // 'C'
                        else                  state <= S_WAIT_R;
                    end else begin
                        if (watchdog == WATCHDOG_CYCLES - 27'd1) begin
                            watchdog <= 27'd0;
                            state    <= S_WAIT_R;
                        end else watchdog <= watchdog + 27'd1;
                    end
                end

                S_WAIT_V: begin
                    if (rx_valid) begin
                        watchdog <= 27'd0;
                        if (rx_data == 8'h56) state <= S_WAIT_COL; // 'V'
                        else                  state <= S_WAIT_R;
                    end else begin
                        if (watchdog == WATCHDOG_CYCLES - 27'd1) begin
                            watchdog <= 27'd0;
                            state    <= S_WAIT_R;
                        end else watchdog <= watchdog + 27'd1;
                    end
                end

                S_WAIT_COL: begin
                    if (rx_valid) begin
                        watchdog <= 27'd0;
                        if (rx_data == 8'h3A) begin // ':'
                            bit_count <= 7'd0;
                            recv_cw   <= 100'd0;
                            state     <= S_READ_BITS;
                        end else state <= S_WAIT_R;
                    end else begin
                        if (watchdog == WATCHDOG_CYCLES - 27'd1) begin
                            watchdog <= 27'd0;
                            state    <= S_WAIT_R;
                        end else watchdog <= watchdog + 27'd1;
                    end
                end

                // ---- Bit collection ----
                S_READ_BITS: begin
                    watchdog <= 27'd0;
                    if (rx_valid) begin
                        if (rx_data == 8'h30 || rx_data == 8'h31) begin
                            // '0' = 0x30, '1' = 0x31
                            // Shift in LSB first: bit 0 = first char received
                            recv_cw[bit_count] <= rx_data[0];
                            bit_count          <= bit_count + 7'd1;
                            if (bit_count == 7'd99) begin
                                // FIX: pulse load_done for exactly this one cycle,
                                // then transition to S_DONE where it stays 0.
                                load_done <= 1'b1;
                                state     <= S_DONE;
                            end
                        end
                        // else: ignore \r, \n, spaces, invalid chars
                    end
                end

                // ---- Done: sit quietly until rst ----
                // load_done is 0 here (cleared at top of else block every cycle)
                S_DONE: begin
                    state <= S_DONE;
                end

                default: state <= S_WAIT_R;

            endcase
        end
    end
endmodule
