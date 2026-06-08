// ============================================================
// ldpc_decoder_core.v  (CONVERGENCE UPDATE)
//
// Changes in this version:
//
//  1. MAX_ITER raised 20 → 50
//       Gives the algorithm more attempts on borderline cases
//       such as 2-error inputs that land in a shallow trapping set.
//
//  2. Best-codeword tracker
//       At every S_CHECK that does not yet pass, the current
//       codeword is compared against the best seen so far
//       (measured by syndrome weight = number of unsatisfied
//       check nodes).  If the current word is better it is saved
//       to best_codeword / best_syn_weight.
//       On FAIL, decoded_cw outputs best_codeword instead of the
//       oscillation endpoint - the closest the decoder ever got.
//
//  3. syndrome_weight output  [5:0]  (0-50)
//       Combinatorial popcount of the syndrome register.
//       Wired to result_sender so "SYNDROME : N" can be printed.
//
//  4. Re-arm support (carried over from previous fix)
//       S_SUCCESS / S_FAIL return to S_LOAD on a new load pulse.
// ============================================================
module ldpc_decoder_core (
    input  wire        clk,
    input  wire        rst,
    input  wire [99:0] recv_cw_in,
    input  wire        load,
    output reg         done,
    output reg         success,
    output reg         fail,
    output wire [99:0] decoded_cw,
    output wire [5:0]  syndrome_weight   // NEW: unsatisfied check count
);

    localparam [5:0] MAX_ITER = 6'd50;   // raised from 20

    localparam [3:0]
        S_IDLE     = 4'd0,
        S_LOAD     = 4'd1,
        S_CLEAR    = 4'd2,
        S_ROM_WAIT = 4'd3,
        S_ACCUM    = 4'd4,
        S_NEXT_CN  = 4'd5,
        S_CHECK    = 4'd6,
        S_FLIP     = 4'd7,
        S_WAIT_FLP = 4'd8,
        S_SUCCESS  = 4'd9,
        S_FAIL     = 4'd10;

    reg [3:0]  state;
    reg [99:0] codeword;
    reg [49:0] syndrome;
    reg [5:0]  iter_count;
    reg [5:0]  cn_idx;

    // Best-codeword tracker
    reg [99:0] best_codeword;
    reg [5:0]  best_syn_weight;

    // decoded_cw always reflects the best codeword found
    assign decoded_cw = best_codeword;

    // Combinatorial syndrome popcount (0-50)
    reg [5:0] syn_weight_comb;
    integer k;
    always @(*) begin
        syn_weight_comb = 6'd0;
        for (k = 0; k < 50; k = k + 1)
            syn_weight_comb = syn_weight_comb + {5'd0, syndrome[k]};
    end
    assign syndrome_weight = syn_weight_comb;

    wire syndrome_zero = ~(|syndrome);

    // ROM interface
    reg  [5:0]  rom_addr;
    wire [99:0] rom_row;

    // Syndrome unit
    wire syn_bit;

    // Bit-flip counter
    reg         cnt_clear;
    reg         cnt_accum;
    reg         cnt_flip;
    wire [99:0] cw_flipped;
    wire        flip_done;

    // --------------------------------------------------------
    h_matrix_rom u_rom (
        .clk      (clk),
        .row_addr (rom_addr),
        .row_data (rom_row)
    );

    syndrome_unit u_syn (
        .h_row    (rom_row),
        .codeword (codeword),
        .syn_bit  (syn_bit)
    );

    bit_flip_counter u_cnt (
        .clk         (clk),
        .rst         (rst),
        .clear       (cnt_clear),
        .accum_en    (cnt_accum),
        .flip_en     (cnt_flip),
        .syn_bit     (syn_bit),
        .h_row       (rom_row),
        .codeword_in (codeword),
        .codeword_out(cw_flipped),
        .flip_done   (flip_done)
    );

    // --------------------------------------------------------
    // FSM
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state           <= S_IDLE;
            codeword        <= 100'd0;
            syndrome        <= 50'd0;
            iter_count      <= 6'd0;
            cn_idx          <= 6'd0;
            rom_addr        <= 6'd0;
            cnt_clear       <= 1'b0;
            cnt_accum       <= 1'b0;
            cnt_flip        <= 1'b0;
            done            <= 1'b0;
            success         <= 1'b0;
            fail            <= 1'b0;
            best_codeword   <= 100'd0;
            best_syn_weight <= 6'd50;
        end else begin
            cnt_clear <= 1'b0;
            cnt_accum <= 1'b0;
            cnt_flip  <= 1'b0;

            case (state)

                S_IDLE: begin
                    done    <= 1'b0;
                    success <= 1'b0;
                    fail    <= 1'b0;
                    if (load) state <= S_LOAD;
                end

                S_LOAD: begin
                    codeword        <= recv_cw_in;
                    iter_count      <= 6'd0;
                    // Initialise best to the received word; updated at S_CHECK
                    best_codeword   <= recv_cw_in;
                    best_syn_weight <= 6'd50;
                    state           <= S_CLEAR;
                end

                S_CLEAR: begin
                    syndrome  <= 50'd0;
                    cn_idx    <= 6'd0;
                    rom_addr  <= 6'd0;
                    cnt_clear <= 1'b1;
                    state     <= S_ROM_WAIT;
                end

                S_ROM_WAIT: begin
                    state <= S_ACCUM;
                end

                S_ACCUM: begin
                    syndrome[cn_idx] <= syn_bit;
                    cnt_accum        <= 1'b1;
                    state            <= S_NEXT_CN;
                end

                S_NEXT_CN: begin
                    if (cn_idx == 6'd49) begin
                        state <= S_CHECK;
                    end else begin
                        cn_idx   <= cn_idx + 6'd1;
                        rom_addr <= cn_idx + 6'd1;
                        state    <= S_ROM_WAIT;
                    end
                end

                S_CHECK: begin
                    if (syndrome_zero) begin
                        // Perfect decode - record as best and succeed
                        best_codeword   <= codeword;
                        best_syn_weight <= 6'd0;
                        state           <= S_SUCCESS;
                    end else begin
                        // Update best-codeword tracker before flipping
                        if (syn_weight_comb < best_syn_weight) begin
                            best_codeword   <= codeword;
                            best_syn_weight <= syn_weight_comb;
                        end
                        if (iter_count >= MAX_ITER)
                            state <= S_FAIL;
                        else
                            state <= S_FLIP;
                    end
                end

                S_FLIP: begin
                    cnt_flip <= 1'b1;
                    state    <= S_WAIT_FLP;
                end

                S_WAIT_FLP: begin
                    if (flip_done) begin
                        codeword   <= cw_flipped;
                        iter_count <= iter_count + 6'd1;
                        state      <= S_CLEAR;
                    end
                end

                S_SUCCESS: begin
                    done    <= 1'b1;
                    success <= 1'b1;
                    fail    <= 1'b0;
                    if (load) begin
                        done    <= 1'b0;
                        success <= 1'b0;
                        state   <= S_LOAD;
                    end
                end

                S_FAIL: begin
                    done    <= 1'b1;
                    fail    <= 1'b1;
                    success <= 1'b0;
                    if (load) begin
                        done  <= 1'b0;
                        fail  <= 1'b0;
                        state <= S_LOAD;
                    end
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule
