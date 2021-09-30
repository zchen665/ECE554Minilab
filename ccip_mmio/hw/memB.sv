module memB
  #(
    parameter BITS_AB=8,
    parameter DIM=8
    )
   (
    input                      clk,rst_n,en,
    input signed [BITS_AB-1:0] Bin [DIM-1:0],
    output signed [BITS_AB-1:0] Bout [DIM-1:0]
    );
	
	// logic signed [DIM-1:0] cnt;
	
    // Only for test memB_tb
	genvar i;
	generate
		for(i=0; i<DIM; ++i) begin
			fifo #(DIM+i,BITS_AB) fifo_memB(
				.clk(clk),
				.rst_n(rst_n),
				.en(en),
				.d(Bin[i]),
				.q(Bout[i])
			);
		end
	endgenerate
 	
/*	always @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			cnt <= 0;
		else if(!en)
			cnt <= 0;
		else if (cnt <= DIM)
			cnt <= cnt + 1;
		
	end
*/
/*	
	// parallelogram shift
	always_comb begin
		Bout[0] = Btmp[0];
		for (int k=1; k<DIM; ++k) begin
			Bout[k] = (cnt >= k) ? Btmp[k] : 0; 
		end
	end */
	
endmodule