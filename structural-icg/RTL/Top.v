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

    // Layer 1: clock gate — suppress multiplier switching when either input is zero
    wire clock_enable = !((A == 16'b0) || (B == 16'b0));

    // Layer 2: delay register — tracks inputs one cycle behind for output mux (not clock-gated)
    reg [15:0] A_del, B_del;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            A_del <= 16'b0;
            B_del <= 16'b0;
        end else begin
            A_del <= A;
            B_del <= B;
        end
    end

    DFF D_ff (
        .clk(clk),
        .reset(reset),
        .clock_enable(clock_enable),
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

    // Layer 2: output mux — force output to zero when delayed input was zero
    wire zero_out = (A_del == 16'b0) || (B_del == 16'b0);

    always @(posedge clk or posedge reset) begin
        if (reset)
            Output <= 32'b0;
        else if (zero_out)
            Output <= 32'b0;
        else
            Output <= OUT;
    end

endmodule
