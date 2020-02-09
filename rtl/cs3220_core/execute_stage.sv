`default_nettype none
`include "opcodes.sv"

module execute_stage(
    input wire i_clk, i_reset,

    input wire [31:0] rr_pc,
    input wire [5:0] rr_op,
    input wire [7:0] rr_altop,
    input wire [3:0] rr_rd,
    input wire [31:0] rr_rs_val, rr_rt_val,
    input wire [31:0] rr_imm32,

    output wire exec_stall,
    output wire exec_flush,

    output reg [31:0] exec_br_pc,
    output wire exec_ld_pc,

    output wire [3:0] exec_of_reg,
    output wire [31:0] exec_of_val,

    output reg [3:0] exec_rd,
    output reg [31:0] exec_rd_val
);

wire is_eq = rr_rs_val == rr_rt_val;
wire is_lt = rr_rs_val < rr_rt_val;
wire is_le = is_eq || is_lt;
wire is_ne = !is_eq;

assign exec_stall = 0;
assign exec_flush = do_jump;

reg [31:0] alu_result;

always @(*) begin
    if (rr_op == 6'h0) begin
        case (rr_altop)
             `EXTOP_EQ: alu_result = {31'h0, is_eq};
             `EXTOP_LT: alu_result = {31'h0, is_lt};
             `EXTOP_LE: alu_result = {31'h0, is_le};
             `EXTOP_NE: alu_result = {31'h0, is_ne};
             `EXTOP_ADD: alu_result = rr_rs_val + rr_rt_val; 
             `EXTOP_AND: alu_result = rr_rs_val & rr_rt_val;
             `EXTOP_OR : alu_result = rr_rs_val | rr_rt_val;
             `EXTOP_XOR: alu_result = rr_rs_val ^ rr_rt_val;
             `EXTOP_SUB: alu_result = rr_rs_val - rr_rt_val;
             `EXTOP_NAND: alu_result = ~(rr_rs_val & rr_rt_val);
             `EXTOP_NOR: alu_result = ~(rr_rs_val | rr_rt_val);
             `EXTOP_NXOR: alu_result = ~(rr_rs_val ^ rr_rt_val);
             `EXTOP_RSH: alu_result = $signed($signed(rr_rs_val) >>> rr_rt_val[4:0]);
             `EXTOP_LSH: alu_result = rr_rs_val << rr_rt_val[4:0];
             default: alu_result = 32'0;
        endcase
    end
    else case (rr_op)
        `OPCODE_ADDI: alu_result = rr_rs_val + rr_imm32;
        `OPCODE_ANDI: alu_result = rr_rs_val & rr_imm32; 
        `OPCODE_ORI: alu_result = rr_rs_val | rr_imm32;
        `OPCODE_XORI: alu_result = rr_rs_val ^ rr_imm32;
        `OPCODE_JAL: alu_result = rr_pc + 4;
        default: alu_result = 32'h0;
    endcase
end

wire is_jump = (
    rr_op == `OPCODE_JAL ||
    rr_op == `OPCODE_BEQ ||
    rr_op == `OPCODE_BLT ||
    rr_op == `OPCODE_BLE ||
    rr_op == `OPCODE_BNE 
);

// Branch Target PC
always @(*) begin
    case (rr_op)
        `OPCODE_JAL: exec_br_pc = rr_imm32 + rr_rs_val;
        default: exec_br_pc = rr_imm32;
    endcase
end

reg do_jump;
always @(*) begin
    case (rr_op)
        `OPCODE_JAL: do_jump = 1;
        `OPCODE_BEQ: do_jump = is_eq;
        `OPCODE_BLT: do_jump = is_lt;
        `OPCODE_BLE: do_jump = is_le;
        `OPCODE_BNE: do_jump = is_ne;
        default: do_jump = 0;
    endcase
end
assign exec_ld_pc = do_jump;

// Operand Fwd
assign exec_of_reg = rr_rd;
assign exec_of_val = alu_result;

always @(posedge i_clk) begin
    if (i_reset) begin
        exec_rd <= 0;
        exec_rd_val <= 0;
    end else begin
        exec_rd <= rr_rd;
        exec_rd_val <= alu_result;
    end
end

endmodule : execute_stage