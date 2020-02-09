`timescale 1ns/1ps



module tb_core();
    reg i_clk, i_reset;

    core core(.i_clk, .i_reset);

    `ifdef TRACE
    initial begin
        $dumpfile("test.vcd");
        $dumpvars(0,core);
    end
    `endif

    always #1 i_clk = !i_clk;


    initial begin
        i_clk = 0; i_reset = 1;
        #2;
        i_reset = 0;

        #20;
        $finish();
    end


endmodule : tb_core



