// Brent-Kung Parallel Prefix Adder
`timescale 1ns / 1ps

module BrentKung #(parameter WIDTH = 32) (
    input  [WIDTH-1:0] A,
    input  [WIDTH-1:0] B,
    input              Cin,
    output [WIDTH-1:0] Sum,
    output             Cout
);

    localparam LOG_W       = $clog2(WIDTH);
    localparam TOTAL_LEVELS = 2 * LOG_W;

    // Bit-level propagate and generate
    wire [WIDTH-1:0] p_b, g_b;
    assign p_b = A ^ B;
    assign g_b = A & B;

    // 2D wire arrays: one WIDTH-bit word per level
    wire [WIDTH-1:0] P_level [0:TOTAL_LEVELS-1];
    wire [WIDTH-1:0] G_level [0:TOTAL_LEVELS-1];

    // Level 0: absorb Cin into bit 0
    assign G_level[0] = {g_b[WIDTH-1:1], (g_b[0] | (p_b[0] & Cin))};
    assign P_level[0] = p_b;

    // UP-SWEEP
    genvar l, i;
    generate
        for (l = 1; l <= LOG_W; l = l + 1) begin : up_sweep
            for (i = 0; i < WIDTH; i = i + 1) begin : bits
                if (((i + 1) % (1 << l)) == 0) begin : bc
                    assign G_level[l][i] = G_level[l-1][i]
                                         | (P_level[l-1][i] & G_level[l-1][i - (1 << (l-1))]);
                    assign P_level[l][i] = P_level[l-1][i] & P_level[l-1][i - (1 << (l-1))];
                end else begin : pt
                    assign G_level[l][i] = G_level[l-1][i];
                    assign P_level[l][i] = P_level[l-1][i];
                end
            end
        end
    endgenerate

    // DOWN-SWEEP
    genvar d;
    generate
        for (d = 1; d < LOG_W; d = d + 1) begin : down_sweep
            for (i = 0; i < WIDTH; i = i + 1) begin : bits
                if ((((i + 1) % (1 << (LOG_W - d))) == (1 << (LOG_W - 1 - d)))
                     && (i >= (1 << (LOG_W - d)) - 1)) begin : bc
                    assign G_level[LOG_W + d][i] =
                        G_level[LOG_W + d - 1][i]
                        | (P_level[LOG_W + d - 1][i]
                           & G_level[LOG_W + d - 1][i - (1 << (LOG_W - 1 - d))]);
                    assign P_level[LOG_W + d][i] =
                        P_level[LOG_W + d - 1][i]
                        & P_level[LOG_W + d - 1][i - (1 << (LOG_W - 1 - d))];
                end else begin : pt
                    assign G_level[LOG_W + d][i] = G_level[LOG_W + d - 1][i];
                    assign P_level[LOG_W + d][i] = P_level[LOG_W + d - 1][i];
                end
            end
        end
    endgenerate

    // Final sum
    wire [WIDTH-1:0] carry;
    assign carry[0] = Cin;
    generate
        for (i = 1; i < WIDTH; i = i + 1) begin : gen_carry
            assign carry[i] = G_level[TOTAL_LEVELS-1][i-1];
        end
    endgenerate

    assign Sum  = p_b ^ carry;
    assign Cout = G_level[TOTAL_LEVELS-1][WIDTH-1];

endmodule
