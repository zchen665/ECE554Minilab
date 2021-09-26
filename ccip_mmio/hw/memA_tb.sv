// Testbench for memA
// Jianping Shen

`include "memAB_tc.svh"

module memA_tb();
    localparam BITS_AB=8;
    localparam BITS_C=16;
    localparam DIM=8;
    localparam ROWBITS=$clog2(DIM);
    
    localparam TESTS=10;

    logic clk;
    logic rst_n;
    logic en;
    logic WrEn;
    logic signed [BITS_AB-1: 0] Ain [DIM-1:0];
    logic [ROWBITS-1: 0] Arow;
    wire signed [BITS_AB-1: 0] Aout [DIM-1:0];
    integer mycycle;
    integer errors;


    memA DUT(
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .WrEn(WrEn),
        .Ain(Ain),
        .Arow(Arow),
        .Aout(Aout)
    );

    memAB_tc #(
        .BITS_AB(BITS_AB),
        .BITS_C(BITS_C),
        .DIM(DIM)
    ) satc;

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 1;
        en = 0;
        WrEn = 0;
        Arow = 0;
        mycycle = 0;
        errors = 0;
        for(int rowcol=0;rowcol<DIM;++rowcol) begin
            Ain[rowcol] = {BITS_AB{1'b0}};
        end


        // Reset
        @(negedge clk) rst_n = 0;
        @(negedge clk) rst_n = 1;

        // Check A has been reset
        @(negedge clk)
        for(int rowcol=0;rowcol<DIM;++rowcol) begin
            if(Aout[rowcol] != 0) begin
                $display("Error! Reset was not conducted properly. Expected: 0, Got: %4d for Row %4d", Aout[rowcol], rowcol);
            end
        end

        for(int test = 0; test < TESTS; ++test) begin
            // instantiate test case
            satc = new();

            @(posedge clk)
            // Fill Ain
            for(int row; row < DIM; ++row) begin
                @(posedge clk)
                WrEn = 1;
                Arow = row;
                for(int col; col < DIM; ++col) begin
                    Ain[col] = satc.A[row][col];
                end
            end

            @(posedge clk)
            WrEn = 0;
            @(posedge clk)
            en = 1;
            satc.dumpA();
            for(int cyc=0;cyc<(DIM*3-2);++cyc) begin
            // test Aout from get_next_A
                for(int rowcol=0;rowcol<DIM;++rowcol) begin
                    if(Aout[rowcol] != satc.get_next_A(rowcol)) begin
                        errors++;
                        $display("ERROR! Aout[%1d] was not conducted properly at cycle %2d. Expected %4d, get %4d.", rowcol, cyc, satc.get_next_A(rowcol), Aout[rowcol]);
                    end
                end
                if(errors != 0) begin
                    $display("Errors detected! Terminate test!");
                    $stop;
                end
                @(posedge clk)
                mycycle = satc.next_cycle();
            end
        end

        $display("Yahoo! All test pass!");
        $stop;
    end


endmodule