`define MESI_MODIFIED   2'b11
`define MESI_EXCLUSIVE  2'b10
`define MESI_SHARED     2'b01
`define MESI_INVALID    2'b00

module l1_cache #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,
  parameter CACHE_SIZE = 1024, // Cache size in bytes
  parameter LINE_SIZE = 4      // Line size in bytes
) (
  input wire clk,
  input wire reset,
  input wire [ADDR_WIDTH-1:0] address,
  input wire [DATA_WIDTH-1:0] write_data,
  input wire mem_read,
  input wire mem_write,
  output reg [DATA_WIDTH-1:0] read_data,
  output reg mem_ready,
  // Interface with L2 cache
  output reg l2_read_req,
  output reg l2_write_req,
  output reg [ADDR_WIDTH-1:0] l2_address,
  output reg [DATA_WIDTH-1:0] l2_write_data,
  input wire [DATA_WIDTH-1:0] l2_read_data,
  input wire l2_read_ready,
  input wire l2_write_ready,
  // MESI Protocol snooping inputs
  input wire snoop_read,
  input wire snoop_write,
  input wire [ADDR_WIDTH-1:0] snoop_address,
  output reg snoop_response // Output to indicate action taken on snoop
);

  // Cache line structure
  typedef struct packed {
    logic valid;
    logic [ADDR_WIDTH-1:0] tag;
    logic [DATA_WIDTH-1:0] data;
    logic [1:0] mesi_state;
  } cache_line_t;

  // Cache memory array
  cache_line_t cache_mem [CACHE_SIZE/LINE_SIZE];

  // Cache indexing logic
  localparam INDEX_SIZE = $clog2(CACHE_SIZE/LINE_SIZE);
  localparam TAG_SIZE = ADDR_WIDTH - INDEX_SIZE;
  wire [INDEX_SIZE-1:0] index = address[INDEX_SIZE-1:0];
  wire [TAG_SIZE-1:0] tag = address[ADDR_WIDTH-1:INDEX_SIZE];

  // Round-Robin eviction pointer
  reg [INDEX_SIZE-1:0] rr_evict_ptr = 0;

  always_ff @(posedge clk) begin
    if (reset) begin
      // Reset cache state and eviction pointer
      for (int i = 0; i < CACHE_SIZE/LINE_SIZE; i++) begin
        cache_mem[i].valid <= 0;
        cache_mem[i].mesi_state <= `MESI_INVALID;
		  cache_mem[i].tag <= 0;
		  cache_mem[i].data <= 0;
      end
      rr_evict_ptr <= 0;
      mem_ready <= 0;
      l2_read_req <= 0;
      l2_write_req <= 0;
    end else begin
      // Handle read/write requests
      if (mem_read && !mem_ready) begin
        if (cache_mem[index].valid && cache_mem[index].tag == tag) begin
          // Cache hit logic
          read_data <= cache_mem[index].data;
          mem_ready <= 1;
        end else begin
          // Cache miss logic
          l2_read_req <= 1;
          l2_address <= address;
        end
      end
      if (mem_write && !mem_ready) begin
        if (cache_mem[index].valid && cache_mem[index].tag == tag) begin
          // Write hit logic
          cache_mem[index].data <= write_data;
          cache_mem[index].mesi_state <= `MESI_MODIFIED;
          mem_ready <= 1;
        end else begin
          // Write miss logic
          l2_write_req <= 1;
          l2_address <= address;
          l2_write_data <= write_data;
        end
      end
      // Handle L2 cache responses
      if (l2_read_req && l2_read_ready) begin
        // L2 read complete
        cache_mem[index].data <= l2_read_data;
        cache_mem[index].valid <= 1;
        cache_mem[index].tag <= tag;
        cache_mem[index].mesi_state <= `MESI_EXCLUSIVE;
        read_data <= l2_read_data;
        mem_ready <= 1;
        l2_read_req <= 0;
      end
      if (l2_write_req && l2_write_ready) begin
        // L2 write complete
        cache_mem[index].valid <= 1;
        cache_mem[index].tag <= tag;
        cache_mem[index].mesi_state <= `MESI_MODIFIED;
        mem_ready <= 1;
        l2_write_req <= 0;
      end

		// Modify the logic for cache miss
		if ((mem_read || mem_write) && !cache_mem[index].valid) begin
		  // Check if we need to evict an existing cache line
		  if (cache_mem[rr_evict_ptr].valid) begin
			 // Evict the cache line at rr_evict_ptr
			 if (cache_mem[rr_evict_ptr].mesi_state == `MESI_MODIFIED) begin
				// Write back if the line is dirty
				l2_write_req <= 1;
				l2_address <= {cache_mem[rr_evict_ptr].tag, rr_evict_ptr};
				l2_write_data <= cache_mem[rr_evict_ptr].data;
			 end
			 // Invalidate the evicted line
			 cache_mem[rr_evict_ptr].valid <= 0;
			 cache_mem[rr_evict_ptr].mesi_state <= `MESI_INVALID;
		  end
		  // Update the eviction pointer
		  rr_evict_ptr <= (rr_evict_ptr + 1) % (CACHE_SIZE/LINE_SIZE);

		  // Initiate L2 cache read or write request for the new data
		  if (mem_read) begin
			 l2_read_req <= 1;
			 l2_address <= address;
		  end
		  if (mem_write) begin
			 l2_write_req <= 1;
			 l2_address <= address;
			 l2_write_data <= write_data;
		  end
		end


      // Snoop read/write operations
      snoop_response <= 0; // Default no action
      if ((snoop_read || snoop_write) && cache_mem[index].valid) begin
        if (cache_mem[index].tag == snoop_address[TAG_SIZE+INDEX_SIZE-1:INDEX_SIZE]) begin
          case (cache_mem[index].mesi_state)
            `MESI_MODIFIED: begin
              if (snoop_write) begin
                cache_mem[index].mesi_state <= `MESI_INVALID;
                cache_mem[index].valid <= 0;
                l2_write_req <= 1;
                l2_address <= {cache_mem[index].tag, index};
                l2_write_data <= cache_mem[index].data;
                snoop_response <= 1;
              end else begin
                cache_mem[index].mesi_state <= `MESI_SHARED;
                snoop_response <= 1;
              end
            end
            `MESI_EXCLUSIVE: begin
              cache_mem[index].mesi_state <= `MESI_SHARED;
              snoop_response <= 1;
            end
            `MESI_SHARED: begin
              if (snoop_write) begin
                cache_mem[index].mesi_state <= `MESI_INVALID;
                cache_mem[index].valid <= 0;
                snoop_response <= 1;
              end
            end
            // No action required for `MESI_INVALID` state
          endcase
        end
      end
    end
  end
endmodule
