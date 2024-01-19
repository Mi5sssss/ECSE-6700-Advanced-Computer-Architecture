`timescale 1ns / 1ps

module testbench;
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter NUM_LINES = 256;
    parameter TAG_WIDTH = 10;

    // Inputs to the UUT
    logic clk;
    logic reset;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] write_data;
    logic read;
    logic write;

    // Outputs from the UUT
    logic [DATA_WIDTH-1:0] read_data;
    logic hit;
    logic miss;

    // Instantiate the Unit Under Test (UUT)
    simple_cache_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_LINES(NUM_LINES),
        .TAG_WIDTH(TAG_WIDTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .addr(addr),
        .write_data(write_data),
        .read(read),
        .write(write),
        .read_data(read_data),
        .hit(hit),
        .miss(miss)
    );

    // Clock generation
    initial clk = 0;
    always begin
        #5 clk = ~clk; // Toggle clock every 5 ns
    end

    initial begin
        // Initialize Inputs
        reset = 1;
        addr = 0;
        write_data = 0;
        read = 0;
        write = 0;

        // Apply reset
        #50;
        reset = 0;

        // Test Case 1: Read from an unwritten address (Expect MISS)
        $display("Time: %0t, Starting read from an unwritten address.", $time);
        addr = 32'hC; // Unwritten address
        read = 1;
        #20;
        read = 0;
        $display("Time: %0t, Read operation from unwritten address completed.", $time);
        #20;

        // Test Case 2: Write then Read from a different address (Expect MISS)
        #50; // Wait for some time
        $display("Time: %0t, Starting write to a different address.", $time);
        addr = 32'hE; // Different address
        write_data = 32'hCAFEBABE;
        write = 1;
        #20;
        write = 0;
        $display("Time: %0t, Write operation to different address completed.", $time);

        // Read from the new address
        addr = 32'hB;
        read = 1;
        #20;
        read = 0;
        $display("Time: %0t, Read operation from different address completed.", $time);
        #20;

        // Test Case 3: Write then Read from the same address (Expect HIT)
        $display("Time: %0t, Starting write then read from same address.", $time);
        addr = 32'hD;
        write_data = 32'hBABECAFE;
        write = 1;
        #20;
        write = 0;

        addr = 32'hD;
        read = 1;
        #20;
        read = 0;
        $display("Time: %0t, Read operation from same address completed.", $time);
        #20;

        // Test Case 4: Write to an existing address (Expect HIT on Read)
        $display("Time: %0t, Starting write to existing address.", $time);
        addr = 32'hD; // Previously written address
        write_data = 32'h12345678;
        write = 1;
        #20;
        write = 0;

        addr = 32'hD;
        read = 1;
        #20;
        read = 0;
        $display("Time: %0t, Read operation from existing address completed.", $time);
        #20;

        // End of test
        $display("Time: %0t, End of Test.", $time);
//        $finish;
    end
endmodule