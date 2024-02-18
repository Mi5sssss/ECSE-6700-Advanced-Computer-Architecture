`define MESI_MODIFIED   2'b11
`define MESI_EXCLUSIVE  2'b10
`define MESI_SHARED     2'b01
`define MESI_INVALID    2'b00

module l2_cache #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,
  parameter CACHE_SIZE = 4096, // Cache size in bytes
  parameter LINE_SIZE = 4,     // Line size in bytes
  parameter ASSOCIATIVITY = 4  // 4-way set associative
) (
  input wire clk,
  input wire reset,
  // Interface with L1 cache
  input wire l1_read_req,
  input wire l1_write_req,
  input wire [ADDR_WIDTH-1:0] l1_address,
  input wire [DATA_WIDTH-1:0] l1_write_data,
  output reg [DATA_WIDTH-1:0] l1_read_data,
  output reg l1_read_ready,
  output reg l1_write_ready,
  // Interface with shared L3 cache or main memory
  output reg mem_read_req,
  output reg mem_write_req,
  output reg [ADDR_WIDTH-1:0] mem_address,
  output reg [DATA_WIDTH-1:0] mem_write_data,
  input wire [DATA_WIDTH-1:0] mem_read_data,
  input wire mem_read_ready,
  input wire mem_write_ready
);


  // Cache line structure
  typedef struct packed {
    logic valid;
	  logic dirty;
    logic [ADDR_WIDTH-1:0] tag;
    logic [DATA_WIDTH-1:0] data;
    logic [1:0] mesi_state;
  } cache_line_t;

  // Cache memory array
  cache_line_t cache_mem [CACHE_SIZE/LINE_SIZE/ASSOCIATIVITY][ASSOCIATIVITY];

  // Additional variables for LRU implementation
  logic [1:0] lru_bits [CACHE_SIZE/LINE_SIZE/ASSOCIATIVITY][ASSOCIATIVITY];

  // Cache indexing logic
  localparam INDEX_SIZE = $clog2(CACHE_SIZE/LINE_SIZE/ASSOCIATIVITY);
  localparam TAG_SIZE = ADDR_WIDTH - INDEX_SIZE;
  wire [INDEX_SIZE-1:0] index = l1_address[INDEX_SIZE-1:0];
  wire [TAG_SIZE-1:0] tag = l1_address[ADDR_WIDTH-1:INDEX_SIZE];
  
  // Declare int variables used within always_ff at the module level
  int empty_line_index;
  int lru_line_index;
  int line_to_use;
  int line_to_update;
  logic [1:0] max_lru_value;
  int line_to_evict;
  logic [1:0] max_lru;
  
  // Cache operation logic
  always_ff @(posedge clk) begin
    if (reset) begin
      // Reset cache state
      for (int i = 0; i < CACHE_SIZE/LINE_SIZE/ASSOCIATIVITY; i++) begin
        for (int j = 0; j < ASSOCIATIVITY; j++) begin
          cache_mem[i][j].valid <= 0;
          cache_mem[i][j].mesi_state <= `MESI_INVALID;
          cache_mem[i][j].tag <= 0;
          cache_mem[i][j].data <= 0;
          cache_mem[i][j].dirty <= 0;
          lru_bits[i][j] <= 0;
        end
      end
      l1_read_ready <= 0;
      l1_write_ready <= 0;
      mem_read_req <= 0;
      mem_write_req <= 0;
    end else begin
      // Handle requests from L1 cache
      if (l1_read_req || l1_write_req) begin
        // Search for the tag in the set
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
          if (cache_mem[index][i].valid && cache_mem[index][i].tag == tag) begin
            // Cache hit logic
            if (l1_read_req) begin
              // Read hit
              l1_read_data <= cache_mem[index][i].data;
              l1_read_ready <= 1;
            end
            if (l1_write_req) begin
              // Write hit
              cache_mem[index][i].data <= l1_write_data;
              cache_mem[index][i].mesi_state <= `MESI_MODIFIED;
              l1_write_ready <= 1;
            end
            break; // Exit loop on hit
          end
        end
	  end
	end

		// Handle cache miss


  if (l1_write_req && !l1_write_ready) begin
    // Variable to check if we found a matching cache line
    automatic logic found = 0;
    // Search for the tag in the set
    for (int i = 0; i < ASSOCIATIVITY; i++) begin
      if (cache_mem[index][i].valid && cache_mem[index][i].tag == tag) begin
        // Write hit logic
        cache_mem[index][i].data <= l1_write_data;
        cache_mem[index][i].mesi_state <= `MESI_MODIFIED;
        cache_mem[index][i].dirty <= 1; // Mark as dirty
        l1_write_ready <= 1;
        found = 1;
        break; // Exit loop on hit
      end
    end

    // Handle write miss
    if (!found) begin
      // Find a line to evict based on LRU policy or empty line
      max_lru = 0;  
      line_to_evict = -1;  

      for (int i = 0; i < ASSOCIATIVITY; i++) begin
        if (!cache_mem[index][i].valid) begin
          line_to_evict = i;
          break;
			end
		  else if (lru_bits[index][i] > max_lru) begin
          max_lru = lru_bits[index][i];
          line_to_evict = i;
        end
      end

//// Incrementally reintroduce the loop
//for (int i = 0; i < ASSOCIATIVITY; i++) begin
//    line_to_evict = i;  // Initially simple assignment
//    max_lru = lru_bits[index][i];  // Simple assignment
//    // Gradually add back other conditions and logic
//end




      // Evict the selected line if it's dirty
      if (line_to_evict != -1 && cache_mem[index][line_to_evict].dirty) begin
        // Write back the dirty line to L3 cache/main memory
        mem_write_req <= 1;
        mem_write_data <= cache_mem[index][line_to_evict].data;
        mem_address <= {cache_mem[index][line_to_evict].tag, index};
      end

      // Invalidate the evicted line
      cache_mem[index][line_to_evict].valid <= 0;
      cache_mem[index][line_to_evict].dirty <= 0;
      cache_mem[index][line_to_evict].mesi_state <= `MESI_INVALID;

      // Fetch the new line from L3 cache/main memory
      mem_read_req <= 1;
      mem_address <= l1_address;

      // Update LRU bits
      lru_bits[index][line_to_evict] <= 0; // Most recently used
      for (int i = 0; i < ASSOCIATIVITY; i++) begin
        if (i != line_to_evict) begin
          lru_bits[index][i] <= lru_bits[index][i] + 1;
        end
      end
    end
  end

		// Handle L3 cache/main memory responses
		if (mem_read_req && mem_read_ready) begin
		  // Update the cache line with new data from L3 cache/main memory
		  line_to_update = -1;
		  for (int i = 0; i < ASSOCIATIVITY; i++) begin
			 if (!cache_mem[index][i].valid) begin
				line_to_update = i;
				break;
			 end
		  end

		  if (line_to_update != -1) begin
			 cache_mem[index][line_to_update].valid <= 1;
			 cache_mem[index][line_to_update].tag <= tag;
			 cache_mem[index][line_to_update].data <= mem_read_data;
			 cache_mem[index][line_to_update].mesi_state <= `MESI_EXCLUSIVE;
			 l1_read_data <= mem_read_data;
			 l1_read_ready <= 1;
			 mem_read_req <= 0;
		  end
		end

		if (mem_write_req && mem_write_ready) begin
		  // Handle write completion to memory
		  l1_write_ready <= 1;
		  mem_write_req <= 0;
		end
  end

		// Additional logic for replacement policy, write-back, etc.
		// In a real cache, you would have more complex logic for selecting which line
		// to evict (e.g., LRU policy), and handling write-back of dirty lines to memory.


endmodule
