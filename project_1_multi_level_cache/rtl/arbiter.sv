// arbiter.sv
module arbiter #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_PORTS = 4 // Number of L2 caches interfacing with the arbiter
) (
    input wire clk,
    input wire reset,
    input wire [NUM_PORTS-1:0] read_req,
    input wire [NUM_PORTS-1:0] write_req,
    input wire [ADDR_WIDTH-1:0] address [NUM_PORTS],
    input wire [DATA_WIDTH-1:0] write_data [NUM_PORTS],
    output reg [DATA_WIDTH-1:0] read_data [NUM_PORTS],
    output reg [NUM_PORTS-1:0] ready,
    output reg [ADDR_WIDTH-1:0] mem_address,
    output reg [DATA_WIDTH-1:0] mem_write_data,
    input wire [DATA_WIDTH-1:0] mem_read_data,
    output reg mem_read_req,
    output reg mem_write_req,
    input wire mem_ready
);

    // Internal variables
    reg [NUM_PORTS-1:0] request_granted;
    integer i;

	always_ff @(posedge clk or posedge reset) begin
		 if (reset) begin
			  // Reset logic
			  request_granted <= 0;
			  ready <= 0;
			  mem_read_req <= 0;
			  mem_write_req <= 0;

			  // Initialize read_data and ready arrays to zero
			  for (i = 0; i < NUM_PORTS; i++) begin
					read_data[i] <= {DATA_WIDTH{1'b0}};
					ready[i] <= 1'b0;
			  end
		 end else begin
            // Arbitration logic
            for (i = 0; i < NUM_PORTS; i++) begin
                if (read_req[i] && !request_granted[i]) begin
                    // Grant read access to port i
                    mem_address <= address[i];
                    mem_read_req <= 1;
                    request_granted <= 1 << i; // Only grant to one requester
                    break;
                end else if (write_req[i] && !request_granted[i]) begin
                    // Grant write access to port i
                    mem_address <= address[i];
                    mem_write_data <= write_data[i];
                    mem_write_req <= 1;
                    request_granted <= 1 << i; // Only grant to one requester
                    break;
                end
            end

            // If memory is ready, pass data back to the requester and reset request
            if (mem_ready && mem_read_req) begin
                read_data[request_granted] <= mem_read_data;
                ready[request_granted] <= 1;
                mem_read_req <= 0;
                request_granted <= 0;
            end else if (mem_ready && mem_write_req) begin
                ready[request_granted] <= 1;
                mem_write_req <= 0;
                request_granted <= 0;
            end
        end
    end
endmodule
