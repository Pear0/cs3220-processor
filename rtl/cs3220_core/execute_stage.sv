`default_nettype none
`include "opcodes.sv"

/*
 * Major changes to this module include pipelining the module to take 2 cycles per instruction
 * and support two instructions in-flight at one time (as long as they do not have a data
 * dependency). This helps improve timing because it is difficult to pass 130 MHz on a Cyclone V
 * when a 32 bit barrel shift must be done in one cycle.
 *
 * This module makes heavy use of my compat_* modules that abstract explicit Altera IP
 * instantiations behind vendor detection and fallback implementations (that may still be
 * inferrable) for Verilator and other vendors.
 */


module execute_stage(
    input wire i_clk, i_reset,

    input wire [31:0] rr_pc,
    input wire [5:0] rr_op,
    input wire [7:0] rr_altop,
    input wire [3:0] rr_altaluop,
    input wire [3:0] rr_rd,
    input wire [3:0] rr_rs, rr_rt,
    input wire [31:0] rr_rs_val, rr_rt_val,
    input wire [31:0] rr_imm32,
	input wire [31:0] rr_pc_inc,
    input wire [0:0] rr_next_is_cont,
    input wire [31:0] rr_predicted_pc,

    output wire exec_stall,
    output wire exec_flush,

    output reg [31:0] exec_br_pc,
    output reg [31:0] exec_br_origin,
    output reg exec_ld_pc,

    output wire [3:0] exec_of_reg,
    output wire [31:0] exec_of_val,

    output reg [3:0] exec_rd,
    output reg [31:0] exec_rd_val,



    perf_if perf
);

    localparam internal_pipeline=1;
    localparam internal_pipeline_shift=1;

    reg inferred_halt;
    wire is_eq, is_lt, is_le, is_ne, is_gt, is_gte;

    compat_compare #(
        .WIDTH(32),
        .PIPELINE(internal_pipeline)
    ) cmp (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .dataa(rr_rs_val),
        .datab(rr_rt_val),
        .aeb(is_eq),
        .alb(is_lt),
        .aleb(is_le),
        .aneb(is_ne),
        .agb(is_gt),
        .ageb(is_gte)
    );

    reg do_jump;

    wire pipeline_stall = 0; //(out_rd != 0 && ((out_rd == rr_rs) || (out_rd == rr_rt)));

    assign exec_stall = inferred_halt || pipeline_stall;
    assign exec_flush = exec_ld_pc;

    // 1 == RSHF
    wire shift_direction;
    assign shift_direction = ~rr_altop[0];
    wire [31:0] shift_result;
    wire [31:0] add_result;
    wire [31:0] add_imm_result;
    wire [31:0] sub_result;

    wire [31:0] and_result;
    wire [31:0] or_result;
    wire [31:0] xor_result;

    wire [31:0] and_imm_result;
    wire [31:0] or_imm_result;
    wire [31:0] xor_imm_result;

    compat_shift#(
        .WIDTH(32),
        .WIDTHDIST(5),
        .TYPE("ARITHMETIC"),
        .PIPELINE(internal_pipeline_shift)
    ) shifter(
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .data(rr_rs_val),
        .distance(rr_rt_val[4:0]),
        .direction(shift_direction),
        .result(shift_result)
    );

    compat_add #(
        .WIDTH(32),
        .PIPELINE(internal_pipeline)
    ) add (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .dataa(rr_rs_val),
        .datab(rr_rt_val),
        .result(add_result)
    );

    compat_add #(
        .WIDTH(32),
        .PIPELINE(internal_pipeline)
    ) add_imm (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .dataa(rr_rs_val),
        .datab(rr_imm32),
        .result(add_imm_result)
    );

    compat_sub #(
        .WIDTH(32),
        .PIPELINE(internal_pipeline)
    ) sub (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .dataa(rr_rs_val),
        .datab(rr_rt_val),
        .result(sub_result)
    );

    compat_bitwise #(
        .WIDTH(32),
        .PIPELINE(internal_pipeline)
    ) bitwise (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .dataa(rr_rs_val),
        .datab(rr_rt_val),
        .result_and(and_result),
        .result_or(or_result),
        .result_xor(xor_result)
    );

    compat_bitwise #(
        .WIDTH(32),
        .PIPELINE(internal_pipeline)
    ) bitwise_imm (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .dataa(rr_rs_val),
        .datab(rr_imm32),
        .result_and(and_imm_result),
        .result_or(or_imm_result),
        .result_xor(xor_imm_result)
    );

    wire [31:0] out_pc;
    compat_delay #(
        .WIDTH(32),
        .PIPELINE(internal_pipeline)
    ) pc_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .in(rr_pc),
        .out(out_pc)
    );

    wire [31:0] out_pc_inc;
    compat_delay #(
        .WIDTH(32),
        .PIPELINE(internal_pipeline)
    ) pc_inc_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .in(rr_pc_inc),
        .out(out_pc_inc)
    );

    wire [3:0] out_rd;
    compat_delay #(
        .WIDTH(4),
        .PIPELINE(internal_pipeline)
    ) rd_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .in((exec_flush || pipeline_stall) ? 0 : rr_rd),
        .out(out_rd)
    );

    wire [5:0] out_op;
    compat_delay #(
        .WIDTH(6),
        .PIPELINE(internal_pipeline)
    ) op_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .in(exec_flush ? 0 : rr_op),
        .out(out_op)
    );

    wire [7:0] out_altop;
    compat_delay #(
        .WIDTH(8),
        .PIPELINE(internal_pipeline)
    ) altop_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .in(exec_flush ? 0 : rr_altop),
        .out(out_altop)
    );

    wire [31:0] out_imm32;
    compat_delay #(
        .WIDTH(32),
        .PIPELINE(internal_pipeline)
    ) imm32_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .in(rr_imm32),
        .out(out_imm32)
    );

    wire out_next_is_cont;
    compat_delay #(
        .WIDTH(1),
        .PIPELINE(internal_pipeline)
    ) next_is_cont_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .in(rr_next_is_cont),
        .out(out_next_is_cont)
    );

    wire [31:0] out_predicted_pc;
    compat_delay #(
        .WIDTH(32),
        .PIPELINE(internal_pipeline)
    ) predicted_pc_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .in(rr_predicted_pc),
        .out(out_predicted_pc)
    );

    wire out_op_jal;
    compat_const_eq #(
        .WIDTH(6),
        .PIPELINE(internal_pipeline)
    ) out_op_jal_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .dataa(rr_op),
        .datab(`OPCODE_JAL),
        .aeb(out_op_jal)
    );

    wire out_op_zero;
    compat_const_eq #(
        .WIDTH(6),
        .PIPELINE(internal_pipeline)
    ) out_op_zero_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .dataa(rr_op),
        .datab(0),
        .aeb(out_op_zero)
    );

    wire [3:0] out_altaluop;
    compat_delay #(
        .WIDTH(4),
        .PIPELINE(internal_pipeline)
    ) altaluop_delay (
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .in(rr_altaluop),
        .out(out_altaluop)
    );

    perf_if inst_count();
    perf_if cycle_count();

    perf_mux2 perf_mux(
        .a(inst_count),
        .b(cycle_count),
        .out(perf)
    );

    perf_counter64#(
        .ADDR(8'h02)
    )inst_counter(
        .i_clk,
        .i_reset,
        .incr(!exec_stall && (out_op != 0 || out_altop != 0)),
        .perf(inst_count)
    );

    perf_counter64#(
        .ADDR(8'h04)
    )cycle_counter(
        .i_clk,
        .i_reset,
        .incr(!inferred_halt),
        .perf(cycle_count)
    );

    reg [31:0] alu_result;
    always @(*) begin
        if (out_rd == 0)
            alu_result = 0;
        else if (out_op_zero) begin

            case (out_altaluop)
                `ALUOP_EQ: alu_result = {31'h0, is_eq};
                `ALUOP_LT: alu_result = {31'h0, is_lt};
                `ALUOP_LE: alu_result = {31'h0, is_le};
                `ALUOP_NE: alu_result = {31'h0, is_ne};
                `ALUOP_ADD: alu_result = add_result;
                `ALUOP_AND: alu_result = and_result;
                `ALUOP_OR: alu_result = or_result;
                `ALUOP_XOR: alu_result = xor_result;
                `ALUOP_SUB: alu_result = sub_result;
                `ALUOP_NAND: alu_result = ~and_result;
                `ALUOP_NOR: alu_result = ~or_result;
                `ALUOP_NXOR: alu_result = ~xor_result;
                `ALUOP_LSHF: alu_result = shift_result;
                `ALUOP_RSHF: alu_result = shift_result;
                default: alu_result = 32'h0;
            endcase
        end
        else case (out_op)
            `OPCODE_ADDI: alu_result = add_imm_result;
            `OPCODE_ANDI: alu_result = and_imm_result;
            `OPCODE_ORI: alu_result = or_imm_result;
            `OPCODE_XORI: alu_result = xor_imm_result;
            `OPCODE_JAL: alu_result = out_pc_inc;
            default: alu_result = 32'h0;
        endcase
    end

    wire is_jump = (out_op[5:3] == 3'b001);

    reg [31:0] branch_target_pc;
    // Branch Target PC
//    always @(*) begin
//        case (out_op)
//        `OPCODE_JAL: branch_target_pc = add_imm_result;
//            default: branch_target_pc = out_imm32;
//        endcase
//    end
    assign branch_target_pc = out_op_jal ? add_imm_result : out_imm32;

    always @(*) begin
        case (out_op)
        `OPCODE_JAL: do_jump = 1;
            `OPCODE_BEQ: do_jump = is_eq;
            `OPCODE_BLT: do_jump = is_lt;
            `OPCODE_BLE: do_jump = is_le;
            `OPCODE_BNE: do_jump = is_ne;
            default: do_jump = 1'b0;
        endcase
    end
//    assign exec_ld_pc = is_jump && (do_jump ? (out_predicted_pc != branch_target_pc) : !out_next_is_cont);
//    assign exec_br_pc = do_jump ? branch_target_pc : (out_pc_inc);
//    assign exec_br_origin = out_pc;
    // Operand Fwd
    assign exec_of_reg = out_rd;
    assign exec_of_val = alu_result;

    // Determine an inferred halt one cycle too late to optimize timing.
    reg ih_exec_ld_pc;
    reg [31:0] ih_pc;
    reg [31:0] ih_br_pc;
    wire should_infer_halt;
    assign should_infer_halt = ih_exec_ld_pc && (ih_pc == ih_br_pc);

    reg [5:0] flush_count;

    always @(posedge i_clk) begin
        if (i_reset || flush_count[0]) begin
            exec_rd <= 0;
            exec_rd_val <= 0;
            exec_ld_pc <= 0;
            exec_br_pc <= 0;
            exec_br_origin <= 0;
            ih_exec_ld_pc <= 0;
            ih_pc <= 0;
            ih_br_pc <= 0;
            if (i_reset) begin
                inferred_halt <= 0;
                flush_count <= 0;
            end

            if (flush_count[0])
                flush_count <= (flush_count >> 1);
        end
        else if (!inferred_halt) begin
            // infer a halt if we jump into a forever single instruction loop

            exec_ld_pc <= is_jump && (do_jump ? (out_predicted_pc != branch_target_pc) : !out_next_is_cont);
            exec_br_pc <= do_jump ? branch_target_pc : (out_pc_inc);
            exec_br_origin <= out_pc;

            if (is_jump && (do_jump ? (out_predicted_pc != branch_target_pc) : !out_next_is_cont))
                flush_count <= 6'b11;
            else
                flush_count <= (flush_count >> 1);

            // TODO mve this to same cycle
            ih_exec_ld_pc <= exec_ld_pc;
            ih_pc <= out_pc;
            ih_br_pc <= exec_br_pc;
            // next cycle
            inferred_halt <= should_infer_halt;

//            if (out_op != `OPCODE_LW && out_op != `OPCODE_LW)
            if (~out_op[4])
                exec_rd <= out_rd;
            else
                exec_rd <= 0;

            exec_rd_val <= alu_result;
        end
    end

endmodule: execute_stage