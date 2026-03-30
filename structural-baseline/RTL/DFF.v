// D FLIP FLOP
`timescale 1ns / 1ps


module DFF (
            input clk , input reset ,
            input [15:0] A , input [15:0] B,
            output reg [15:0] A_ff ,
            output reg [15:0] B_ff
            );

        always@(posedge clk or posedge reset) begin
            if(reset)begin
                A_ff <= 16'b0;
                B_ff <= 16'b0;
                end
            else begin
                A_ff <= A;
                B_ff <= B;
            end
         end
endmodule   
