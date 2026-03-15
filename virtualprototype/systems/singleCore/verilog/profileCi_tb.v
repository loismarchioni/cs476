`timescale 1ns/1ns  

module tb_profcounters;

    // Testbench signals
    reg         start;
    reg         clock;
    reg         reset;
    reg         stall;
    reg         busIdle;
    reg  [31:0] valueA;
    reg  [31:0] valueB;
    reg  [7:0]  ciN;
    wire        done;
    wire [31:0] result;

    // Instantiate the DUT
    profcounters #(
        .customId(8'hb)   
    ) DUT (
        .start(start),
        .clock(clock),
        .reset(reset),
        .stall(stall),
        .busIdle(busIdle),
        .valueA(valueA),
        .valueB(valueB),
        .ciN(ciN),
        .done(done),
        .result(result)
    );

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock; // 100 MHz clock
    end

    // Waveform dumping
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_profcounters);
    end

    // Monitor internal DUT signals automatically on any change
    initial begin
        $monitor("[%0t ns] done=%b result=%0d | enable0=%b enable1=%b enable2=%b enable3=%b | stall=%b busIdle=%b",
                  $time, done, result,
                  DUT.enable0, DUT.enable1, DUT.enable2, DUT.enable3,
                  stall, busIdle);
    end

    // Task: fire a CI call for one cycle
    task ci_call;
        input [31:0] a;
        input [31:0] b;
        begin
            @(negedge clock);
            ciN    = 8'hb;
            valueA = a;
            valueB = b;
            start  = 1;
            @(negedge clock);
            start  = 0;
            ciN    = 8'h00;
            valueA = 0;
            valueB = 0;
        end
    endtask

    // Task: read a counter
    task read_counter;
        input [1:0] counter_id;
        begin
            @(negedge clock);
            ciN    = 8'hb;
            valueA = {30'd0, counter_id};
            valueB = 32'd0;
            start  = 1;
            @(posedge clock); #1;
            $display("[%0t ns] Counter%0d = %0d", $time, counter_id, result);
            @(negedge clock);
            start  = 0;
            ciN    = 8'h00;
            valueA = 0;
        end
    endtask

    // Test stimulus
    initial begin
        // Initialize signals
        start   = 0;
        reset   = 1;
        stall   = 0;
        busIdle = 0;
        valueA  = 0;
        valueB  = 0;
        ciN     = 8'h00;

        // Release reset
        #20;
        reset = 0;
        #10;

        // --- Enable Counter0 ---
        $display("[%0t ns] Enabling Counter0", $time);
        ci_call(32'd0, 32'b0000_0000_0000_0001);
        #50;

        // --- Enable Counter1, toggle stall ---
        $display("[%0t ns] Enabling Counter1", $time);
        ci_call(32'd0, 32'b0000_0000_0000_0011);
        #20;
        $display("[%0t ns] Stall ON", $time);
        stall = 1;
        #30;
        $display("[%0t ns] Stall OFF", $time);
        stall = 0;
        #20;

        // --- Enable Counter2, toggle busIdle ---
        $display("[%0t ns] Enabling Counter2", $time);
        ci_call(32'd0, 32'b0000_0000_0000_0111);
        #20;
        $display("[%0t ns] busIdle ON", $time);
        busIdle = 1;
        #30;
        $display("[%0t ns] busIdle OFF", $time);
        busIdle = 0;
        #20;

        // --- Enable Counter3 ---
        $display("[%0t ns] Enabling Counter3", $time);
        ci_call(32'd0, 32'b0000_0000_0000_1111);
        #50;

        // --- Disable all counters ---
        $display("[%0t ns] Disabling all counters", $time);
        ci_call(32'd0, 32'b0000_0000_1111_0000);
        #20;

        // --- Read all counters ---
        $display("[%0t ns] --- Reading counters ---", $time);
        read_counter(2'd0);
        read_counter(2'd1);
        read_counter(2'd2);
        read_counter(2'd3);

        #20;
        $finish;
    end

endmodule