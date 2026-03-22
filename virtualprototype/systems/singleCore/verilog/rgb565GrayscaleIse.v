/*
rgb565GrayscaleIse.v

Custom instruction module to perform a grayscale conversion in a singe cycle.

*/

module rgb565GrayscaleIse #(
        parameter [7:0] CustomInstructionId = 8'd8
    )(
        input  wire        start,
        input  wire [31:0] valueA,  // RGB 565 value. Only the lower 16 bits contain proper info.
        input  wire [7:0]  iseId,
        output wire        done,
        output wire [31:0] result   // grayscale value. Only the lower 8 bits contain proper info, rest must be zero.
    );

    assign done = (iseId == CustomInstructionId) & start;
    
    // extract RGB-565 channels
    wire [4:0] r5 = valueA[15:11];
    wire [5:0] g6 = valueA[10:5];
    wire [4:0] b5 = valueA[4:0];

    // expansion of RGB-565 to RGB-888 : fill the LSBs with the MSBs of the initial channels
    wire [15:0] r8 = {r5, r5[4:2]};
    wire [15:0] g8 = {g6, g6[5:4]};
    wire [15:0] b8 = {b5, b5[4:2]};

    // channels coefficients computation without multiplication : 2power-decomposition
    wire [15:0] gray_full = (r8 << 5) + (r8 << 4) + (r8 << 2) + (r8 << 1)                      // 54*r
                          + (g8 << 7) + (g8 << 5) + (g8 << 4) + (g8 << 2) + (g8 << 1) + g8     // 183*g
                          + (b8 << 4) + (b8 << 1) + b8;                                        // 19*b

    wire [7:0]  gray      = gray_full[15:8];

    assign result = ((iseId == CustomInstructionId) & start) ? {24'b0, gray} : 32'b0;

    
endmodule