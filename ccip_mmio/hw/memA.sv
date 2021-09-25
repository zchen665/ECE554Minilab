module memA
  #(
    parameter BITS_AB=8,
    parameter DIM=8
    )
   (
    input                      clk,rst_n,en,WrEn,
    input signed [BITS_AB-1:0] Ain [DIM-1:0],
    input [$clog2(DIM)-1:0] Arow,
    output logic signed [BITS_AB-1:0] Aout [DIM-1:0]
   );

   genvar i;
   generate
     for (i = 0; i < DIM; ++i) begin
       transpose_fifo #(DIM,BITS_AB) T_FIFO(
         .clk(clk),
         .rst_n(rst_n),
         .en(en),
         .wr(WrEn & Arow == i), //select one row to update
         .row(Ain),
         .q(Aout[i])
       );
     end
   endgenerate
   endmodule