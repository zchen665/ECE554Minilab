//transpose fifo for matrix B process

module transpose_fifo
  #(
  parameter DEPTH=8,
  parameter BITS=64
  )
  (
  input clk,rst_n,en,wr,
  input [BITS-1:0] row [DEPTH -1:0],
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
  else if(wr) begin
      for (i = 0; i < DEPTH; i++) begin
        data[i] <= row[i];
      end
  end
	else if(en) begin
      for (i = 0; i < DEPTH - 1; i++) begin
        data[i] <= data[i+1];
      end
          data[DEPTH-1] <= 0;
	  end
  end
  
  assign q = data[0];
  
endmodule // fifo
