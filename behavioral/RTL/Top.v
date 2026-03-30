// TOP MODULE - Behavioral 16x16 signed multiplier
`timescale 1ns / 1ps

module Top (
    input              clk,
    input              reset,
    input  [15:0]      A,
    input  [15:0]      B,
    output reg [31:0]  Output
);

    reg signed [15:0] A_ff, B_ff;

    // Pipeline stage 1: register inputs
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            A_ff <= 16'b0;
            B_ff <= 16'b0;
        end else begin
            A_ff <= A;
            B_ff <= B;
        end
    end

    // Pipeline stage 2: multiply + register output
    always @(posedge clk or posedge reset) begin
        if (reset) Output <= 32'b0;
        else       Output <= A_ff * B_ff;
    end

endmodule
