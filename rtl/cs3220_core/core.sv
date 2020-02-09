

module core(
    input wire i_clk, i_reset

);

    wire [31:0] pc, inst;

    fetch fetch(
        .i_clk,
        .i_reset,
        .o_pc(pc),
        .o_inst(inst)
    );

endmodule : core
