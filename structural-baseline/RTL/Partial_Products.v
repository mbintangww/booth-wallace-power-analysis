// PARTIAL PRODUCTS GENERATOR
`timescale 1ns / 1ps


module Partial_Products (
                        input [15:0] A_ff,
                        input [15:0] B_ff,
                        output [135:0] PP_flat,
                        output [7:0] sign);

    wire [17:0] multiplicand;
    assign multiplicand = {B_ff[15], B_ff, 1'b0};

    wire [16:0] PP_arr [0:7];

    genvar k;
    generate
        for (k = 0; k < 8; k = k + 1) begin : gen_enc
            Booth_Encoder enc (
                .multiplicand(multiplicand[2*k+2 : 2*k]),
                .A_ff(A_ff),
                .PP(PP_arr[k]),
                .sign(sign[k])
            );
         
            assign PP_flat[(k+1)*17-1 : k*17] = PP_arr[k];
        end
    endgenerate

endmodule