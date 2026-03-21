/*
tb_rgb565GrayscaleIse.v

Tesbench for the custom instruction module to perform a grayscale conversion in a singe cycle.

*/

`timescale 1ns/1ns

module tb_rgb565GrayscaleIse;

    // testbench signals
    reg         start;
    reg  [31:0] valueA;
    reg  [7:0]  iseId;
    wire        done;
    wire [31:0] result;

    
    // DUT instanciation
    rgb565GrayscaleIse #(
        .CustomInstructionId(8'd0)
    ) dut (
        .start  (start),
        .valueA (valueA),
        .iseId  (iseId),
        .done   (done),
        .result (result)
    );


    // dump file
    initial begin
        $dumpfile("rgb565GrayscaleIse.vcd");
        $dumpvars(0, tb_rgb565GrayscaleIse);
    end


    // reference grayscale model -> actually only checks that the shift multiplication is correctly implemented
    function [7:0] ref_gray;
        input [15:0] rgb565;

        reg [4:0]  r5;
        reg [5:0]  g6;
        reg [4:0]  b5;
        reg [7:0]  r8;
        reg [7:0]  g8;
        reg [7:0]  b8;
        reg [15:0] gray_full;

        begin
            r5 = rgb565[15:11];
            g6 = rgb565[10:5];
            b5 = rgb565[4:0];

            r8 = (r5 << 3) | (r5 >> 2);
            g8 = (g6 << 2) | (g6 >> 4);
            b8 = (b5 << 3) | (b5 >> 2);

            gray_full = (54*r8) + (183*g8) + (19*b8);
            ref_gray  = gray_full[15:8];
        end
        
    endfunction


    // task runtest
    task run_test;
        input [15:0]  pixel;
        inout integer nb_errors;
        
        reg [7:0] expected;

        begin
            valueA = {16'b0, pixel};
            iseId  = 8'd0;
            start  = 1'b1;
            #1;

            expected = ref_gray(pixel);
            
            // check done assertion
            if (done !== 1'b1) begin
                $display("[%0t ns] ERROR: done not asserted for pixel %h", $time, pixel);
                nb_errors = nb_errors + 1;
            end

            // compare ref and result
            if (result !== {24'b0, expected}) begin
                $display("[%0t ns] ERROR. For pixel: %h, expected is: %h and result is: %h", $time, pixel, expected, result[7:0]);
                nb_errors = nb_errors + 1;

            end else
                $display("[%0t ns] For pixel: %h. Result is : %h", $time, pixel, expected);

            start = 1'b0;
            #5;
        end
    endtask


    // testbench stimulus
    integer i;
    integer nb_errors;
    initial begin
        start     = 0;
        valueA    = 0;
        iseId     = 0;
        nb_errors = 0;
        #10;

        // known pixel value tests
        $display("\nTests with known pixel values. (in order) black, white, red, green, blue, yellow, magenta, cyan.");
        run_test(16'h0000, nb_errors); // black
        run_test(16'hFFFF, nb_errors); // white
        run_test(16'hF800, nb_errors); // red
        run_test(16'h07E0, nb_errors); // green
        run_test(16'h001F, nb_errors); // blue
        run_test(16'hFFE0, nb_errors); // yellow
        run_test(16'hF81F, nb_errors); // magenta
        run_test(16'h07FF, nb_errors); // cyan

        // random pixel value tests
        $display("\nTests with random pixel values.");
        for (i = 0; i < 20; i = i + 1) begin
            run_test($random, nb_errors);
        end

        // test incorrect instruction id
        valueA = 32'h0000_FFFF;
        iseId  = 8'd1;  // correct id is 8'd0
        start  = 1;
        #1;

        if (done !== 0 || result !== 0) begin
            $display("[%0t ns] ERROR: id mismatch, done is: %b, and result is not zero: %h", $time, done, result[7:0]);
            nb_errors = nb_errors + 1;

        end else
            $display("[%0t ns] Id mismatch is correctly handled: done is: %b and result is: %h", $time, done, result[7:0]);
        
        // end
        #10
        if (nb_errors !== 0)
            $display("\n[%0t ns] Testbench completed with %d errors detected.\n", $time, nb_errors);
        else
            $display("\n[%0t ns] Testbench completed without detecting any error.\n", $time);

        $finish;

    end
    
endmodule