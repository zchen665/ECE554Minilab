/*
* Module systolic_array
* Engineer: Jianping Shen
*/

module systolic_array
#(
    parameter BITS_AB=8,
    parameter BITS_C=16,
    parameter DIM=8
)
(
    input                      clk,rst_n,WrEn,en,
    input signed [BITS_AB-1:0] A [DIM-1:0],
    input signed [BITS_AB-1:0] B [DIM-1:0],
    input signed [BITS_C-1:0]  Cin [DIM-1:0],
    input [$clog2(DIM)-1:0]    Crow,
    output logic signed [BITS_C-1:0] Cout [DIM-1:0]
);
    logic signed [BITS_AB-1:0] Aval [DIM-1:0][DIM-1:0];
    logic signed [BITS_AB-1:0] Bval [DIM-1:0][DIM-1:0];
    logic signed [BITS_C-1:0] Cval [DIM-1:0][DIM-1:0];
    logic [DIM-1:0] WrEnRow;


    genvar i, j;
    generate
    for (i = 0; i < DIM; ++i) begin
        for (j = 0; j < DIM; ++j) begin
            tpumac #(BITS_AB,BITS_C) TPUMAC(
                .clk(clk),
		        .rst_n(rst_n),
		        .WrEn(WrEnRow[i]),
		        .en(en),
		        .Ain(Aval[i][j]),
		        .Bin(Bval[i][j]),
		        .Cin(Cin[j]),
		        .Aout(Aval[i][j+1]),
		        .Bout(Bval[i+1][j]),
		        .Cout(Cval[i][j])
            );
        end
    end
    endgenerate

    integer k;

    always_comb begin
        WrEnRow = 0;
        WrEnRow[Crow] = WrEn;
        for (k = 0; k < DIM; ++k) begin
            Aval[k][0] = A[k];
            Bval[0][k] = B[k];
            Cout[k] = Cval[Crow][k];
        end
    end

endmodule
