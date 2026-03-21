/*
rgb565GrayscaleIse.v

Custom instruction module to perform a grayscale conversion in a singe cycle.

*/

module rgb565GrayscaleIse #(
        parameter [7:0] CustomInstructionId = 8'd0
    )(
        input  wire        start,
        input  wire [31:0] valueA,  // RGB 565 value. Only the lower 16 bits contain proper info.
        input  wire [7:0]  iseId,
        output wire        done,
        output wire [31:0] result   // grayscale value. Only the lower 8 bits contain proper info, rest must be zero.
    );

    
    // extract RGB-565 channels
    wire [4:0] r5 = valueA[15:11];
    wire [5:0] g6 = valueA[10:5];
    wire [4:0] b5 = valueA[4:0];

    // expansion of RGB-565 to RGB-888 : shift the existing bits to the left and fill the new lower bits with the MSBs of the original color
    wire [7:0] r8 = (r5 << 3) | (r5 >> 2);
    wire [7:0] g8 = (g6 << 2) | (g6 >> 4);
    wire [7:0] b8 = (b5 << 3) | (b5 >> 2);

    // channels coefficients computation without multiplication : 2power-decomposition
    wire [15:0] r = (r8 << 5) + (r8 << 4) + (r8 << 2) + (r8 << 1);                      // r = 54*r8
    wire [15:0] g = (g8 << 7) + (g8 << 5) + (g8 << 4) + (g8 << 2) + (g8 << 1) + g8;     // g = 183*g8
    wire [15:0] b = (b8 << 4) + (b8 << 1) + b8;                                         // b = 19*b8

    // grayscale conversion
    wire [15:0] gray_full = r + g + b;
    wire [7:0]  gray      = gray_full[15:8];


    assign done   = (iseId == CustomInstructionId) && start;
    assign result = ((iseId == CustomInstructionId) && start) ? {24'b0, gray} : 32'b0;
    
endmodule