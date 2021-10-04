// Jianping Shen

module tpuv1 #(
    parameter BITS_AB=8,
    parameter BITS_C=16,
    parameter DIM=8,
    parameter ADDRW=16,
    parameter DATAW=64
)
(
    input                       clk     , 
    input                       rst_n   , 
    input                       r_w     , // r_w=0 read, =1 write
    input           [DATAW-1:0] dataIn  ,
    output  logic   [DATAW-1:0] dataOut ,
    input           [ADDRW-1:0] addr
);

    logic C_WrEn, A_WrEn, B_WrEn, C_load;
    logic cal_en;
    logic signed [4:0] Acnt, Bcnt;
    logic signed [5:0] Ccnt, Mcnt;
    logic signed [BITS_AB-1:0]  Ain [DIM-1:0];
    logic signed [BITS_AB-1:0]  Bin [DIM-1:0];
    logic signed [BITS_AB-1:0]  Aout [DIM-1:0];
    logic signed [BITS_AB-1:0]  Bout [DIM-1:0];
    logic signed [BITS_C-1:0]   Cin [DIM-1:0];
    logic signed [BITS_C-1:0]   Cout [DIM-1:0];
    logic signed [BITS_C-1:0]   Ccache [DIM/2-1:0];
    logic [$clog2(DIM)-1:0]     Crow;
    logic [$clog2(DIM)-1:0]     Arow;

/*
    wire signed [BITS_C-1:0]   Check [DIM-1:0];
    wire signed [BITS_AB-1:0]   ACheck [DIM-1:0];
    wire signed [BITS_AB-1:0]   BCheck [DIM-1:0];
    
    assign ACheck = Aout;
    assign BCheck = Bout;
    assign Check = Cin;
*/
    localparam Abase = 16'h0100;
    localparam Bbase = 16'h0200;
    localparam Cbase = 16'h0300;
    localparam MatMul = 16'h0400;
    // Systolic_array
    systolic_array #(
        BITS_AB,
        BITS_C,
        DIM
    ) SYSARRAY (
        .clk(clk),
        .rst_n(rst_n),
        .WrEn(C_WrEn),
        .en(cal_en),
        .A(Aout),
        .B(Bout),
        .Cin(Cin),
        .Crow(Crow),
        .Cout(Cout)
    );
    
    memA #(
        BITS_AB,
        DIM
    ) MEMA (
        .clk(clk),
        .rst_n(rst_n),
        .en(cal_en),
        .WrEn(A_WrEn),
        .Ain(Ain),
        .Arow(Arow),
        .Aout(Aout)
    );

    memB #(
        BITS_AB,
        DIM
    ) MEMB (
        .clk(clk),
        .rst_n(rst_n),
        .en(cal_en | B_WrEn),
        .Bin(Bin),
        .Bout(Bout)
    );

    typedef enum logic { 
        IDLE,
        MUL
    } state_t;
    
    state_t state, nxt_state;

    // State machine
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) state <= IDLE;
        else state <= nxt_state;
    end

    // Counter
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            Acnt <= 0;
            Bcnt <= 0;
            Ccnt <= 0;
            Mcnt <= 0;
        end
        else if(A_WrEn) Acnt = Acnt + 1;
        else if(B_WrEn) Bcnt = Bcnt + 1;
        else if(C_WrEn | C_load) Ccnt = Ccnt + 1;
        else if(cal_en) begin
            Acnt <= 0;
            Bcnt <= 0;
            Ccnt <= 0;
            Mcnt <= Mcnt + 1;
        end
        else Mcnt <= 0;
    end


    // C load buffer
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            for(integer i = 0; i<DIM/2; i++) Ccache[i] <= 0;
        end
        else if(C_load) begin
            for(integer i = 0; i<DIM/2; i++) Ccache[i] <= dataIn[(BITS_C*i) +: BITS_C];
        end
    end




    genvar i;
    generate
        for(i = 0; i<DIM; ++i) begin
            assign Ain[i] = A_WrEn? dataIn[BITS_AB*i+7:BITS_AB*i]: 0;
            assign Bin[i] = B_WrEn? dataIn[BITS_AB*i+7:BITS_AB*i]: 0;
        end

        for(i = 0; i<DIM/2; ++i) begin
            // assign Ccache[i+4] = dataIn[(16*i) +: 16];
            assign Cin[i] = C_WrEn? Ccache[i]: 0;
            assign Cin[i+4] = C_WrEn? dataIn[(BITS_C*i) +: BITS_C]: 0;
            assign dataOut[(BITS_C*i) +: BITS_C] = addr[3]? Cout[i+4]: Cout[i];
        end
    endgenerate

    assign Arow = Acnt;
    assign Crow = r_w? Ccnt[3:1]: addr[7:4];

    // SM combinational logic
    always_comb begin
        cal_en = 0;
        A_WrEn = 0;
        B_WrEn = 0;
        C_WrEn = 0;
        C_load = 0;
        nxt_state = state;
        case(state)
            IDLE: begin
                if (addr == MatMul) nxt_state = MUL;
                else if(r_w) begin
                    if(addr == Abase + 8*Acnt) A_WrEn = 1;
                    else if(addr == Bbase + 8*Bcnt) B_WrEn = 1;
                    else if(addr == Cbase + 8*Ccnt) begin
                        if(Ccnt[0]) C_WrEn = 1;
                        else C_load = 1;
                    end
                end
            end
            MUL: begin
                if(Mcnt < 3*DIM - 2) cal_en = 1;
                else nxt_state = IDLE;
            end
        endcase
    end
endmodule

