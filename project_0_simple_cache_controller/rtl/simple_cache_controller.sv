module simple_cache_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter NUM_LINES = 256,
    parameter TAG_WIDTH = 10
) (
    input logic clk,
    input logic reset,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] write_data,
    input logic read,
    input logic write,
    output logic [DATA_WIDTH-1:0] read_data,
    output logic hit,
    output logic miss
);



    typedef struct {
        logic valid;
        logic [TAG_WIDTH-1:0] tag;
        logic [DATA_WIDTH-1:0] data;
    } cache_line_t;
	 
	 

    cache_line_t cache_mem[NUM_LINES];

    // State definitions
    typedef enum {IDLE, READ_HIT, WRITE_HIT, MISS} state_t;
    state_t current_state, next_state;
	 
	function string state_to_string(state_t state);
		 case (state)
			  IDLE: return "IDLE";
			  READ_HIT: return "READ_HIT";
			  WRITE_HIT: return "WRITE_HIT";
			  MISS: return "MISS";
			  default: return "UNKNOWN";
		 endcase
	endfunction

    // Variables for tag and index calculation
    logic [TAG_WIDTH-1:0] tag;
    int index;
	 
    always_comb begin
        tag = addr[ADDR_WIDTH-1:ADDR_WIDTH-TAG_WIDTH];
        index = addr % NUM_LINES;
    end

	 

    // Update cache memory and state transitions in a sequential block
    always_ff @(posedge clk) begin
        if (reset) begin
            // Reset logic
            for (int i = 0; i < NUM_LINES; i++) begin
                cache_mem[i].valid = 0;
            end
            current_state <= IDLE;
        end else begin
            // State transitions based on current state and inputs
            case (current_state)
                IDLE: begin
                    if (read || write) begin
							$display("hello");
                        if (cache_mem[index].valid && (cache_mem[index].tag == tag)) begin
                            // Cache hit
                            next_state = (read) ? READ_HIT : WRITE_HIT;
                        end else begin
                            // Cache miss
                            next_state = MISS;
									 $display("cache miss");
                        end
                    end
                end

                READ_HIT: begin
                    read_data = cache_mem[index].data;
						  $display("Time: %0t, Reading from Cache Line: Index = %0d, Tag = %h, Data = %h", $time, index, tag, read_data);
                    hit = 1;
						  miss = 0;
                    next_state = IDLE;
                end

                WRITE_HIT: begin
                    hit = 1;
						  miss = 0;
                    if (write) begin
                        // Update cache line on write hit
                        cache_mem[index].data = write_data;
								$display("Time: %0t, Writing to Cache Line: Index = %0d, Tag = %h, Data = %h", $time, index, tag, write_data);
                    end
                    next_state = IDLE;
                end

                MISS: begin
                    miss = 1;
						  hit = 0;
						  $display("cache miss, then the write is ", write);
						  read_data = 0;
                    if (write) begin
                        // On a miss, we need to write the data into the cache
                        cache_mem[index].valid = 1;
                        cache_mem[index].tag = tag;
                        cache_mem[index].data = write_data;
								
								$display("Time: %0t, Writing to Cache Line: Index = %0d, Tag = %h, Data = %h", $time, index, tag, write_data);
                    end
                    next_state = IDLE;
                end
            endcase

            // After determining next state, update current state
            current_state <= next_state;
        end

        // Debug display
        $display("Time: %0t, Current State: %s, Next State: %s", $time, state_to_string(current_state), state_to_string(next_state));
		  $display("write signal is ", write);
		  $display("read signal is ", read);
    end



endmodule
