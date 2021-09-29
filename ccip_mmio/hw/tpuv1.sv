// Jianping Shen

module tpuv1 #(
    parameter BITS_AB=8,
    parameter BITS_C=16,
    parameter DIM=8,
    parameter ADDRW=16;
    parameter DATAW=64;
)
(
    input               clk     , 
    input               rst_n   , 
    input               r_w     , // r_w=0 read, =1 write
    input   [DATAW-1:0] dataIn  ,
    output  [DATAW-1:0] dataOut ,
    input   [ADDRW-1:0] addr
);

    logic C_WrEn;
    logic cal_en;
    logic [BITS_AB-1:0]     Aout [DIM-1:0];
    logic [BITS_AB-1:0]     Bout [DIM-1:0];
    logic [BITS_C-1:0]      Cin [DIM-1:0];
    logic [$clog2(DIM)-1:0] Crow;
    
    // Systolic_array
    systolic_array #(
        BITS_AB=8,
        BITS_C=16,
        DIM=8
    )
    (
        clk(clk),
        rst_n(rst_n),
        WrEn(C_WrEn),
        en(cal_en),
        A(Aout),
        B(Bout),
        Cin(),
        Crow(),
        Cout()
    );
    