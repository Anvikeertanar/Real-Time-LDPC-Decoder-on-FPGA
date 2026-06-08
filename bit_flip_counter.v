// ============================================================
// bit_flip_counter.v  (FIXED)
// Filename: bit_flip_counter.v
// Module name: bit_flip_counter  (matches u_cnt instantiation)
//
// Accumulates unsatisfied check counts per variable node AND
// applies the bit-flip decision - all in one module.
//
// SYNTHESIS RULES:
//   - No integer loop variables
//   - No initial blocks
//   - No dynamic indexing into arrays inside always blocks
//   - Unsat counters stored as flat 600-bit register (100 x 6-bit)
//   - All 100 VN paths written as explicit bit-slice assignments
//
// FIX 1 (Bug): clear and accum_en are now mutually exclusive via
//   if-else if.  Previously both were separate if-blocks, so if
//   both were asserted in the same cycle the accum increments
//   would win over the clear (last NBA wins), leaving unsat in
//   a partially-cleared corrupt state.
//
// FIX 2 (Minor): THRESHOLD widened to [5:0] to match the 6-bit
//   unsat counter slices, eliminating implicit zero-extension
//   and width-mismatch warnings.
// ============================================================
module bit_flip_counter (
    input  wire        clk,
    input  wire        rst,
    // Control
    input  wire        clear,       // pulse: reset all counters (start of iteration)
    input  wire        accum_en,    // pulse: accumulate current row
    input  wire        flip_en,     // pulse: apply flip decisions
    // Data in
    input  wire        syn_bit,     // syndrome bit for current CN
    input  wire [99:0] h_row,       // current H matrix row
    input  wire [99:0] codeword_in, // current codeword
    // Data out
    output reg  [99:0] codeword_out,
    output reg         flip_done
);

    // FIX 2: THRESHOLD width matches the 6-bit counter slices
    localparam [5:0] THRESHOLD = 6'd2;

    // ASSIGN-1 fix: explicit 6-bit increment function.
    // Declaring the return type as [5:0] tells Vivado the truncation
    // is intentional - the counter wraps within 6 bits by design
    // (max value is 50 since there are only 50 check nodes, well
    // within the 6-bit range of 0-63, so no real overflow occurs).
    function [5:0] inc6;
        input [5:0] v;
        inc6 = v + 6'd1;
    endfunction

    // 100 x 6-bit unsatisfied counters packed flat
    reg [599:0] unsat;

    always @(posedge clk) begin
        if (rst) begin
            unsat        <= 600'd0;
            codeword_out <= 100'd0;
            flip_done    <= 1'b0;
        end else begin
            flip_done <= 1'b0;

            // FIX 1: if-else if enforces mutual exclusion between
            // clear and accum_en.  clear has higher priority.
            if (clear) begin
                // ------------------------------------------------
                // Clear: reset all unsatisfied-CN counters
                // ------------------------------------------------
                unsat <= 600'd0;
            end else if (accum_en && syn_bit) begin
                // ------------------------------------------------
                // Accumulate: if this CN unsatisfied, increment
                // counters for every VN connected (H_row[j] == 1)
                // ------------------------------------------------
                if (h_row[0])  unsat[5:0]     <= inc6(unsat[5:0]);
                if (h_row[1])  unsat[11:6]    <= inc6(unsat[11:6]);
                if (h_row[2])  unsat[17:12]   <= inc6(unsat[17:12]);
                if (h_row[3])  unsat[23:18]   <= inc6(unsat[23:18]);
                if (h_row[4])  unsat[29:24]   <= inc6(unsat[29:24]);
                if (h_row[5])  unsat[35:30]   <= inc6(unsat[35:30]);
                if (h_row[6])  unsat[41:36]   <= inc6(unsat[41:36]);
                if (h_row[7])  unsat[47:42]   <= inc6(unsat[47:42]);
                if (h_row[8])  unsat[53:48]   <= inc6(unsat[53:48]);
                if (h_row[9])  unsat[59:54]   <= inc6(unsat[59:54]);
                if (h_row[10]) unsat[65:60]   <= inc6(unsat[65:60]);
                if (h_row[11]) unsat[71:66]   <= inc6(unsat[71:66]);
                if (h_row[12]) unsat[77:72]   <= inc6(unsat[77:72]);
                if (h_row[13]) unsat[83:78]   <= inc6(unsat[83:78]);
                if (h_row[14]) unsat[89:84]   <= inc6(unsat[89:84]);
                if (h_row[15]) unsat[95:90]   <= inc6(unsat[95:90]);
                if (h_row[16]) unsat[101:96]  <= inc6(unsat[101:96]);
                if (h_row[17]) unsat[107:102] <= inc6(unsat[107:102]);
                if (h_row[18]) unsat[113:108] <= inc6(unsat[113:108]);
                if (h_row[19]) unsat[119:114] <= inc6(unsat[119:114]);
                if (h_row[20]) unsat[125:120] <= inc6(unsat[125:120]);
                if (h_row[21]) unsat[131:126] <= inc6(unsat[131:126]);
                if (h_row[22]) unsat[137:132] <= inc6(unsat[137:132]);
                if (h_row[23]) unsat[143:138] <= inc6(unsat[143:138]);
                if (h_row[24]) unsat[149:144] <= inc6(unsat[149:144]);
                if (h_row[25]) unsat[155:150] <= inc6(unsat[155:150]);
                if (h_row[26]) unsat[161:156] <= inc6(unsat[161:156]);
                if (h_row[27]) unsat[167:162] <= inc6(unsat[167:162]);
                if (h_row[28]) unsat[173:168] <= inc6(unsat[173:168]);
                if (h_row[29]) unsat[179:174] <= inc6(unsat[179:174]);
                if (h_row[30]) unsat[185:180] <= inc6(unsat[185:180]);
                if (h_row[31]) unsat[191:186] <= inc6(unsat[191:186]);
                if (h_row[32]) unsat[197:192] <= inc6(unsat[197:192]);
                if (h_row[33]) unsat[203:198] <= inc6(unsat[203:198]);
                if (h_row[34]) unsat[209:204] <= inc6(unsat[209:204]);
                if (h_row[35]) unsat[215:210] <= inc6(unsat[215:210]);
                if (h_row[36]) unsat[221:216] <= inc6(unsat[221:216]);
                if (h_row[37]) unsat[227:222] <= inc6(unsat[227:222]);
                if (h_row[38]) unsat[233:228] <= inc6(unsat[233:228]);
                if (h_row[39]) unsat[239:234] <= inc6(unsat[239:234]);
                if (h_row[40]) unsat[245:240] <= inc6(unsat[245:240]);
                if (h_row[41]) unsat[251:246] <= inc6(unsat[251:246]);
                if (h_row[42]) unsat[257:252] <= inc6(unsat[257:252]);
                if (h_row[43]) unsat[263:258] <= inc6(unsat[263:258]);
                if (h_row[44]) unsat[269:264] <= inc6(unsat[269:264]);
                if (h_row[45]) unsat[275:270] <= inc6(unsat[275:270]);
                if (h_row[46]) unsat[281:276] <= inc6(unsat[281:276]);
                if (h_row[47]) unsat[287:282] <= inc6(unsat[287:282]);
                if (h_row[48]) unsat[293:288] <= inc6(unsat[293:288]);
                if (h_row[49]) unsat[299:294] <= inc6(unsat[299:294]);
                if (h_row[50]) unsat[305:300] <= inc6(unsat[305:300]);
                if (h_row[51]) unsat[311:306] <= inc6(unsat[311:306]);
                if (h_row[52]) unsat[317:312] <= inc6(unsat[317:312]);
                if (h_row[53]) unsat[323:318] <= inc6(unsat[323:318]);
                if (h_row[54]) unsat[329:324] <= inc6(unsat[329:324]);
                if (h_row[55]) unsat[335:330] <= inc6(unsat[335:330]);
                if (h_row[56]) unsat[341:336] <= inc6(unsat[341:336]);
                if (h_row[57]) unsat[347:342] <= inc6(unsat[347:342]);
                if (h_row[58]) unsat[353:348] <= inc6(unsat[353:348]);
                if (h_row[59]) unsat[359:354] <= inc6(unsat[359:354]);
                if (h_row[60]) unsat[365:360] <= inc6(unsat[365:360]);
                if (h_row[61]) unsat[371:366] <= inc6(unsat[371:366]);
                if (h_row[62]) unsat[377:372] <= inc6(unsat[377:372]);
                if (h_row[63]) unsat[383:378] <= inc6(unsat[383:378]);
                if (h_row[64]) unsat[389:384] <= inc6(unsat[389:384]);
                if (h_row[65]) unsat[395:390] <= inc6(unsat[395:390]);
                if (h_row[66]) unsat[401:396] <= inc6(unsat[401:396]);
                if (h_row[67]) unsat[407:402] <= inc6(unsat[407:402]);
                if (h_row[68]) unsat[413:408] <= inc6(unsat[413:408]);
                if (h_row[69]) unsat[419:414] <= inc6(unsat[419:414]);
                if (h_row[70]) unsat[425:420] <= inc6(unsat[425:420]);
                if (h_row[71]) unsat[431:426] <= inc6(unsat[431:426]);
                if (h_row[72]) unsat[437:432] <= inc6(unsat[437:432]);
                if (h_row[73]) unsat[443:438] <= inc6(unsat[443:438]);
                if (h_row[74]) unsat[449:444] <= inc6(unsat[449:444]);
                if (h_row[75]) unsat[455:450] <= inc6(unsat[455:450]);
                if (h_row[76]) unsat[461:456] <= inc6(unsat[461:456]);
                if (h_row[77]) unsat[467:462] <= inc6(unsat[467:462]);
                if (h_row[78]) unsat[473:468] <= inc6(unsat[473:468]);
                if (h_row[79]) unsat[479:474] <= inc6(unsat[479:474]);
                if (h_row[80]) unsat[485:480] <= inc6(unsat[485:480]);
                if (h_row[81]) unsat[491:486] <= inc6(unsat[491:486]);
                if (h_row[82]) unsat[497:492] <= inc6(unsat[497:492]);
                if (h_row[83]) unsat[503:498] <= inc6(unsat[503:498]);
                if (h_row[84]) unsat[509:504] <= inc6(unsat[509:504]);
                if (h_row[85]) unsat[515:510] <= inc6(unsat[515:510]);
                if (h_row[86]) unsat[521:516] <= inc6(unsat[521:516]);
                if (h_row[87]) unsat[527:522] <= inc6(unsat[527:522]);
                if (h_row[88]) unsat[533:528] <= inc6(unsat[533:528]);
                if (h_row[89]) unsat[539:534] <= inc6(unsat[539:534]);
                if (h_row[90]) unsat[545:540] <= inc6(unsat[545:540]);
                if (h_row[91]) unsat[551:546] <= inc6(unsat[551:546]);
                if (h_row[92]) unsat[557:552] <= inc6(unsat[557:552]);
                if (h_row[93]) unsat[563:558] <= inc6(unsat[563:558]);
                if (h_row[94]) unsat[569:564] <= inc6(unsat[569:564]);
                if (h_row[95]) unsat[575:570] <= inc6(unsat[575:570]);
                if (h_row[96]) unsat[581:576] <= inc6(unsat[581:576]);
                if (h_row[97]) unsat[587:582] <= inc6(unsat[587:582]);
                if (h_row[98]) unsat[593:588] <= inc6(unsat[593:588]);
                if (h_row[99]) unsat[599:594] <= inc6(unsat[599:594]);
            end

            // ------------------------------------------------
            // Flip: toggle bit j if unsat[j] >= THRESHOLD
            // (independent of clear/accum - flip_en is only
            //  asserted from S_FLIP which is reached after all
            //  accumulation is complete)
            // ------------------------------------------------
            if (flip_en) begin
                codeword_out[0]  <= (unsat[5:0]     >= THRESHOLD) ? ~codeword_in[0]  : codeword_in[0];
                codeword_out[1]  <= (unsat[11:6]    >= THRESHOLD) ? ~codeword_in[1]  : codeword_in[1];
                codeword_out[2]  <= (unsat[17:12]   >= THRESHOLD) ? ~codeword_in[2]  : codeword_in[2];
                codeword_out[3]  <= (unsat[23:18]   >= THRESHOLD) ? ~codeword_in[3]  : codeword_in[3];
                codeword_out[4]  <= (unsat[29:24]   >= THRESHOLD) ? ~codeword_in[4]  : codeword_in[4];
                codeword_out[5]  <= (unsat[35:30]   >= THRESHOLD) ? ~codeword_in[5]  : codeword_in[5];
                codeword_out[6]  <= (unsat[41:36]   >= THRESHOLD) ? ~codeword_in[6]  : codeword_in[6];
                codeword_out[7]  <= (unsat[47:42]   >= THRESHOLD) ? ~codeword_in[7]  : codeword_in[7];
                codeword_out[8]  <= (unsat[53:48]   >= THRESHOLD) ? ~codeword_in[8]  : codeword_in[8];
                codeword_out[9]  <= (unsat[59:54]   >= THRESHOLD) ? ~codeword_in[9]  : codeword_in[9];
                codeword_out[10] <= (unsat[65:60]   >= THRESHOLD) ? ~codeword_in[10] : codeword_in[10];
                codeword_out[11] <= (unsat[71:66]   >= THRESHOLD) ? ~codeword_in[11] : codeword_in[11];
                codeword_out[12] <= (unsat[77:72]   >= THRESHOLD) ? ~codeword_in[12] : codeword_in[12];
                codeword_out[13] <= (unsat[83:78]   >= THRESHOLD) ? ~codeword_in[13] : codeword_in[13];
                codeword_out[14] <= (unsat[89:84]   >= THRESHOLD) ? ~codeword_in[14] : codeword_in[14];
                codeword_out[15] <= (unsat[95:90]   >= THRESHOLD) ? ~codeword_in[15] : codeword_in[15];
                codeword_out[16] <= (unsat[101:96]  >= THRESHOLD) ? ~codeword_in[16] : codeword_in[16];
                codeword_out[17] <= (unsat[107:102] >= THRESHOLD) ? ~codeword_in[17] : codeword_in[17];
                codeword_out[18] <= (unsat[113:108] >= THRESHOLD) ? ~codeword_in[18] : codeword_in[18];
                codeword_out[19] <= (unsat[119:114] >= THRESHOLD) ? ~codeword_in[19] : codeword_in[19];
                codeword_out[20] <= (unsat[125:120] >= THRESHOLD) ? ~codeword_in[20] : codeword_in[20];
                codeword_out[21] <= (unsat[131:126] >= THRESHOLD) ? ~codeword_in[21] : codeword_in[21];
                codeword_out[22] <= (unsat[137:132] >= THRESHOLD) ? ~codeword_in[22] : codeword_in[22];
                codeword_out[23] <= (unsat[143:138] >= THRESHOLD) ? ~codeword_in[23] : codeword_in[23];
                codeword_out[24] <= (unsat[149:144] >= THRESHOLD) ? ~codeword_in[24] : codeword_in[24];
                codeword_out[25] <= (unsat[155:150] >= THRESHOLD) ? ~codeword_in[25] : codeword_in[25];
                codeword_out[26] <= (unsat[161:156] >= THRESHOLD) ? ~codeword_in[26] : codeword_in[26];
                codeword_out[27] <= (unsat[167:162] >= THRESHOLD) ? ~codeword_in[27] : codeword_in[27];
                codeword_out[28] <= (unsat[173:168] >= THRESHOLD) ? ~codeword_in[28] : codeword_in[28];
                codeword_out[29] <= (unsat[179:174] >= THRESHOLD) ? ~codeword_in[29] : codeword_in[29];
                codeword_out[30] <= (unsat[185:180] >= THRESHOLD) ? ~codeword_in[30] : codeword_in[30];
                codeword_out[31] <= (unsat[191:186] >= THRESHOLD) ? ~codeword_in[31] : codeword_in[31];
                codeword_out[32] <= (unsat[197:192] >= THRESHOLD) ? ~codeword_in[32] : codeword_in[32];
                codeword_out[33] <= (unsat[203:198] >= THRESHOLD) ? ~codeword_in[33] : codeword_in[33];
                codeword_out[34] <= (unsat[209:204] >= THRESHOLD) ? ~codeword_in[34] : codeword_in[34];
                codeword_out[35] <= (unsat[215:210] >= THRESHOLD) ? ~codeword_in[35] : codeword_in[35];
                codeword_out[36] <= (unsat[221:216] >= THRESHOLD) ? ~codeword_in[36] : codeword_in[36];
                codeword_out[37] <= (unsat[227:222] >= THRESHOLD) ? ~codeword_in[37] : codeword_in[37];
                codeword_out[38] <= (unsat[233:228] >= THRESHOLD) ? ~codeword_in[38] : codeword_in[38];
                codeword_out[39] <= (unsat[239:234] >= THRESHOLD) ? ~codeword_in[39] : codeword_in[39];
                codeword_out[40] <= (unsat[245:240] >= THRESHOLD) ? ~codeword_in[40] : codeword_in[40];
                codeword_out[41] <= (unsat[251:246] >= THRESHOLD) ? ~codeword_in[41] : codeword_in[41];
                codeword_out[42] <= (unsat[257:252] >= THRESHOLD) ? ~codeword_in[42] : codeword_in[42];
                codeword_out[43] <= (unsat[263:258] >= THRESHOLD) ? ~codeword_in[43] : codeword_in[43];
                codeword_out[44] <= (unsat[269:264] >= THRESHOLD) ? ~codeword_in[44] : codeword_in[44];
                codeword_out[45] <= (unsat[275:270] >= THRESHOLD) ? ~codeword_in[45] : codeword_in[45];
                codeword_out[46] <= (unsat[281:276] >= THRESHOLD) ? ~codeword_in[46] : codeword_in[46];
                codeword_out[47] <= (unsat[287:282] >= THRESHOLD) ? ~codeword_in[47] : codeword_in[47];
                codeword_out[48] <= (unsat[293:288] >= THRESHOLD) ? ~codeword_in[48] : codeword_in[48];
                codeword_out[49] <= (unsat[299:294] >= THRESHOLD) ? ~codeword_in[49] : codeword_in[49];
                codeword_out[50] <= (unsat[305:300] >= THRESHOLD) ? ~codeword_in[50] : codeword_in[50];
                codeword_out[51] <= (unsat[311:306] >= THRESHOLD) ? ~codeword_in[51] : codeword_in[51];
                codeword_out[52] <= (unsat[317:312] >= THRESHOLD) ? ~codeword_in[52] : codeword_in[52];
                codeword_out[53] <= (unsat[323:318] >= THRESHOLD) ? ~codeword_in[53] : codeword_in[53];
                codeword_out[54] <= (unsat[329:324] >= THRESHOLD) ? ~codeword_in[54] : codeword_in[54];
                codeword_out[55] <= (unsat[335:330] >= THRESHOLD) ? ~codeword_in[55] : codeword_in[55];
                codeword_out[56] <= (unsat[341:336] >= THRESHOLD) ? ~codeword_in[56] : codeword_in[56];
                codeword_out[57] <= (unsat[347:342] >= THRESHOLD) ? ~codeword_in[57] : codeword_in[57];
                codeword_out[58] <= (unsat[353:348] >= THRESHOLD) ? ~codeword_in[58] : codeword_in[58];
                codeword_out[59] <= (unsat[359:354] >= THRESHOLD) ? ~codeword_in[59] : codeword_in[59];
                codeword_out[60] <= (unsat[365:360] >= THRESHOLD) ? ~codeword_in[60] : codeword_in[60];
                codeword_out[61] <= (unsat[371:366] >= THRESHOLD) ? ~codeword_in[61] : codeword_in[61];
                codeword_out[62] <= (unsat[377:372] >= THRESHOLD) ? ~codeword_in[62] : codeword_in[62];
                codeword_out[63] <= (unsat[383:378] >= THRESHOLD) ? ~codeword_in[63] : codeword_in[63];
                codeword_out[64] <= (unsat[389:384] >= THRESHOLD) ? ~codeword_in[64] : codeword_in[64];
                codeword_out[65] <= (unsat[395:390] >= THRESHOLD) ? ~codeword_in[65] : codeword_in[65];
                codeword_out[66] <= (unsat[401:396] >= THRESHOLD) ? ~codeword_in[66] : codeword_in[66];
                codeword_out[67] <= (unsat[407:402] >= THRESHOLD) ? ~codeword_in[67] : codeword_in[67];
                codeword_out[68] <= (unsat[413:408] >= THRESHOLD) ? ~codeword_in[68] : codeword_in[68];
                codeword_out[69] <= (unsat[419:414] >= THRESHOLD) ? ~codeword_in[69] : codeword_in[69];
                codeword_out[70] <= (unsat[425:420] >= THRESHOLD) ? ~codeword_in[70] : codeword_in[70];
                codeword_out[71] <= (unsat[431:426] >= THRESHOLD) ? ~codeword_in[71] : codeword_in[71];
                codeword_out[72] <= (unsat[437:432] >= THRESHOLD) ? ~codeword_in[72] : codeword_in[72];
                codeword_out[73] <= (unsat[443:438] >= THRESHOLD) ? ~codeword_in[73] : codeword_in[73];
                codeword_out[74] <= (unsat[449:444] >= THRESHOLD) ? ~codeword_in[74] : codeword_in[74];
                codeword_out[75] <= (unsat[455:450] >= THRESHOLD) ? ~codeword_in[75] : codeword_in[75];
                codeword_out[76] <= (unsat[461:456] >= THRESHOLD) ? ~codeword_in[76] : codeword_in[76];
                codeword_out[77] <= (unsat[467:462] >= THRESHOLD) ? ~codeword_in[77] : codeword_in[77];
                codeword_out[78] <= (unsat[473:468] >= THRESHOLD) ? ~codeword_in[78] : codeword_in[78];
                codeword_out[79] <= (unsat[479:474] >= THRESHOLD) ? ~codeword_in[79] : codeword_in[79];
                codeword_out[80] <= (unsat[485:480] >= THRESHOLD) ? ~codeword_in[80] : codeword_in[80];
                codeword_out[81] <= (unsat[491:486] >= THRESHOLD) ? ~codeword_in[81] : codeword_in[81];
                codeword_out[82] <= (unsat[497:492] >= THRESHOLD) ? ~codeword_in[82] : codeword_in[82];
                codeword_out[83] <= (unsat[503:498] >= THRESHOLD) ? ~codeword_in[83] : codeword_in[83];
                codeword_out[84] <= (unsat[509:504] >= THRESHOLD) ? ~codeword_in[84] : codeword_in[84];
                codeword_out[85] <= (unsat[515:510] >= THRESHOLD) ? ~codeword_in[85] : codeword_in[85];
                codeword_out[86] <= (unsat[521:516] >= THRESHOLD) ? ~codeword_in[86] : codeword_in[86];
                codeword_out[87] <= (unsat[527:522] >= THRESHOLD) ? ~codeword_in[87] : codeword_in[87];
                codeword_out[88] <= (unsat[533:528] >= THRESHOLD) ? ~codeword_in[88] : codeword_in[88];
                codeword_out[89] <= (unsat[539:534] >= THRESHOLD) ? ~codeword_in[89] : codeword_in[89];
                codeword_out[90] <= (unsat[545:540] >= THRESHOLD) ? ~codeword_in[90] : codeword_in[90];
                codeword_out[91] <= (unsat[551:546] >= THRESHOLD) ? ~codeword_in[91] : codeword_in[91];
                codeword_out[92] <= (unsat[557:552] >= THRESHOLD) ? ~codeword_in[92] : codeword_in[92];
                codeword_out[93] <= (unsat[563:558] >= THRESHOLD) ? ~codeword_in[93] : codeword_in[93];
                codeword_out[94] <= (unsat[569:564] >= THRESHOLD) ? ~codeword_in[94] : codeword_in[94];
                codeword_out[95] <= (unsat[575:570] >= THRESHOLD) ? ~codeword_in[95] : codeword_in[95];
                codeword_out[96] <= (unsat[581:576] >= THRESHOLD) ? ~codeword_in[96] : codeword_in[96];
                codeword_out[97] <= (unsat[587:582] >= THRESHOLD) ? ~codeword_in[97] : codeword_in[97];
                codeword_out[98] <= (unsat[593:588] >= THRESHOLD) ? ~codeword_in[98] : codeword_in[98];
                codeword_out[99] <= (unsat[599:594] >= THRESHOLD) ? ~codeword_in[99] : codeword_in[99];
                flip_done <= 1'b1;
            end
        end
    end

endmodule
