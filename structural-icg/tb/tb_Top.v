// Testbench for Top (N=16, signed 16x16 multiplier)
// Self-checking: each test compares Output against known expected value
`timescale 1ns / 1ps

module tb_Top;

    reg                   clk;
    reg                   reset;
    reg  signed [15:0]    A;
    reg  signed [15:0]    B;
    wire signed [31:0]    Output;

    integer pass_count, fail_count;

    Top uut (
        .clk(clk),
        .reset(reset),
        .A(A),
        .B(B),
        .Output(Output)
    );

    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_Top);
    end

    // Set A, B; wait 2 pipeline cycles; compare Output vs expected
    task apply_test;
        input signed [15:0]    ta, tb;
        input signed [31:0]    expected;
        reg   signed [31:0]    exp_latch;
        begin
            exp_latch = expected;
            A = ta; B = tb;
            #20; // 2 clock cycles = pipeline latency
            if (Output === exp_latch) begin
                pass_count = pass_count + 1;
                $display("PASS: %0d * %0d = %0d", ta, tb, Output);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: %0d * %0d = %0d  (expected %0d)", ta, tb, Output, exp_latch);
            end
        end
    endtask

    initial begin
        pass_count = 0; fail_count = 0;
        $monitor("Time=%0t | %d * %d = %d", $time, A, B, Output);

        reset = 1; A = 0; B = 0;
        #110;
        reset = 0;
        @(posedge clk);
        #1;

        // ----------------------------------------------------------------
        // Original test cases (TC1-TC8)
        // ----------------------------------------------------------------
        apply_test( 16'sd4,              16'sd5,              32'sd20          ); // TC1:  4*5
        apply_test( 16'sd10,            -16'sd2,             -32'sd20          ); // TC2:  10*(-2)
        apply_test(-16'sd5,              16'sd5,             -32'sd25          ); // TC3:  (-5)*5
        apply_test(-16'sd10,            -16'sd10,             32'sd100         ); // TC4:  (-10)*(-10)
        apply_test( 16'sd32767,          16'sd32767,           32'sd1073676289  ); // TC5:  max positive
        apply_test($signed(16'h8000),    16'sd1,              -32'sd32768       ); // TC6:  -32768*1
        apply_test($signed(16'h8000),   $signed(16'h8000),    32'sd1073741824   ); // TC7:  (-32768)^2
        apply_test( 16'sd1000,          -16'sd2000,           -32'sd2000000     ); // TC8:  1000*(-2000)

        // ----------------------------------------------------------------
        // Additional test cases (TC9-TC17)
        // ----------------------------------------------------------------
        apply_test( 16'sd0,              16'sd12345,           32'sd0           ); // TC9:  zero x positive
        apply_test( 16'sd777,            16'sd0,               32'sd0           ); // TC10: positive x zero
        apply_test( 16'sd0,              16'sd0,               32'sd0           ); // TC11: zero x zero
        apply_test( 16'sd9999,           16'sd1,               32'sd9999        ); // TC12: identity x1
        apply_test( 16'sd1,             -16'sd4567,            -32'sd4567        ); // TC13: identity 1x
        apply_test( 16'sd500,           -16'sd1,              -32'sd500         ); // TC14: negate x(-1)
        apply_test(-16'sd1,              16'sd32767,           -32'sd32767       ); // TC15: negate (-1)x
        apply_test( 16'sd256,            16'sd128,             32'sd32768        ); // TC16: power-of-2
        // TC17: alternating bits — 0x5555=21845, 0xAAAA=-21846, product=-477225870=32'shE38E1C72
        apply_test($signed(16'h5555),   $signed(16'hAAAA),    32'shE38E1C72     ); // TC17: alternating bits

        $display("\n=== RESULT: %0d passed, %0d failed ===", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");

        $finish;
    end

endmodule
