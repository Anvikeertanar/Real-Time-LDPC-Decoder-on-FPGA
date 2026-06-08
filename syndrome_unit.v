// ============================================================
// syndrome_unit.v  (FIXED)
// Filename: syndrome_unit.v
// Module name: syndrome_unit  (matches u_syn instantiation)
//
// Computes one syndrome bit = XOR reduction of (H_row & codeword)
// Fully combinatorial — no clock, no latches.
// Vivado infers as a 100-input XOR LUT tree.
//
// FIX (Minor 8): Removed the incorrect comment
//   "Design source only — never add to simulation sources."
//   This module is a submodule of ldpc_decoder_core and MUST be
//   included in simulation alongside all other design sources.
//   The comment was misleading and has been removed.
// ============================================================
module syndrome_unit (
    input  wire [99:0] h_row,
    input  wire [99:0] codeword,
    output wire        syn_bit
);

    wire [99:0] masked = h_row & codeword;

    // Explicit XOR tree — no reduction operators that confuse
    // older Vivado parsers, and no integer loops.
    assign syn_bit =
        masked[0]  ^ masked[1]  ^ masked[2]  ^ masked[3]  ^ masked[4]  ^
        masked[5]  ^ masked[6]  ^ masked[7]  ^ masked[8]  ^ masked[9]  ^
        masked[10] ^ masked[11] ^ masked[12] ^ masked[13] ^ masked[14] ^
        masked[15] ^ masked[16] ^ masked[17] ^ masked[18] ^ masked[19] ^
        masked[20] ^ masked[21] ^ masked[22] ^ masked[23] ^ masked[24] ^
        masked[25] ^ masked[26] ^ masked[27] ^ masked[28] ^ masked[29] ^
        masked[30] ^ masked[31] ^ masked[32] ^ masked[33] ^ masked[34] ^
        masked[35] ^ masked[36] ^ masked[37] ^ masked[38] ^ masked[39] ^
        masked[40] ^ masked[41] ^ masked[42] ^ masked[43] ^ masked[44] ^
        masked[45] ^ masked[46] ^ masked[47] ^ masked[48] ^ masked[49] ^
        masked[50] ^ masked[51] ^ masked[52] ^ masked[53] ^ masked[54] ^
        masked[55] ^ masked[56] ^ masked[57] ^ masked[58] ^ masked[59] ^
        masked[60] ^ masked[61] ^ masked[62] ^ masked[63] ^ masked[64] ^
        masked[65] ^ masked[66] ^ masked[67] ^ masked[68] ^ masked[69] ^
        masked[70] ^ masked[71] ^ masked[72] ^ masked[73] ^ masked[74] ^
        masked[75] ^ masked[76] ^ masked[77] ^ masked[78] ^ masked[79] ^
        masked[80] ^ masked[81] ^ masked[82] ^ masked[83] ^ masked[84] ^
        masked[85] ^ masked[86] ^ masked[87] ^ masked[88] ^ masked[89] ^
        masked[90] ^ masked[91] ^ masked[92] ^ masked[93] ^ masked[94] ^
        masked[95] ^ masked[96] ^ masked[97] ^ masked[98] ^ masked[99];

endmodule
