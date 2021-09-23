// fifo.sv
// Implements delay buffer (fifo)
// On reset all entries are set to 0
// Shift causes fifo to shift out oldest entry to q, shift in d

module fifo
  #(
  parameter DEPTH=8,
  parameter BITS=64
  )
  (
  input clk,rst_n,en,
  input [BITS-1:0] d,
  output [BITS-1:0] q
  );
  // your RTL code here
  logic [BITS-1:0] data [DEPTH - 1: 0];
  integer i;
  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		for (i = 0; i < DEPTH; i++) begin
			data[i] <= 0;
		end
	end
	else if(en) begin
		for (i = 0; i < DEPTH - 1; i++) begin
			data[i] <= data[i+1];
		end
		data[DEPTH-1] <= d;
	end
  end
  
  assign q = data[0];
  
endmodule // fifo
