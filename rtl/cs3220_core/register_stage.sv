`default_nettype none

module register_stage(
    input wire i_clk, i_reset,

    // Incoming Pipeline
    input wire [31:0] decode_pc,
    input wire [5:0] decode_op,
    input wire [7:0] decode_altop,
    input wire [3:0] decode_rd, decode_rs, decode_rt,
    input wire [31:0] decode_imm32,
    input wire [31:0] fetch_pc,

    // Outgoing pipeline
    output reg [31:0] rr_pc,
	output reg [31:0] rr_pc_inc,
    output reg [5:0] rr_op,
    output reg [7:0] rr_altop,
    output reg [3:0] rr_rd,
    output reg [31:0] rr_rs_val, rr_rt_val,
    output reg [31:0] rr_imm32,
    output reg [0:0] rr_next_is_cont,

    output reg rr_stall, rr_flush,
    input wire exec_stall, exec_flush,

    // reg file interface
    output wire [3:0] dprf_ra, dprf_rb,
    input wire [31:0] dprf_ra_val, dprf_rb_val,

    // Forwarding. fwd_a overrules fwd_b
    input wire [3:0] fwd_a_addr, fwd_b_addr,
    input wire [31:0] fwd_a_val, fwd_b_val
);

    assign dprf_ra = decode_rs;
    assign dprf_rb = decode_rt;

    assign rr_stall = exec_stall;
    assign rr_flush = exec_flush;

    always @(posedge i_clk) begin
        if (i_reset || exec_flush) begin
            rr_pc <= 0;
            rr_op <= 0;
            rr_altop <= 0;
            rr_rd <= 0;
            rr_imm32 <= 0;
            rr_rs_val <= 0;
            rr_rt_val <= 0;
            rr_pc_inc <= 0;
        end
        else if (!exec_stall) begin
            rr_pc_inc <= decode_pc + 4;
            rr_next_is_cont <= (decode_pc + 4 == fetch_pc); // No reset, because there is no point
            rr_pc <= decode_pc;
            rr_op <= decode_op;
            rr_altop <= decode_altop;
            rr_rd <= decode_rd;
            rr_imm32 <= decode_imm32;

            if (decode_rs == fwd_a_addr)
                rr_rs_val <= fwd_a_val;
            else if (decode_rs == fwd_b_addr)
                rr_rs_val <= fwd_b_val;
            else
                rr_rs_val <= dprf_ra_val;

            if (decode_rt == fwd_a_addr)
                rr_rt_val <= fwd_a_val;
            else if (decode_rt == fwd_b_addr)
                rr_rt_val <= fwd_b_val;
            else
                rr_rt_val <= dprf_rb_val;
        end
    end

endmodule: register_stage
