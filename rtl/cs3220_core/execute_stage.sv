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
	input wire [31:0] rr_pc_inc,
    input wire [0:0] rr_next_is_cont,

    input wire [31:0] decode_pc,

    output wire exec_stall,
    output wire exec_flush,

    output reg [31:0] exec_br_pc,
    output wire exec_ld_pc,

    output wire [3:0] exec_of_reg,
    output wire [31:0] exec_of_val,

    output reg [3:0] exec_rd,
    output reg [31:0] exec_rd_val,

    perf_if perf
);

    localparam shift_pipelining=0;

    reg inferred_halt;

    wire is_eq = rr_rs_val == rr_rt_val;
    wire is_lt = $signed(rr_rs_val) < $signed(rr_rt_val);
    wire is_le = is_eq || is_lt;
    wire is_ne = !is_eq;

    reg do_jump;

    // multi-cycle instruction support
    reg [3:0] curr_inst_delay;
    reg [3:0] inst_delay;
    wire inst_delay_stall;
    reg inst_was_stalling;
    assign inst_delay_stall = inst_was_stalling ? (inst_delay != 0):(curr_inst_delay != 0);


    assign exec_stall = inst_delay_stall || inferred_halt;
    assign exec_flush = exec_ld_pc;

    wire shift_direction;
    assign shift_direction = (rr_altop == `EXTOP_RSHF);
    wire [31:0] shift_result;

`ifndef VERILATOR
    compat_shift#(
        .WIDTH(32),
        .WIDTHDIST(5),
        .TYPE("ARITHMETIC"),
        .PIPELINE(shift_pipelining)
    ) shifter(
        .clock(i_clk),
        .aclr(0),
        .clken(1),
        .data(rr_rs_val),
        .distance(rr_rt_val[4:0]),
        .direction(shift_direction),
        .result(shift_result)
    );
`else
    assign shift_result = shift_direction ? (
        rr_rs_val << rr_rt_val[4:0]
    ) : (
        $signed($signed(rr_rs_val) >>> rr_rt_val[4:0])
    );
`endif

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
        .incr(!exec_stall && (rr_op != 0 || rr_altop != 0)),
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
        if (rr_op == 6'h0) begin
            case (rr_altop)
                `EXTOP_EQ: alu_result = {31'h0, is_eq};
                `EXTOP_LT: alu_result = {31'h0, is_lt};
                `EXTOP_LE: alu_result = {31'h0, is_le};
                `EXTOP_NE: alu_result = {31'h0, is_ne};
                `EXTOP_ADD: alu_result = rr_rs_val+rr_rt_val;
                `EXTOP_AND: alu_result = rr_rs_val & rr_rt_val;
                `EXTOP_OR: alu_result = rr_rs_val | rr_rt_val;
                `EXTOP_XOR: alu_result = rr_rs_val ^ rr_rt_val;
                `EXTOP_SUB: alu_result = rr_rs_val-rr_rt_val;
                `EXTOP_NAND: alu_result = ~(rr_rs_val & rr_rt_val);
                `EXTOP_NOR: alu_result = ~(rr_rs_val | rr_rt_val);
                `EXTOP_NXOR: alu_result = ~(rr_rs_val ^ rr_rt_val);
                `EXTOP_RSHF: alu_result = $signed($signed(rr_rs_val) >>> rr_rt_val[4:0]);
                `EXTOP_LSHF: alu_result = rr_rs_val << rr_rt_val[4:0];
//                `EXTOP_RSHF: alu_result = shift_result;
//                `EXTOP_LSHF: alu_result = shift_result;
                default: alu_result = 32'h0;
            endcase
        end
        else case (rr_op)
            `OPCODE_ADDI: alu_result = rr_rs_val+rr_imm32;
            `OPCODE_ANDI: alu_result = rr_rs_val & rr_imm32;
            `OPCODE_ORI: alu_result = rr_rs_val | rr_imm32;
            `OPCODE_XORI: alu_result = rr_rs_val ^ rr_imm32;
            `OPCODE_JAL: alu_result = rr_pc+4;
            default: alu_result = 32'h0;
        endcase
    end

    // Instruction multi cycle delay does not properly work for branch instructions.
    always @(*) begin
//        if (rr_op == 6'h0) begin
//            case (rr_altop)
//                `EXTOP_RSHF: curr_inst_delay = shift_pipelining;
//                `EXTOP_LSHF: curr_inst_delay = shift_pipelining;
//                default: curr_inst_delay = 0;
//            endcase
//        end
//        else case (rr_op)
//            default: curr_inst_delay = 0;
//        endcase
        curr_inst_delay = rr_altop[4] ? shift_pipelining:0; // BIG HACK. shift alt ops have bit4 set, nobody else does.
    end

    wire is_jump = (
        rr_op == `OPCODE_JAL ||
            rr_op == `OPCODE_BEQ ||
            rr_op == `OPCODE_BLT ||
            rr_op == `OPCODE_BLE ||
            rr_op == `OPCODE_BNE
        );

    reg [31:0] branch_target_pc;

    // Branch Target PC
    always @(*) begin
        case (rr_op)
        `OPCODE_JAL: branch_target_pc = rr_imm32+rr_rs_val;
            default: branch_target_pc = rr_imm32;
        endcase
    end

    always @(*) begin
        case (rr_op)
        `OPCODE_JAL: do_jump = 1;
            `OPCODE_BEQ: do_jump = is_eq;
            `OPCODE_BLT: do_jump = is_lt;
            `OPCODE_BLE: do_jump = is_le;
            `OPCODE_BNE: do_jump = is_ne;
            default: do_jump = 1'bx;
        endcase
    end
    assign exec_ld_pc = is_jump && (do_jump ? (decode_pc != branch_target_pc) : !rr_next_is_cont);
    assign exec_br_pc = do_jump ? branch_target_pc : (rr_pc_inc);
    // Operand Fwd
    assign exec_of_reg = rr_rd;
    assign exec_of_val = alu_result;

    always @(posedge i_clk) begin
        if (i_reset) begin
            exec_rd <= 0;
            exec_rd_val <= 0;
            inst_delay <= 0;
            inst_was_stalling <= 0;
            inferred_halt <= 0;
        end else begin
            // infer a halt if we jump into a forever single instruction loop
            inferred_halt <= inferred_halt || (exec_ld_pc && (rr_pc == exec_br_pc));


            if (inst_delay_stall) begin

                if (inst_was_stalling) begin
                    if (inst_delay > 0)
                        inst_delay <= inst_delay-1;
                end else begin
                    inst_was_stalling <= 1;
                    inst_delay <= curr_inst_delay-1;
                end

            end else begin
                exec_rd <= rr_rd;
                exec_rd_val <= alu_result;
                inst_was_stalling <= 0;
            end
        end
    end

endmodule: execute_stage