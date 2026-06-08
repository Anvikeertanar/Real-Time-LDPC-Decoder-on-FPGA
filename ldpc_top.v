// ============================================================
// ldpc_top.v  (CONVERGENCE UPDATE)  -  Top-level wrapper for Basys 3
//
// UART-enabled version:
//   1. uart_rx    receives bytes at 115200 baud
//   2. cw_loader  parses "RECV:<100 bits>\n" into recv_cw
//   3. ldpc_decoder_core decodes recv_cw using Gallager Alg A
//   4. result_sender transmits result string over uart_tx
//
// Basys 3 pins:
//   clk        W5   100 MHz
//   rst        U18  BTNC  (synchronous reset)
//   uart_rxd   B18  USB-UART RX
//   uart_txd   A18  USB-UART TX
//   done_led   U16  LD0
//   fail_led   E19  LD1
//   decode_success U19 LD2
//
// Changes in this version:
//   - Wire syndrome_weight [5:0] from ldpc_decoder_core to
//     result_sender so "SYNDROME : N unsatisfied checks" is
//     included in the UART output on every decode attempt.
//   - done_rise remains a registered synchronous pulse (previous fix).
// ============================================================
module ldpc_top (
    input  wire clk,
    input  wire rst,
    input  wire uart_rxd,
    output wire uart_txd,
    output wire done_led,
    output wire fail_led,
    output wire decode_success
);

    // --------------------------------------------------------
    // 2-FF synchroniser for rst
    // --------------------------------------------------------
    reg rst_ff1, rst_ff2;
    always @(posedge clk) begin
        rst_ff1 <= rst;
        rst_ff2 <= rst_ff1;
    end
    wire rst_sync = rst_ff2;

    // --------------------------------------------------------
    // UART RX
    // --------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx u_rx (
        .clk      (clk),
        .rst      (rst_sync),
        .uart_rxd (uart_rxd),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

    // --------------------------------------------------------
    // Codeword loader
    // --------------------------------------------------------
    wire [99:0] recv_cw;
    wire        load_done;

    cw_loader u_loader (
        .clk      (clk),
        .rst      (rst_sync),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .recv_cw  (recv_cw),
        .load_done(load_done),
        .bit_count()
    );

    // --------------------------------------------------------
    // LDPC Decoder Core
    // --------------------------------------------------------
    wire        done_int;
    wire        success_int;
    wire        fail_int;
    wire [99:0] decoded_cw;
    wire [5:0]  syndrome_weight;   // NEW

    ldpc_decoder_core u_decoder (
        .clk             (clk),
        .rst             (rst_sync),
        .recv_cw_in      (recv_cw),
        .load            (load_done),
        .done            (done_int),
        .success         (success_int),
        .fail            (fail_int),
        .decoded_cw      (decoded_cw),
        .syndrome_weight (syndrome_weight)   // NEW
    );

    // --------------------------------------------------------
    // UART TX
    // --------------------------------------------------------
    wire [7:0] tx_data;
    wire       tx_start;
    wire       tx_busy;

    uart_tx u_tx (
        .clk      (clk),
        .rst      (rst_sync),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .tx_busy  (tx_busy),
        .uart_txd (uart_txd)
    );

    // --------------------------------------------------------
    // Registered rising-edge detector for done_int
    // --------------------------------------------------------
    reg done_prev;
    reg done_rise;

    always @(posedge clk) begin
        if (rst_sync) begin
            done_prev <= 1'b0;
            done_rise <= 1'b0;
        end else begin
            done_prev <= done_int;
            done_rise <= done_int & ~done_prev;
        end
    end

    // --------------------------------------------------------
    // Result sender
    // --------------------------------------------------------
    result_sender u_sender (
        .clk             (clk),
        .rst             (rst_sync),
        .send_start      (done_rise),
        .send_busy       (),
        .recv_cw         (recv_cw),
        .decoded_cw      (decoded_cw),
        .decode_success  (success_int),
        .syndrome_weight (syndrome_weight),   // NEW
        .tx_data         (tx_data),
        .tx_start        (tx_start),
        .tx_busy         (tx_busy)
    );

    // --------------------------------------------------------
    // LED outputs
    // --------------------------------------------------------
    assign done_led      = done_int;
    assign fail_led      = fail_int;
    assign decode_success = success_int;

endmodule
