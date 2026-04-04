// Testbench for Top — parameterized zero-input power analysis
// 1000 random test cases: ZERO_PCT% have at least one operand = 0
// Self-checking: verifies output against expected A*B
// Override at compile time: iverilog -DZERO_PCT=50 ...
`ifndef ZERO_PCT
  `define ZERO_PCT 70
`endif
`timescale 1ns / 1ps

module tb_Top_power;

    reg               clk;
    reg               reset;
    reg  signed [15:0] A;
    reg  signed [15:0] B;
    wire signed [31:0] Output;

    integer pass_count, fail_count, i;
    reg signed [15:0] A_d1, B_d1;  // inputs delayed 1 iteration (= 1 pipeline stage ago)
    reg signed [31:0] expected;

    Top uut (
        .clk(clk),
        .reset(reset),
        .A(A),
        .B(B),
        .Output(Output)
    );

    initial begin clk = 0; forever #8 clk = ~clk; end

    initial begin
        $dumpfile("sim_out/gate_level.vcd");
        $dumpvars(0, tb_Top_power.uut);
    end

    initial begin
        pass_count = 0;
        fail_count = 0;

        // Reset
        reset = 1; A = 0; B = 0;
        #110;
        reset = 0;
        @(posedge clk); #1;

        A_d1 = 0; B_d1 = 0;

        for (i = 0; i < 1000; i = i + 1) begin
            // ZERO_PCT% chance: at least one operand = 0
            if (($urandom % 100) < `ZERO_PCT) begin
                case ($urandom % 3)
                    0: begin A = 0;        B = $urandom; end
                    1: begin A = $urandom; B = 0;        end
                    2: begin A = 0;        B = 0;        end
                endcase
            end else begin
                A = $urandom;
                if (A == 0) A = 1;
                B = $urandom;
                if (B == 0) B = 1;
            end

            @(posedge clk); #1;

            // After posedge i, Output = A[i-1] * B[i-1] = A_d1 * B_d1
            if (i >= 1) begin
                expected = A_d1 * B_d1;
                if (Output === expected) begin
                    pass_count = pass_count + 1;
                end else begin
                    fail_count = fail_count + 1;
                    $display("FAIL[%0d]: %0d * %0d = %0d (expected %0d)",
                             i-1, A_d1, B_d1, Output, expected);
                end
            end

            A_d1 = A;
            B_d1 = B;
        end

        // Drain last pipeline output (A[999]*B[999])
        A = 0; B = 0;
        @(posedge clk); #1;
        expected = A_d1 * B_d1;
        if (Output === expected)
            pass_count = pass_count + 1;
        else begin
            fail_count = fail_count + 1;
            $display("FAIL[drain]: %0d * %0d = %0d (expected %0d)",
                     A_d1, B_d1, Output, expected);
        end

        $display("\n=== RESULT: %0d passed, %0d failed ===", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");

        $finish;
    end

endmodule
