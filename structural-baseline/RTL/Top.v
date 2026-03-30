// TOP MODULE
`timescale 1ns / 1ps

module Top (
    input              clk,
    input              reset,
    input  [15:0]      A,
    input  [15:0]      B,
    output reg [31:0]  Output
);

    wire [15:0]  A_ff, B_ff;
    wire [135:0] PP_flat;
    wire [7:0]   sign;
    wire [31:0]  OUT;

    DFF D_ff (
        .clk(clk),
        .reset(reset),
        .A(A),
        .B(B),
        .A_ff(A_ff),
        .B_ff(B_ff)
    );

    Partial_Products Gen_PP (
        .A_ff(A_ff),
        .B_ff(B_ff),
        .PP_flat(PP_flat),
        .sign(sign)
    );

    Partial_Products_Adder Adder (
        .PP_flat(PP_flat),
        .sign(sign),
        .out(OUT)
    );

    always @(posedge clk or posedge reset) begin
        if (reset)
            Output <= 32'b0;
        else
            Output <= OUT;
    end

endmodule
