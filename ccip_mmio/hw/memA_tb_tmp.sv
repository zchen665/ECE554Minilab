

module memA_tb_tmp();
  parameter BITS_AB = 8;
  parameter BITS_C = 16;
  parameter DIM = 8;
	// Clock
  logic clk;
  logic rst_n;
  logic en, WrEn;
  logic signed [BITS_AB-1:0] Ain [DIM-1:0];
  logic signed [BITS_AB-1:0] Aout [DIM-1:0];
  logic [$clog2(DIM)-1:0] Arow;
memA DUT(.clk(clk),.rst_n(rst_n),.en(en),.WrEn(WrEn),.Ain(Ain),.Arow(Arow),.Aout(Aout));
  initial begin
    clk = 0;
  end
always #5 clk = ~clk; 

 initial begin
rst_n = 0;
en = 0;
WrEn =0;
@(negedge clk);
rst_n = 1;

for (integer i = 0; i < DIM; i++)begin
	for (integer j = 0; j < DIM; j++)begin
	Ain[j] = $random;
end
WrEn = 1;
Arow = i;
@(negedge clk);
end

en = 1;
WrEn = 0;
for (integer i = 0; i < DIM; i++)begin
@(negedge clk);
end
$stop();
end
endmodule