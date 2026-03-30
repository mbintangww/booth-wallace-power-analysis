// D FLIP FLOP
`timescale 1ns / 1ps

module DFF (
            input clk , input reset ,
            input clock_enable ,
            input [15:0] A , input [15:0] B,
            output reg [15:0] A_ff ,
            output reg [15:0] B_ff
            );

`ifdef SYNTHESIS
    // ICG structural — sky130_fd_sc_hd__dlclkp_1
    wire clk_gated;
    sky130_fd_sc_hd__dlclkp_1 ICG (
        .CLK  (clk),
        .GATE (clock_enable),
        .GCLK (clk_gated)
    );
    always @(posedge clk_gated or posedge reset) begin
        if (reset) begin
            A_ff <= 16'b0;
            B_ff <= 16'b0;
        end else begin
            A_ff <= A;
            B_ff <= B;
        end
    end
`else
    // Behavioral fallback for RTL simulation (iverilog)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            A_ff <= 16'b0;
            B_ff <= 16'b0;
        end else if (clock_enable) begin
            A_ff <= A;
            B_ff <= B;
        end
    end
`endif

endmodule
