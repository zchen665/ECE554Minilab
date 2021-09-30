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
    integer counter;
    logic signed [BITS_AB-1:0] Atmp [DIM-1:0];
   genvar i;
   generate
     for (i = 1; i < DIM; ++i) begin
       transpose_fifo #(DIM,BITS_AB) T_FIFO(
         .clk(clk),
         .rst_n(rst_n),
         .en(en & counter >= i), // maybe add !WrEn
         .wr(WrEn & Arow == i), //select one row to update
         .row(Ain),
         .q(Atmp[i])
       );
     end
     transpose_fifo #(DIM,BITS_AB) T_FIFO(
         .clk(clk),
         .rst_n(rst_n),
         .en(en), // maybe add !WrEn
         .wr(WrEn & Arow == 0), //select one row to update
         .row(Ain),
         .q(Atmp[0])
       );
   endgenerate

   always@(posedge clk, negedge rst_n) begin
     if (!rst_n) begin
       counter <= 0;
     end
     else if (WrEn) begin
       counter <=0;
     end
     else if (en) begin
       counter <= counter + 1;
     end
   end

   always_comb begin
     Aout[0] = Atmp[0];
     for (integer j = 1; j < DIM; j++) begin
       Aout[j] = counter >= j? Atmp[j]:0;
     end
   end
   endmodule