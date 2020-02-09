`default_nettype none

module dummy_fetch_stage(
    input wire i_clk, i_reset,

    output reg [31:0] o_pc,
    output reg [31:0] o_inst
);

    reg [31:0] pc;
    initial pc = 0;

    always @(*)
        case (o_pc)
            default : o_inst = 0;
        endcase

    always @(posedge i_clk) begin
        if (i_reset) begin
            pc <= 32'h100;
            o_pc <= 0;
            o_inst <= 0;
        end
        else begin
            o_pc <= pc;
            pc <= pc + 4;
        end
    end

endmodule

