`timescale 1ns / 1ps

module top_level_cache_system_tb;

    // Parameters from the top-level module
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam L1_CACHE_SIZE = 1024;
    localparam L2_CACHE_SIZE = 4096;
    localparam LINE_SIZE = 4;
    localparam L2_ASSOCIATIVITY = 4;
    localparam NUM_L1_CACHES = 4;

    // Testbench Signals
    reg clk;
    reg reset;

    // Processor simulation signals for each L1 cache instance
    reg [ADDR_WIDTH-1:0] proc_address [NUM_L1_CACHES-1:0];
    reg [DATA_WIDTH-1:0] proc_write_data [NUM_L1_CACHES-1:0];
    reg [NUM_L1_CACHES-1:0] proc_mem_read, proc_mem_write;
    wire [DATA_WIDTH-1:0] proc_read_data [NUM_L1_CACHES-1:0];
    wire [NUM_L1_CACHES-1:0] proc_mem_ready;

    // Instantiate the top-level module
    top_level_cache_system #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .L1_CACHE_SIZE(L1_CACHE_SIZE),
        .L2_CACHE_SIZE(L2_CACHE_SIZE),
        .LINE_SIZE(LINE_SIZE),
        .L2_ASSOCIATIVITY(L2_ASSOCIATIVITY)
    ) uut (
        .clk(clk),
        .reset(reset),
        // Connect processor simulation signals for each L1 cache instance
        .proc_address(proc_address),
        .proc_write_data(proc_write_data),
        .proc_mem_read(proc_mem_read),
        .proc_mem_write(proc_mem_write),
        .proc_read_data(proc_read_data),
        .proc_mem_ready(proc_mem_ready)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // Generate a clock with a period of 10ns
    end

    // Reset logic
    initial begin
        reset = 1;
        #20 reset = 0;  // Release reset after 20ns
    end

    // Test stimuli
    initial begin
        // Reset the system
        reset = 1;
        #20 reset = 0;

        // Initialize processor simulation signals for all L1 caches
        for (int i = 0; i < NUM_L1_CACHES; i++) begin
            proc_address[i] = 0;
            proc_write_data[i] = 0;
            proc_mem_read[i] = 0;
            proc_mem_write[i] = 0;
        end
		  
		// Test Case 1: Simple read operation for L1 cache instance 0
		#100;  // Wait for some time after reset
		proc_address[0] = 32'h0000_0004;  // Set an address to read
		proc_mem_read[0] = 1'b1;          // Trigger a read operation
		#10;                             // Wait for operation to complete
		proc_mem_read[0] = 1'b0;          // Reset the read trigger


		// Test Case 2: Simple write operation for L1 cache instance 1
		#100;                              // Wait for some time
		proc_address[1] = 32'h0000_0008;    // Set an address to write
		proc_write_data[1] = 32'h1234_5678; // Data to write
		proc_mem_write[1] = 1'b1;           // Trigger a write operation
		#10;                               // Wait for operation to complete
		proc_mem_write[1] = 1'b0;           // Reset the write trigger


		// Test Case 3: Cache Miss and Fetch from Memory for L1 cache instance 2
		#100;                               // Wait for some time
		proc_address[2] = 32'h0000_1000;     // Set an address likely to cause a cache miss
		proc_mem_read[2] = 1'b1;             // Trigger a read operation
		#10;                                // Wait for operation to complete
		proc_mem_read[2] = 1'b0;             // Reset the read trigger

		// Test Case 4: Cache Coherence Check among all L1 cache instances
		#100;                               // Wait for some time
		proc_address[0] = 32'h0000_000C;     // Set a common address for all instances
		proc_write_data[0] = 32'hAAAA_BBBB;  // Write different data from each instance
		proc_mem_write[0] = 1'b1;            // Trigger a write operation
		#10;                                // Wait for operation to complete
		proc_mem_write[0] = 1'b0;            // Reset the write trigger

		#10;                                // Wait for some time
		proc_write_data[1] = 32'hCCCC_DDDD;  // Write different data from instance 1
		proc_mem_write[1] = 1'b1;            // Trigger a write operation
		#10;                                // Wait for operation to complete
		proc_mem_write[1] = 1'b0;            // Reset the write trigger

		// Similarly, perform write operations from other instances and then read back
		// the data from each instance to check for coherence.

        // Finish the simulation
        #1000;
        $finish;
    end

    // Additional tasks or functions to apply stimuli
    // ...

endmodule
