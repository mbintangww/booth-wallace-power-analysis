// PARTIAL PRODUCTS ADDER
`timescale 1ns / 1ps

module Partial_Products_Adder (
    input  [135:0] PP_flat,
    input  [7:0]   sign,
    output [31:0]  out
);

    // Unpack partial products from flat bus
    wire [16:0] pp [0:7];
    genvar k;
    generate
        for (k = 0; k < 8; k = k + 1) begin : unpack_pp
            assign pp[k] = PP_flat[(k+1)*17-1 : k*17];
        end
    endgenerate

    wire [31:0] p0, p1, p2, p3, p4, p5, p6, p7, svec;

    assign p0   = {12'b0, ~pp[0][16], pp[0][16], pp[0][16], pp[0]};
    assign p1   = {11'b0,  1'b1, ~pp[1][16], pp[1],  2'b0};
    assign p2   = { 9'b0,  1'b1, ~pp[2][16], pp[2],  4'b0};
    assign p3   = { 7'b0,  1'b1, ~pp[3][16], pp[3],  6'b0};
    assign p4   = { 5'b0,  1'b1, ~pp[4][16], pp[4],  8'b0};
    assign p5   = { 3'b0,  1'b1, ~pp[5][16], pp[5], 10'b0};
    assign p6   = { 1'b0,  1'b1, ~pp[6][16], pp[6], 12'b0};
    assign p7   = {~pp[7][16], pp[7], 14'b0};
    assign svec = {18'b0,
                   sign[7], 1'b0, sign[6], 1'b0, sign[5], 1'b0, sign[4], 1'b0,
                   sign[3], 1'b0, sign[2], 1'b0, sign[1], 1'b0, sign[0]};

    // CSA Wallace Tree                                     

    wire [31:0] rc1, rc2, rc3, rc4, rc5, rc6;
    wire [31:0] s1, c1, s2, c2, s3, c3;
    wire [31:0] s4, c4, s5, c5;
    wire [31:0] s6, c6;
    wire [31:0] row1, row2_raw;

    // Stage 1
    assign s1  = p0 ^ p1 ^ p2;
    assign rc1 = (p0 & p1) | (p1 & p2) | (p2 & p0);
    assign c1  = {rc1[30:0], 1'b0};

    assign s2  = p3 ^ p4 ^ p5;
    assign rc2 = (p3 & p4) | (p4 & p5) | (p5 & p3);
    assign c2  = {rc2[30:0], 1'b0};

    assign s3  = p6 ^ p7 ^ svec;
    assign rc3 = (p6 & p7) | (p7 & svec) | (svec & p6);
    assign c3  = {rc3[30:0], 1'b0};

    // Stage 2
    assign s4  = s1 ^ c1 ^ s2;
    assign rc4 = (s1 & c1) | (c1 & s2) | (s2 & s1);
    assign c4  = {rc4[30:0], 1'b0};

    assign s5  = c2 ^ s3 ^ c3;
    assign rc5 = (c2 & s3) | (s3 & c3) | (c3 & c2);
    assign c5  = {rc5[30:0], 1'b0};

    // Stage 3
    assign s6  = s4 ^ c4 ^ s5;
    assign rc6 = (s4 & c4) | (c4 & s5) | (s5 & s4);
    assign c6  = {rc6[30:0], 1'b0};

    // Stage 4
    assign row1     = s6 ^ c6 ^ c5;
    assign row2_raw = (s6 & c6) | (c6 & c5) | (c5 & s6);

    // Final Addition: Brent-Kung 
    BrentKung #(.WIDTH(32)) bk_adder (
        .A(row1),
        .B({row2_raw[30:0], 1'b0}),
        .Cin(1'b0),
        .Sum(out),
        .Cout()
    );

endmodule
