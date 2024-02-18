module top_level_cache_system #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter L1_CACHE_SIZE = 256, // Size in bytes for L1 cache
    parameter L2_CACHE_SIZE = 1024, // Size in bytes for L2 cache
    // parameter L1_CACHE_SIZE = 256, // Size in bytes for L1 cache
    // parameter L2_CACHE_SIZE = 1024, // Size in bytes for L2 cache
    parameter LINE_SIZE = 4,        // Line size in bytes
    parameter L2_ASSOCIATIVITY = 4  // 4-way set associative for L2
) (
    input wire clk,
    input wire reset,
    // Additional ports for simulating processor interaction
    input wire [ADDR_WIDTH-1:0] proc_address[3:0],
    input wire [DATA_WIDTH-1:0] proc_write_data[3:0],
    input wire proc_mem_read,
    input wire proc_mem_write,
    output wire [DATA_WIDTH-1:0] proc_read_data[3:0],
    output wire [3:0]proc_mem_ready
    // Other ports, such as those interfacing with the processors or testbench, are not shown here
);

    // Instantiate the L1 and L2 caches and arbiter
    // Signals for L1 to L2 interfaces
    wire [3:0] l1_to_l2_read_req, l1_to_l2_write_req, l2_to_l1_read_ready, l2_to_l1_write_ready;
    wire [ADDR_WIDTH-1:0] l1_to_l2_address[3:0];
    wire [DATA_WIDTH-1:0] l1_to_l2_write_data[3:0], l2_to_l1_read_data[3:0];

    // Signals for L2 to arbiter interfaces
    wire [3:0] l2_to_arb_read_req, l2_to_arb_write_req, arb_to_l2_ready;
    wire [ADDR_WIDTH-1:0] l2_to_arb_address[3:0];
    wire [DATA_WIDTH-1:0] l2_to_arb_write_data[3:0], arb_to_l2_read_data[3:0];

    // Signals for arbiter to memory interface
    wire arb_to_mem_read_req, arb_to_mem_write_req, mem_to_arb_ready;
    wire [ADDR_WIDTH-1:0] arb_to_mem_address;
    wire [DATA_WIDTH-1:0] arb_to_mem_write_data, mem_to_arb_read_data;

    // MESI snooping signals
    wire [3:0] snoop_read, snoop_write;
    wire [ADDR_WIDTH-1:0] snoop_address[3:0];
    wire [3:0] snoop_response;
	
    genvar i;
	 generate
        for (i = 0; i < 4; i++) begin : cache_instances
            l1_cache #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .CACHE_SIZE(L1_CACHE_SIZE),
                .LINE_SIZE(LINE_SIZE)
            ) l1_inst (
                .clk(clk),
                .reset(reset),
//                // Connecting processor-simulating interfaces
               .address(proc_address[i]),
               .write_data(proc_write_data[i]),
               .mem_read(proc_mem_read),
               .mem_write(proc_mem_write),
               .read_data(proc_read_data[i]),
               .mem_ready(proc_mem_ready[i]),
                // Interface with L2 cache
                .l2_read_req(l1_to_l2_read_req[i]),
                .l2_write_req(l1_to_l2_write_req[i]),
                .l2_address(l1_to_l2_address[i]),
                .l2_write_data(l1_to_l2_write_data[i]),
                .l2_read_data(l2_to_l1_read_data[i]),
                .l2_read_ready(l2_to_l1_read_ready[i]),
                .l2_write_ready(l2_to_l1_write_ready[i]),
                // MESI snooping signals
                .snoop_read(snoop_read[i]),
                .snoop_write(snoop_write[i]),
                .snoop_address(snoop_address[i]),
                .snoop_response(snoop_response[i])
            );

            l2_cache #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .CACHE_SIZE(L2_CACHE_SIZE),
                .LINE_SIZE(LINE_SIZE),
                .ASSOCIATIVITY(L2_ASSOCIATIVITY)
            ) l2_inst (
                .clk(clk),
                .reset(reset),
                // Interface with L1 cache
                .l1_read_req(l1_to_l2_read_req[i]),
                .l1_write_req(l1_to_l2_write_req[i]),
                .l1_address(l1_to_l2_address[i]),
                .l1_write_data(l1_to_l2_write_data[i]),
                .l1_read_data(l2_to_l1_read_data[i]),
                .l1_read_ready(l2_to_l1_read_ready[i]),
                .l1_write_ready(l2_to_l1_write_ready[i]),
                // Interface with arbiter
                .mem_read_req(l2_to_arb_read_req[i]),
                .mem_write_req(l2_to_arb_write_req[i]),
                .mem_address(l2_to_arb_address[i]),
                .mem_write_data(l2_to_arb_write_data[i]),
                .mem_read_data(arb_to_l2_read_data[i]),
                .mem_read_ready(arb_to_l2_ready[i]),
                .mem_write_ready(arb_to_l2_ready[i])
            );
        end
    endgenerate

    arbiter #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PORTS(4)
    ) arbiter_inst (
        .clk(clk),
        .reset(reset),
        // Interface with all L2 caches
        .read_req(l2_to_arb_read_req),
        .write_req(l2_to_arb_write_req),
        .address(l2_to_arb_address),
        .write_data(l2_to_arb_write_data),
        .read_data(arb_to_l2_read_data),
        .ready(arb_to_l2_ready),
        // Interface with memory
        .mem_address(arb_to_mem_address),
        .mem_write_data(arb_to_mem_write_data),
        .mem_read_data(mem_to_arb_read_data),
        .mem_read_req(arb_to_mem_read_req),
        .mem_write_req(arb_to_mem_write_req),
        .mem_ready(mem_to_arb_ready)
    );

    // Memory model or actual memory interface
    // (For simulation, a memory model might be used. For synthesis, connect to actual memory.)
    // ...

endmodule
