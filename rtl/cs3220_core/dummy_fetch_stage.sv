`default_nettype none

module dummy_fetch_stage(
    input wire i_clk, i_reset,

    output reg [31:0] fetch_pc,
    output reg [31:0] fetch_inst
);

    reg [31:0] pc;
    initial pc = 0;

    reg [31:0] meemory[0:63];

    wire [31:0] fetch_sub;
    assign fetch_sub = fetch_pc - 32'h100;

    always @(*)
        if (fetch_pc >= 32'h100  && fetch_pc < (32'h100 + 64 * 4))
            fetch_inst = meemory[fetch_sub[7:2]];
        else case (fetch_pc)
            default : fetch_inst = 0;
        endcase

    always @(posedge i_clk) begin
        if (i_reset) begin
            pc <= 32'h100;
            fetch_pc <= 0;
        end
        else begin
            fetch_pc <= pc;
            pc <= pc + 4;
        end
    end

endmodule : dummy_fetch_stage

