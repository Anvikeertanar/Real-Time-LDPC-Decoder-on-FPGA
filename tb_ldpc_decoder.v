// ============================================================
// tb_ldpc_decoder.v  -  SIMULATION SOURCES ONLY
//
// UART version testbench:
//   - Sends "RECV:<100 bits>\n" over simulated UART at 115200 baud
//   - Monitors decoded output and UART TX response
//   - Writes codeword_output.txt after simulation
//
// Vivado-safe Verilog-2001:
//   - No $countones (replaced with popcount functions)
//   - No $dumpfile
// ============================================================
`timescale 1ns/1ps

module tb_ldpc_decoder;

    // --------------------------------------------------------
    // DUT ports
    // --------------------------------------------------------
    reg  clk, rst;
    reg  uart_rxd;
    wire uart_txd;
    wire done_led, fail_led, decode_success;

    ldpc_top DUT (
        .clk           (clk),
        .rst           (rst),
        .uart_rxd      (uart_rxd),
        .uart_txd      (uart_txd),
        .done_led      (done_led),
        .fail_led      (fail_led),
        .decode_success(decode_success)
    );

    // --------------------------------------------------------
    // Hierarchical signal taps
    // --------------------------------------------------------
    wire [99:0] recv_cw    = DUT.u_loader.recv_cw;
    wire [99:0] decoded_cw = DUT.u_decoder.decoded_cw;
    wire [49:0] syndrome   = DUT.u_decoder.syndrome;
    wire [5:0]  iter_count = DUT.u_decoder.iter_count;
    wire [3:0]  fsm_state  = DUT.u_decoder.state;

    localparam S_SUCCESS = 4'd9;
    localparam S_FAIL    = 4'd10;

    // --------------------------------------------------------
    // UART timing: 115200 baud @ 1ns timescale
    // bit period = 1_000_000_000 / 115200 = 8680 ns
    // --------------------------------------------------------
    localparam BIT_PERIOD = 8680;

    // --------------------------------------------------------
    // Popcount functions
    // --------------------------------------------------------
    function integer popcount_100;
        input [99:0] vec;
        integer k;
        begin
            popcount_100 = 0;
            for (k = 0; k < 100; k = k + 1)
                popcount_100 = popcount_100 + vec[k];
        end
    endfunction

    function integer popcount_50;
        input [49:0] vec;
        integer k;
        begin
            popcount_50 = 0;
            for (k = 0; k < 50; k = k + 1)
                popcount_50 = popcount_50 + vec[k];
        end
    endfunction

    // --------------------------------------------------------
    // Task: send one byte over simulated UART (8N1)
    // --------------------------------------------------------
    task uart_send_byte;
        input [7:0] data;
        integer b;
        begin
            // Start bit
            uart_rxd = 1'b0;
            #(BIT_PERIOD);
            // 8 data bits LSB first
            for (b = 0; b < 8; b = b + 1) begin
                uart_rxd = data[b];
                #(BIT_PERIOD);
            end
            // Stop bit
            uart_rxd = 1'b1;
            #(BIT_PERIOD);
        end
    endtask

    // --------------------------------------------------------
    // Task: send a string character by character
    // --------------------------------------------------------
    task uart_send_string_RECV_prefix;
        begin
            uart_send_byte(8'h52); // R
            uart_send_byte(8'h45); // E
            uart_send_byte(8'h43); // C
            uart_send_byte(8'h56); // V
            uart_send_byte(8'h3A); // :
        end
    endtask

    // --------------------------------------------------------
    // Storage
    // --------------------------------------------------------
    reg [99:0] test_vector;
    reg [99:0] decoded_latch;
    integer    timeout;
    integer    i;
    integer    iter_log [0:50];   // sized for MAX_ITER=50
    integer    syn_log  [0:50];   // sized for MAX_ITER=50
    integer    fd;

    reg decoded_latched;

    // --------------------------------------------------------
    // 100 MHz clock
    // --------------------------------------------------------
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // --------------------------------------------------------
    // Latch decoded codeword at S_SUCCESS / S_FAIL
    // --------------------------------------------------------
    initial decoded_latched = 1'b0;
    always @(posedge clk) begin
        if ((fsm_state == S_SUCCESS || fsm_state == S_FAIL) && !decoded_latched) begin
            decoded_latch   <= decoded_cw;
            decoded_latched <= 1'b1;
        end
    end

    // --------------------------------------------------------
    // Per-iteration snapshot at S_CLEAR
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (fsm_state == 4'd2) begin // S_CLEAR
            syn_log[iter_count]  <= popcount_50(syndrome);
            iter_log[iter_count] <= popcount_100(DUT.u_decoder.codeword);
        end
    end

    // --------------------------------------------------------
    // Main stimulus
    // --------------------------------------------------------
    initial begin
        // Initialise
        uart_rxd     = 1'b1;   // UART idle HIGH
        decoded_latch = 100'd0;
        for (i = 0; i < 51; i = i + 1) begin
            iter_log[i] = 0;
            syn_log[i]  = 0;
        end

        // Test vector: single error at bit 5.
        // Gallager Algorithm A (col-weight 3, threshold 2) guarantees
        // correction of exactly 1 error. The all-zeros word is a valid
        // codeword (H x 0^T = 0), so flipping one bit is a clean test.
        // Do NOT inject more than 1 error - the code cannot correct 2+.
        test_vector = 100'd0;
        test_vector[5] = 1'b1;   // single error at bit 5

        $display("============================================================");
        $display(" LDPC UART DECODER -- BEHAVIORAL SIMULATION");
        $display(" H: 50x100  |  Threshold: 2  |  Max iter: 50");
        $display(" Baud: 115200");
        $display("============================================================");

        // ---- Reset ----
        rst = 1'b1;
        repeat(20) @(posedge clk);
        rst = 1'b0;
        repeat(10) @(posedge clk);

        // ---- Print test vector being sent ----
        $display("");
        $display("  [TX] Sending: RECV:<100 bits>");
        $display("  Test vector active bits : %0d", popcount_100(test_vector));
        $write  ("  Bit positions           : ");
        for (i = 0; i < 100; i = i + 1)
            if (test_vector[i]) $write("%0d ", i);
        $display("");

        // ---- Send RECV: prefix ----
        uart_send_string_RECV_prefix;

        // ---- Send 100 bit characters (bit 0 first) ----
        for (i = 0; i < 100; i = i + 1) begin
            if (test_vector[i])
                uart_send_byte(8'h31); // '1'
            else
                uart_send_byte(8'h30); // '0'
        end

        // ---- Send newline to terminate ----
        uart_send_byte(8'h0A); // \n

        $display("  [TX] Transmission complete");

        // ---- Wait for cw_loader to reach S_DONE (state 6) ----
        // NOTE: load_done is a 1-cycle pulse fired during S_READ_BITS→S_DONE
        // transition, which happens ~87 µs before this polling loop starts
        // (during reception of the 100th bit, before the \n byte is sent).
        // Polling load_done directly would always miss it. Instead we poll
        // the loader FSM state, which stays in S_DONE until reset.
        timeout = 0;
        while (DUT.u_loader.state !== 4'd6 && timeout < 2000000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (DUT.u_loader.state !== 4'd6) begin
            $display("  [ERROR] cw_loader never reached S_DONE - check FSM");
            $finish;
        end
        $display("  [RX] Codeword received by loader -- starting decode");

        // ---- Wait for decoder to finish (up to 10 ms = 1,000,000 cycles) ----
        timeout = 0;
        while (!done_led && timeout < 500000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        // ---- Results ----
        $display("");
        $display("  ── RECEIVED  CODEWORD ──────────────────────────────────");
        $display("  Active bits  : %0d", popcount_100(recv_cw));
        $write  ("  Bit positions: ");
        for (i = 0; i < 100; i = i + 1)
            if (recv_cw[i]) $write("%0d ", i);
        $display("");

        $display("");
        $display("  ── DECODED   CODEWORD ──────────────────────────────────");
        $display("  Active bits  : %0d", popcount_100(decoded_latch));
        $write  ("  Bit positions: ");
        for (i = 0; i < 100; i = i + 1)
            if (decoded_latch[i]) $write("%0d ", i);
        $display("");

        $display("");
        $display("  ── VISUAL DIFF (* = corrected) ─────────────────────────");
        $display("  Idx  Received    Decoded     Delta");
        $display("  ---  ----------  ----------  ----------");
        for (i = 0; i < 10; i = i + 1) begin
            $write("  %3d  ", i * 10);
            begin : row_r
                integer c;
                for (c = 0; c < 10; c = c + 1)
                    $write("%b", recv_cw[i*10 + c]);
            end
            $write("  ");
            begin : row_d
                integer c;
                for (c = 0; c < 10; c = c + 1)
                    $write("%b", decoded_latch[i*10 + c]);
            end
            $write("  ");
            begin : row_x
                integer c;
                for (c = 0; c < 10; c = c + 1) begin
                    if (recv_cw[i*10+c] !== decoded_latch[i*10+c])
                        $write("*");
                    else
                        $write(".");
                end
            end
            $display("");
        end

        $display("");
        $write  ("  Corrected bit indices: ");
        for (i = 0; i < 100; i = i + 1)
            if (recv_cw[i] !== decoded_latch[i]) $write("%0d ", i);
        $display("");
        $display("  Total bits corrected : %0d", popcount_100(recv_cw ^ decoded_latch));

        $display("");
        $display("  ── ITERATION TRACE ─────────────────────────────────────");
        $display("  Iter  Unsat-CNs  Active-1s");
        $display("  ----  ---------  ---------");
        for (i = 0; i <= iter_count && i < 51; i = i + 1)
            $display("  %4d  %9d  %9d", i, syn_log[i], iter_log[i]);

        $display("");
        $display("  ── RESULT ──────────────────────────────────────────────");
        if (!done_led)
            $display("  [TIMEOUT] Decoder did not finish in %0d cycles", timeout);
        else if (decode_success) begin
            $display("  [PASS] Decode SUCCESS");
            $display("  Total cycles : %0d", timeout);
            $display("  Iterations   : %0d / 50", iter_count);
            $display("  Bits fixed   : %0d", popcount_100(recv_cw ^ decoded_latch));
        end else begin
            $display("  [FAIL] Max iterations reached");
            $display("  Residual unsat checks: %0d", popcount_50(syndrome));
            $display("  Best codeword output  (closest decode found)");
        end

        $display("");
        if (|syndrome)
            $display("  [WARNING] Residual syndrome non-zero");
        else
            $display("  [CHECK] Syndrome = 0 -- valid codeword confirmed");

        $display("============================================================");

        // ---- Write codeword_output.txt ----
        fd = $fopen("codeword_output.txt", "w");
        if (fd != 0) begin
            $fdisplay(fd, "============================================================");
            $fdisplay(fd, " LDPC UART DECODER -- CODEWORD REPORT");
            $fdisplay(fd, "============================================================");
            $fdisplay(fd, "");
            $fdisplay(fd, "RECEIVED (CORRUPTED) CODEWORD:");
            $fdisplay(fd, "  Binary : %b", recv_cw);
            $fdisplay(fd, "  Hex    : %025x", recv_cw);
            $fwrite  (fd, "  Set bits: ");
            for (i = 0; i < 100; i = i + 1)
                if (recv_cw[i]) $fwrite(fd, "%0d ", i);
            $fdisplay(fd, "");
            $fdisplay(fd, "");
            $fdisplay(fd, "DECODED CODEWORD:");
            $fdisplay(fd, "  Binary : %b", decoded_latch);
            $fdisplay(fd, "  Hex    : %025x", decoded_latch);
            $fwrite  (fd, "  Set bits: ");
            for (i = 0; i < 100; i = i + 1)
                if (decoded_latch[i]) $fwrite(fd, "%0d ", i);
            $fdisplay(fd, "");
            $fdisplay(fd, "");
            $fdisplay(fd, "XOR DIFF:");
            $fdisplay(fd, "  Binary : %b", recv_cw ^ decoded_latch);
            $fwrite  (fd, "  Corrected indices: ");
            for (i = 0; i < 100; i = i + 1)
                if (recv_cw[i] !== decoded_latch[i]) $fwrite(fd, "%0d ", i);
            $fdisplay(fd, "");
            $fdisplay(fd, "  Total corrected: %0d", popcount_100(recv_cw ^ decoded_latch));
            $fdisplay(fd, "");
            $fdisplay(fd, "ITERATION TRACE:");
            $fdisplay(fd, "  Iter  Unsat-CNs  Active-1s");
            for (i = 0; i <= iter_count && i < 51; i = i + 1)
                $fdisplay(fd, "  %4d  %9d  %9d", i, syn_log[i], iter_log[i]);
            $fdisplay(fd, "");
            if (decode_success)
                $fdisplay(fd, "RESULT: PASS -- %0d bits corrected in %0d iterations",
                          popcount_100(recv_cw ^ decoded_latch), iter_count);
            else
                $fdisplay(fd, "RESULT: FAIL -- max iterations reached");
            $fdisplay(fd, "============================================================");
            $fclose(fd);
            $display("  [FILE] codeword_output.txt written to xsim directory");
        end

        // ---- Wait for result_sender to finish UART TX ----
        // ~250 chars × 86.8 µs/char ≈ 22 ms → 2,200,000 cycles timeout
        timeout = 0;
        while (DUT.u_sender.send_busy && timeout < 2200000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (DUT.u_sender.send_busy)
            $display("  [WARNING] result_sender TX timed out after %0d cycles", timeout);
        else
            $display("  [TX] Result transmission complete (%0d cycles)", timeout);

        repeat(20) @(posedge clk);
        $finish;
    end

endmodule
