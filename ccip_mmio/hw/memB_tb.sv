// memB testbench
// Jianping Shen

`include "memAB_tc.svh"

module memB_tb();
localparam BITS_AB=8;
    localparam BITS_C=16;
    localparam DIM=8;
    localparam ROWBITS=$clog2(DIM);
    
    localparam TESTS=10;

    logic clk;
    logic rst_n;
    logic en;
    logic signed [BITS_AB-1: 0] Bin [DIM-1:0];
    wire signed [BITS_AB-1: 0] Bout [DIM-1:0];
    integer mycycle;
    integer errors;


    memB DUT(
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .Bin(Bin),
        .Bout(Bout)
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
        mycycle = 0;
        errors = 0;
        for(int rowcol=0;rowcol<DIM;++rowcol) begin
            Bin[rowcol] = {BITS_AB{1'b0}};
        end


        // Reset
        @(negedge clk) rst_n = 0;
        @(negedge clk) rst_n = 1;

        // Check A has been reset
        @(negedge clk);
        for(int rowcol=0;rowcol<DIM;++rowcol) begin
            if(Bout[rowcol] != 0) begin
                $display("Error! Reset was not conducted properly. Expected: 0, Got: %4d for Row %4d", Bout[rowcol], rowcol);
            end
        end

        for(int test = 0; test < TESTS; ++test) begin
            // instantiate test case
            satc = new();
            en = 0;

            @(posedge clk);
            // Fill Bin
            for(int row; row < DIM; ++row) begin
                @(posedge clk);
                en = 1;
                for(int col; col < DIM; ++col) begin
                    Bin[col] = satc.B[row][col];
                end
            end

            @(posedge clk)
            en = 1;
            satc.dumpB();
            for(int cyc=0;cyc<(DIM*3-2);++cyc) begin
            // test Aout from get_next_A
                @(posedge clk)
                for(int rowcol=0;rowcol<DIM;++rowcol) begin
                    if(Bout[rowcol] != satc.get_next_B(rowcol)) begin
                        errors++;
                        $display("ERROR! Bout[%1d] was not conducted properly at cycle %2d. Expected %4d, get %4d.", rowcol, cyc, satc.get_next_B(rowcol), Bout[rowcol]);
                    end
                end
                if(errors != 0) begin
                    $display("Errors detected! Terminate test!");
                    $stop;
                end
                //@(posedge clk)
                mycycle = satc.next_cycle();
            end
            en = 0;
        end

        $display("Yahoo! All test pass!");
        $stop;
    end

endmodule
