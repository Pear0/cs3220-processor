`default_nettype none
`include "opcodes.sv"

module decode_stage
(
    i_clk, i_reset,
    fetch_pc, fetch_inst, fetch_predicted_pc,

    rr_stall, rr_flush,
    decode_stall, decode_flush,

    decode_pc, decode_op, decode_altop,
    decode_rd, decode_rs, decode_rt,
    decode_imm32,
    decode_predicted_pc
);
// =============================
// DECODE OUTPUT
// ============================
/*
    OP, AltOp, Rd, Rs, Rt, Imm32, Pc
*/
input wire i_clk, i_reset;
input wire [31:0] fetch_pc, fetch_inst, fetch_predicted_pc;

input wire rr_stall, rr_flush;
output wire decode_stall, decode_flush;
assign decode_stall = rr_stall;
assign decode_flush = rr_flush;

wire [5:0] i_op = fetch_inst[31:26];
wire [3:0] i_rd = fetch_inst[11:8];
wire [3:0] i_rs = fetch_inst[7:4];
wire [3:0] i_rt = fetch_inst[3:0];
wire [7:0] i_altop = fetch_inst[25:18];
wire [15:0] i_imm16 = fetch_inst[23:8];

output reg [31:0] decode_pc;
output reg [5:0] decode_op;
output reg [7:0] decode_altop;
output reg [3:0] decode_rd, decode_rs, decode_rt;
output reg [31:0] decode_imm32;
output reg [31:0] decode_predicted_pc;

always @(posedge i_clk) begin
    if (i_reset || rr_flush) begin
        decode_pc <= 0;
        decode_op <= 0;
        decode_altop <= 0;
        decode_rd <= 0;
        decode_rs <= 0;
        decode_rt <= 0;
        decode_imm32 <= 0;
        decode_predicted_pc <= 0;
    end 
    else if (!rr_stall) begin
        decode_pc <= fetch_pc;
        decode_op <= i_op;
        decode_altop <= i_altop;
        decode_predicted_pc <= fetch_predicted_pc;
        if (i_op == 6'h0) begin
            decode_rd <= i_rd;
            decode_rs <= i_rs;
            decode_rt <= i_rt;
            decode_imm32 <= 32'h0;
        end
        // BRanches: Rs -> Rs & Rt -> Rt & Rd -> 0
        // Imm -> Branch Target
        else if (
            i_op == `OPCODE_BEQ ||
            i_op == `OPCODE_BLT ||
            i_op == `OPCODE_BLE ||
            i_op == `OPCODE_BNE
        ) begin
            decode_imm32 <= {{14{i_imm16[15]}}, i_imm16, 2'h0} + 4 + fetch_pc;
            decode_rd <= 0;
            decode_rt <= i_rt;
            decode_rs <= i_rs;
        end
        // JAL Imm is 4 x sextImm
        else if (i_op == `OPCODE_JAL) begin
            decode_rd <= i_rt;
            decode_rt <= 0;
            decode_rs <= i_rs;
            decode_imm32 <= {{14{i_imm16[15]}}, i_imm16, 2'h0};
        end
        // i_rt -> decode_rd
        else if (i_op == `OPCODE_LW) begin
            decode_rt <= 0;
            decode_imm32 <= {{16{i_imm16[15]}}, i_imm16};
            decode_rd <= i_rt;
            decode_rs <= i_rs;
        end
        else if (i_op == `OPCODE_SW) begin
            decode_imm32 <= {{16{i_imm16[15]}}, i_imm16};
            decode_rd <= 0;
            decode_rt <= i_rt;
            decode_rs <= i_rs;
        end else begin
        // ALUIs
            decode_rd <= i_rt;
            decode_imm32 <= {{16{i_imm16[15]}}, i_imm16};
            decode_rt <= 0;
            decode_rs <= i_rs;
            decode_altop <= {2'h0, i_op};
        end
    end
end


endmodule : decode_stage
