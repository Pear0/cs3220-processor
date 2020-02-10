module cs3220_syn
(
    input wire i_sys_clk, 
    input wire i_resetn,

    output [5:0][6:0] wire ssegs
);

wire i_clk = i_sys_clk;
wire reset = !i_resetn;



endmodule
