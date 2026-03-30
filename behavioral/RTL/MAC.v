// MAC (Multiply-Accumulate) Unit - Behavioral
`timescale 1ns / 1ps

module MAC (
    input              clk,
    input              reset,
    input              clear,      
    input  [15:0]      A,
    input  [15:0]      B,
    input              valid_in,
    output reg [47:0]  result,
    output reg         valid_out
);

    wire [31:0]  mult_out;
    wire [47:0]  mult_sign_ext;
    reg  [2:0]   valid_sr;     
    reg  [47:0]  accumulator;

    // Instantiate the 2-stage pipelined multiplier
    Top multiplier (
        .clk(clk),
        .reset(reset),
        .A(A),
        .B(B),
        .Output(mult_out)
    );

    // Sign-extend multiplier output from 32 to 48 bits
    assign mult_sign_ext = {{16{mult_out[31]}}, mult_out};
    always @(posedge clk or posedge reset) begin
        if (reset) valid_sr <= 3'b0;
        else       valid_sr <= {valid_sr[1:0], valid_in};
    end

    // Accumulator and output logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            accumulator <= 48'b0;
            result      <= 48'b0;
            valid_out   <= 1'b0;
        end else begin
            valid_out <= valid_sr[2];
            if (clear)
                accumulator <= 48'b0;
            else if (valid_sr[1])                   
                accumulator <= accumulator + mult_sign_ext;
            result <= accumulator;
        end
    end

endmodule
