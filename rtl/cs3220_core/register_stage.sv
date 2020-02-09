`default_nettype none

module register_stage(
    input wire i_clk, i_reset,

    // Incoming Pipeline
    input wire [31:0] decode_pc,
    input wire [5:0] decode_op,
    input wire [7:0] decode_altop,
    input wire [3:0] decode_rd, decode_rs, decode_rt,
    input wire [31:0] decode_imm32,

    // Outgoing pipeline
    output reg [31:0] rr_pc,
    output reg [5:0] rr_op,
    output reg [7:0] rr_altop,
    output reg [3:0] rr_rd,
    output wire [31:0] rr_rs_val, rr_rt_val,
    output reg [31:0] rr_imm32,

    output reg rr_stall, rr_flush,
    input wire exec_stall, exec_flush,

    // reg file interface
    output wire dprf_ra, dprf_rb,
    input wire dprf_ra_val, dprf_rb_val
);

    assign dprf_ra = decode_rs;
    assign dprf_rb = decode_rt;

    assign rr_rs_val = exec_flush ? 0 : dprf_ra_val;
    assign rr_rt_val = exec_flush ? 0 : dprf_rb_val;

    assign rr_stall = exec_stall;
    assign rr_flush = exec_flush;

    always @(posedge i_clk) begin
        if (i_reset || exec_flush) begin
            rr_pc <= 0;
            rr_op <= 0;
            rr_altop <= 0;
            rr_rd <= 0;
            rr_imm32 <= 0;
        end
        else if (!exec_stall) begin
            rr_pc <= decode_pc;
            rr_op <= decode_op;
            rr_altop <= decode_altop;
            rr_rd <= decode_rd;
            rr_imm32 <= decode_imm32;
        end
    end

endmodule: register_stage
