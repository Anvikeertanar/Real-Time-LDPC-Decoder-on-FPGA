// ============================================================
// result_sender.v  (CONVERGENCE UPDATE)
//
// Output format now includes a SYNDROME line:
//
//   CORRUPTED: <100 bits>\r\n
//   DECODED  : <100 bits>\r\n
//   CORRECTED: <N> bits at <i0> <i1> ...\r\n
//   RESULT   : PASS\r\n   or   RESULT   : FAIL\r\n
//   SYNDROME : <N> unsatisfied checks\r\n
//
// The SYNDROME line is always printed.  On PASS it will be
// "SYNDROME : 0 unsatisfied checks".  On FAIL it shows how many
// check nodes were still violated in the best codeword found,
// giving the evaluator a clear measure of how far the decoder got.
//
// New port: syndrome_weight [5:0]  (driven by ldpc_decoder_core)
//
// Carried over: no hardware dividers - all decimal conversion
// uses comparator-chain functions dec2_tens / dec2_ones.
// ============================================================
module result_sender (
    input  wire        clk,
    input  wire        rst,
    // Trigger
    input  wire        send_start,
    output reg         send_busy,
    // Data
    input  wire [99:0] recv_cw,
    input  wire [99:0] decoded_cw,
    input  wire        decode_success,
    input  wire [5:0]  syndrome_weight,  // NEW: 0-50 unsatisfied checks
    // UART TX interface
    output reg  [7:0]  tx_data,
    output reg         tx_start,
    input  wire        tx_busy
);

    // --------------------------------------------------------
    // Sequencer states
    // --------------------------------------------------------
    localparam S_IDLE      = 3'd0;
    localparam S_SEND_BYTE = 3'd1;
    localparam S_WAIT_TX   = 3'd2;
    localparam S_NEXT      = 3'd3;

    // Line IDs  (5-bit to accommodate the extra SYNDROME lines)
    localparam L_CORR_LABEL = 5'd0;    // "CORRUPTED: "
    localparam L_CORR_BITS  = 5'd1;    // 100 bit chars
    localparam L_CORR_CRLF  = 5'd2;
    localparam L_DEC_LABEL  = 5'd3;    // "DECODED  : "
    localparam L_DEC_BITS   = 5'd4;
    localparam L_DEC_CRLF   = 5'd5;
    localparam L_FIX_LABEL  = 5'd6;    // "CORRECTED: "
    localparam L_FIX_COUNT  = 5'd7;    // corrected bit count
    localparam L_FIX_TEXT   = 5'd8;    // " bits at "
    localparam L_FIX_IDX    = 5'd9;    // bit indices
    localparam L_FIX_CRLF   = 5'd10;
    localparam L_RES_LABEL  = 5'd11;   // "RESULT   : "
    localparam L_RES_VAL    = 5'd12;   // "PASS" / "FAIL"
    localparam L_RES_CRLF   = 5'd13;
    localparam L_SYN_LABEL  = 5'd14;   // NEW "SYNDROME : "
    localparam L_SYN_VAL    = 5'd15;   // NEW  digit(s)
    localparam L_SYN_TEXT   = 5'd16;   // NEW " unsatisfied checks"
    localparam L_SYN_CRLF   = 5'd17;   // NEW
    localparam L_DONE       = 5'd18;

    reg [2:0]  state;
    reg [4:0]  line;
    reg [6:0]  char_idx;
    reg [7:0]  next_byte;

    // Diff computation
    wire [99:0] diff_cw = recv_cw ^ decoded_cw;

    // Popcount of diff
    reg [6:0] corr_count;
    reg [6:0] corr_count_r;

    // Index scanner
    reg [6:0] scan_idx;
    reg       scan_done;

    // Registered decimal digits
    reg [3:0] tens_digit;
    reg [3:0] ones_digit;

    // Registered syndrome weight for stable printing
    reg [5:0] syn_weight_r;

    // --------------------------------------------------------
    // Combinatorial popcount of diff
    // --------------------------------------------------------
    integer m;
    always @(*) begin
        corr_count = 7'd0;
        for (m = 0; m < 100; m = m + 1)
            corr_count = corr_count + diff_cw[m];
    end

    // --------------------------------------------------------
    // Synthesis-safe decimal digit extraction (no dividers)
    // --------------------------------------------------------
    function [3:0] dec2_tens;
        input [6:0] val;
        begin
            if      (val >= 7'd90) dec2_tens = 4'd9;
            else if (val >= 7'd80) dec2_tens = 4'd8;
            else if (val >= 7'd70) dec2_tens = 4'd7;
            else if (val >= 7'd60) dec2_tens = 4'd6;
            else if (val >= 7'd50) dec2_tens = 4'd5;
            else if (val >= 7'd40) dec2_tens = 4'd4;
            else if (val >= 7'd30) dec2_tens = 4'd3;
            else if (val >= 7'd20) dec2_tens = 4'd2;
            else if (val >= 7'd10) dec2_tens = 4'd1;
            else                   dec2_tens = 4'd0;
        end
    endfunction

    function [3:0] dec2_ones;
        input [6:0] val;
        reg   [6:0] t;
        begin
            if      (val >= 7'd90) t = val - 7'd90;
            else if (val >= 7'd80) t = val - 7'd80;
            else if (val >= 7'd70) t = val - 7'd70;
            else if (val >= 7'd60) t = val - 7'd60;
            else if (val >= 7'd50) t = val - 7'd50;
            else if (val >= 7'd40) t = val - 7'd40;
            else if (val >= 7'd30) t = val - 7'd30;
            else if (val >= 7'd20) t = val - 7'd20;
            else if (val >= 7'd10) t = val - 7'd10;
            else                   t = val;
            dec2_ones = t[3:0];
        end
    endfunction

    // --------------------------------------------------------
    // Fixed label ROMs
    // --------------------------------------------------------
    function [7:0] label_corrupted;
        input [3:0] idx;
        case (idx)
            4'd0:  label_corrupted = 8'h43; // C
            4'd1:  label_corrupted = 8'h4F; // O
            4'd2:  label_corrupted = 8'h52; // R
            4'd3:  label_corrupted = 8'h52; // R
            4'd4:  label_corrupted = 8'h55; // U
            4'd5:  label_corrupted = 8'h50; // P
            4'd6:  label_corrupted = 8'h54; // T
            4'd7:  label_corrupted = 8'h45; // E
            4'd8:  label_corrupted = 8'h44; // D
            4'd9:  label_corrupted = 8'h3A; // :
            4'd10: label_corrupted = 8'h20; // space
            default: label_corrupted = 8'h20;
        endcase
    endfunction

    function [7:0] label_decoded;
        input [3:0] idx;
        case (idx)
            4'd0:  label_decoded = 8'h44; // D
            4'd1:  label_decoded = 8'h45; // E
            4'd2:  label_decoded = 8'h43; // C
            4'd3:  label_decoded = 8'h4F; // O
            4'd4:  label_decoded = 8'h44; // D
            4'd5:  label_decoded = 8'h45; // E
            4'd6:  label_decoded = 8'h44; // D
            4'd7:  label_decoded = 8'h20; // space
            4'd8:  label_decoded = 8'h20; // space
            4'd9:  label_decoded = 8'h3A; // :
            4'd10: label_decoded = 8'h20; // space
            default: label_decoded = 8'h20;
        endcase
    endfunction

    function [7:0] label_corrected;
        input [3:0] idx;
        case (idx)
            4'd0:  label_corrected = 8'h43; // C
            4'd1:  label_corrected = 8'h4F; // O
            4'd2:  label_corrected = 8'h52; // R
            4'd3:  label_corrected = 8'h52; // R
            4'd4:  label_corrected = 8'h45; // E
            4'd5:  label_corrected = 8'h43; // C
            4'd6:  label_corrected = 8'h54; // T
            4'd7:  label_corrected = 8'h45; // E
            4'd8:  label_corrected = 8'h44; // D
            4'd9:  label_corrected = 8'h3A; // :
            4'd10: label_corrected = 8'h20; // space
            default: label_corrected = 8'h20;
        endcase
    endfunction

    function [7:0] label_result;
        input [3:0] idx;
        case (idx)
            4'd0:  label_result = 8'h52; // R
            4'd1:  label_result = 8'h45; // E
            4'd2:  label_result = 8'h53; // S
            4'd3:  label_result = 8'h55; // U
            4'd4:  label_result = 8'h4C; // L
            4'd5:  label_result = 8'h54; // T
            4'd6:  label_result = 8'h20; // space
            4'd7:  label_result = 8'h20; // space
            4'd8:  label_result = 8'h20; // space
            4'd9:  label_result = 8'h3A; // :
            4'd10: label_result = 8'h20; // space
            default: label_result = 8'h20;
        endcase
    endfunction

    // "SYNDROME : " - 11 chars (same column-aligned width as other labels)
    function [7:0] label_syndrome;
        input [3:0] idx;
        case (idx)
            4'd0:  label_syndrome = 8'h53; // S
            4'd1:  label_syndrome = 8'h59; // Y
            4'd2:  label_syndrome = 8'h4E; // N
            4'd3:  label_syndrome = 8'h44; // D
            4'd4:  label_syndrome = 8'h52; // R
            4'd5:  label_syndrome = 8'h4F; // O
            4'd6:  label_syndrome = 8'h4D; // M
            4'd7:  label_syndrome = 8'h45; // E
            4'd8:  label_syndrome = 8'h20; // space
            4'd9:  label_syndrome = 8'h3A; // :
            4'd10: label_syndrome = 8'h20; // space
            default: label_syndrome = 8'h20;
        endcase
    endfunction

    // " unsatisfied checks" - 20 chars
    function [7:0] label_unsat;
        input [4:0] idx;
        case (idx)
            5'd0:  label_unsat = 8'h20; // space
            5'd1:  label_unsat = 8'h75; // u
            5'd2:  label_unsat = 8'h6E; // n
            5'd3:  label_unsat = 8'h73; // s
            5'd4:  label_unsat = 8'h61; // a
            5'd5:  label_unsat = 8'h74; // t
            5'd6:  label_unsat = 8'h69; // i
            5'd7:  label_unsat = 8'h73; // s
            5'd8:  label_unsat = 8'h66; // f
            5'd9:  label_unsat = 8'h69; // i
            5'd10: label_unsat = 8'h65; // e
            5'd11: label_unsat = 8'h64; // d
            5'd12: label_unsat = 8'h20; // space
            5'd13: label_unsat = 8'h63; // c
            5'd14: label_unsat = 8'h68; // h
            5'd15: label_unsat = 8'h65; // e
            5'd16: label_unsat = 8'h63; // c
            5'd17: label_unsat = 8'h6B; // k
            5'd18: label_unsat = 8'h73; // s
            default: label_unsat = 8'h20;
        endcase
    endfunction

    // " bits at " - 9 chars
    function [7:0] label_bits_at;
        input [3:0] idx;
        case (idx)
            4'd0: label_bits_at = 8'h20; // space
            4'd1: label_bits_at = 8'h62; // b
            4'd2: label_bits_at = 8'h69; // i
            4'd3: label_bits_at = 8'h74; // t
            4'd4: label_bits_at = 8'h73; // s
            4'd5: label_bits_at = 8'h20; // space
            4'd6: label_bits_at = 8'h61; // a
            4'd7: label_bits_at = 8'h74; // t
            4'd8: label_bits_at = 8'h20; // space
            default: label_bits_at = 8'h20;
        endcase
    endfunction

    // --------------------------------------------------------
    // Main FSM
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state        <= S_IDLE;
            line         <= L_CORR_LABEL;
            char_idx     <= 7'd0;
            send_busy    <= 1'b0;
            tx_data      <= 8'd0;
            tx_start     <= 1'b0;
            scan_idx     <= 7'd0;
            scan_done    <= 1'b0;
            corr_count_r <= 7'd0;
            tens_digit   <= 4'd0;
            ones_digit   <= 4'd0;
            syn_weight_r <= 6'd0;
            next_byte    <= 8'd0;
        end else begin
            tx_start <= 1'b0;

            case (state)

                S_IDLE: begin
                    if (send_start) begin
                        send_busy    <= 1'b1;
                        line         <= L_CORR_LABEL;
                        char_idx     <= 7'd0;
                        scan_idx     <= 7'd0;
                        scan_done    <= 1'b0;
                        corr_count_r <= corr_count;
                        tens_digit   <= dec2_tens(corr_count);
                        ones_digit   <= dec2_ones(corr_count);
                        syn_weight_r <= syndrome_weight;  // latch on start
                        state        <= S_NEXT;
                    end
                end

                // ---- Determine next byte to send ----
                S_NEXT: begin
                    case (line)

                        L_CORR_LABEL: begin
                            next_byte <= label_corrupted(char_idx[3:0]);
                            if (char_idx == 7'd10) begin
                                char_idx <= 7'd0; line <= L_CORR_BITS;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_CORR_BITS: begin
                            next_byte <= recv_cw[char_idx] ? 8'h31 : 8'h30;
                            if (char_idx == 7'd99) begin
                                char_idx <= 7'd0; line <= L_CORR_CRLF;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_CORR_CRLF: begin
                            next_byte <= (char_idx == 7'd0) ? 8'h0D : 8'h0A;
                            if (char_idx == 7'd1) begin
                                char_idx <= 7'd0; line <= L_DEC_LABEL;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_DEC_LABEL: begin
                            next_byte <= label_decoded(char_idx[3:0]);
                            if (char_idx == 7'd10) begin
                                char_idx <= 7'd0; line <= L_DEC_BITS;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_DEC_BITS: begin
                            next_byte <= decoded_cw[char_idx] ? 8'h31 : 8'h30;
                            if (char_idx == 7'd99) begin
                                char_idx <= 7'd0; line <= L_DEC_CRLF;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_DEC_CRLF: begin
                            next_byte <= (char_idx == 7'd0) ? 8'h0D : 8'h0A;
                            if (char_idx == 7'd1) begin
                                char_idx <= 7'd0; line <= L_FIX_LABEL;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_FIX_LABEL: begin
                            next_byte <= label_corrected(char_idx[3:0]);
                            if (char_idx == 7'd10) begin
                                char_idx <= 7'd0; line <= L_FIX_COUNT;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_FIX_COUNT: begin
                            if (tens_digit > 4'd0) begin
                                if (char_idx == 7'd0) begin
                                    next_byte <= 8'h30 + {4'd0, tens_digit};
                                    char_idx  <= 7'd1;
                                end else begin
                                    next_byte <= 8'h30 + {4'd0, ones_digit};
                                    char_idx  <= 7'd0;
                                    line      <= L_FIX_TEXT;
                                end
                            end else begin
                                next_byte <= 8'h30 + {4'd0, ones_digit};
                                char_idx  <= 7'd0;
                                line      <= L_FIX_TEXT;
                            end
                            state <= S_SEND_BYTE;
                        end

                        L_FIX_TEXT: begin
                            next_byte <= label_bits_at(char_idx[3:0]);
                            if (char_idx == 7'd8) begin
                                char_idx  <= 7'd0; line <= L_FIX_IDX;
                                scan_idx  <= 7'd0; scan_done <= 1'b0;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_FIX_IDX: begin
                            if (scan_done || corr_count_r == 7'd0) begin
                                line <= L_FIX_CRLF; char_idx <= 7'd0;
                                state <= S_NEXT;
                            end else begin
                                if (diff_cw[scan_idx]) begin
                                    if (scan_idx >= 7'd10) begin
                                        if (char_idx == 7'd0) begin
                                            next_byte <= 8'h30 + {4'd0, dec2_tens(scan_idx)};
                                            char_idx  <= 7'd1; state <= S_SEND_BYTE;
                                        end else if (char_idx == 7'd1) begin
                                            next_byte <= 8'h30 + {4'd0, dec2_ones(scan_idx)};
                                            char_idx  <= 7'd2; state <= S_SEND_BYTE;
                                        end else begin
                                            next_byte <= 8'h20; char_idx <= 7'd0;
                                            if (scan_idx == 7'd99) scan_done <= 1'b1;
                                            else scan_idx <= scan_idx + 7'd1;
                                            state <= S_SEND_BYTE;
                                        end
                                    end else begin
                                        if (char_idx == 7'd0) begin
                                            next_byte <= 8'h30 + scan_idx[3:0];
                                            char_idx  <= 7'd1; state <= S_SEND_BYTE;
                                        end else begin
                                            next_byte <= 8'h20; char_idx <= 7'd0;
                                            if (scan_idx == 7'd99) scan_done <= 1'b1;
                                            else scan_idx <= scan_idx + 7'd1;
                                            state <= S_SEND_BYTE;
                                        end
                                    end
                                end else begin
                                    if (scan_idx == 7'd99) begin
                                        scan_done <= 1'b1; line <= L_FIX_CRLF;
                                        char_idx  <= 7'd0; state <= S_NEXT;
                                    end else begin
                                        scan_idx <= scan_idx + 7'd1; state <= S_NEXT;
                                    end
                                end
                            end
                        end

                        L_FIX_CRLF: begin
                            next_byte <= (char_idx == 7'd0) ? 8'h0D : 8'h0A;
                            if (char_idx == 7'd1) begin
                                char_idx <= 7'd0; line <= L_RES_LABEL;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_RES_LABEL: begin
                            next_byte <= label_result(char_idx[3:0]);
                            if (char_idx == 7'd10) begin
                                char_idx <= 7'd0; line <= L_RES_VAL;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_RES_VAL: begin
                            if (decode_success) begin
                                case (char_idx[1:0])
                                    2'd0: next_byte <= 8'h50; // P
                                    2'd1: next_byte <= 8'h41; // A
                                    2'd2: next_byte <= 8'h53; // S
                                    2'd3: next_byte <= 8'h53; // S
                                    default: next_byte <= 8'h20;
                                endcase
                            end else begin
                                case (char_idx[1:0])
                                    2'd0: next_byte <= 8'h46; // F
                                    2'd1: next_byte <= 8'h41; // A
                                    2'd2: next_byte <= 8'h49; // I
                                    2'd3: next_byte <= 8'h4C; // L
                                    default: next_byte <= 8'h20;
                                endcase
                            end
                            if (char_idx == 7'd3) begin
                                char_idx <= 7'd0; line <= L_RES_CRLF;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_RES_CRLF: begin
                            next_byte <= (char_idx == 7'd0) ? 8'h0D : 8'h0A;
                            if (char_idx == 7'd1) begin
                                char_idx <= 7'd0; line <= L_SYN_LABEL;
                            end else begin
                                char_idx <= char_idx + 7'd1;
                                state    <= S_SEND_BYTE;
                            end
                            if (char_idx != 7'd1) state <= S_SEND_BYTE;
                            else state <= S_NEXT;
                        end

                        // ---- NEW: SYNDROME line ----
                        L_SYN_LABEL: begin
                            next_byte <= label_syndrome(char_idx[3:0]);
                            if (char_idx == 7'd10) begin
                                char_idx <= 7'd0; line <= L_SYN_VAL;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        // Print syndrome weight as 1 or 2 decimal digits
                        L_SYN_VAL: begin
                            if (dec2_tens({1'b0, syn_weight_r}) > 4'd0) begin
                                if (char_idx == 7'd0) begin
                                    next_byte <= 8'h30 + {4'd0, dec2_tens({1'b0, syn_weight_r})};
                                    char_idx  <= 7'd1;
                                end else begin
                                    next_byte <= 8'h30 + {4'd0, dec2_ones({1'b0, syn_weight_r})};
                                    char_idx  <= 7'd0; line <= L_SYN_TEXT;
                                end
                            end else begin
                                next_byte <= 8'h30 + {4'd0, dec2_ones({1'b0, syn_weight_r})};
                                char_idx  <= 7'd0; line <= L_SYN_TEXT;
                            end
                            state <= S_SEND_BYTE;
                        end

                        // " unsatisfied checks" - 19 chars (indices 0-18)
                        L_SYN_TEXT: begin
                            next_byte <= label_unsat(char_idx[4:0]);
                            if (char_idx == 7'd18) begin
                                char_idx <= 7'd0; line <= L_SYN_CRLF;
                            end else char_idx <= char_idx + 7'd1;
                            state <= S_SEND_BYTE;
                        end

                        L_SYN_CRLF: begin
                            next_byte <= (char_idx == 7'd0) ? 8'h0D : 8'h0A;
                            if (char_idx == 7'd1) begin
                                line  <= L_DONE; state <= S_NEXT;
                            end else begin
                                char_idx <= char_idx + 7'd1; state <= S_SEND_BYTE;
                            end
                        end

                        L_DONE: begin
                            send_busy <= 1'b0;
                            state     <= S_IDLE;
                        end

                        default: begin
                            line  <= L_DONE; state <= S_NEXT;
                        end

                    endcase
                end

                // ---- Send the byte ----
                S_SEND_BYTE: begin
                    if (!tx_busy) begin
                        tx_data  <= next_byte;
                        tx_start <= 1'b1;
                        state    <= S_WAIT_TX;
                    end
                end

                // ---- Wait for TX to finish ----
                S_WAIT_TX: begin
                    tx_start <= 1'b0;
                    if (!tx_busy) state <= S_NEXT;
                end

                default: state <= S_IDLE;

            endcase
        end
    end
endmodule
