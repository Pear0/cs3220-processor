`default_nettype none

module core(
    input wire i_clk, i_reset

);

    wire [31:0] fetch_pc, fetch_inst;

    wire [31:0] decode_pc;
    wire [5:0] decode_op;
    wire [7:0] decode_altop;
    wire [3:0] decode_rd, decode_rs, decode_rt;
    wire [31:0] decode_imm32;
    wire decode_stall, decode_flush;

    wire [3:0] fwd_a_addr, fwd_b_addr;
    wire [31:0] fwd_a_val, fwd_b_val;

    wire [31:0] rr_pc;
    wire [5:0] rr_op;
    wire [7:0] rr_altop;
    wire [3:0] rr_rd;
    wire [31:0] rr_rs_val, rr_rt_val;
    wire [31:0] rr_imm32;
    wire rr_stall, rr_flush;

    wire [3:0] dprf_ra, dprf_rb;
    wire [31:0] dprf_ra_val, dprf_rb_val;

    wire exec_stall, exec_flush;


    dummy_fetch_stage fetch(
        .i_clk,
        .i_reset,
        .fetch_pc,
        .fetch_inst
    );

    decode_stage decode(
        .i_clk,
        .i_reset,
        .fetch_pc,
        .fetch_inst,

        .decode_stall,
        .decode_flush,
        .rr_stall,
        .rr_flush,

        .decode_pc,
        .decode_op,
        .decode_altop,
        .decode_rd,
        .decode_rs,
        .decode_rt,
        .decode_imm32
    );

    wire wr_reg;
    wire [31:0] wr_data;
    wire [3:0] wr_addr;

    tl45_dprf dprf(
        .clk(i_clk),
        .reset(i_reset),

        .readAdd1(dprf_ra),
        .readAdd2(dprf_rb),
        .writeAdd(wr_addr),
        .dataO1(dprf_ra_val),
        .dataO2(dprf_rb_val),
        .dataI(wr_data),
        .wrREG(wr_reg)
    );

    register_stage rr(
        .i_clk,
        .i_reset,

        .decode_pc,
        .decode_op,
        .decode_altop,
        .decode_rd,
        .decode_rs,
        .decode_rt,
        .decode_imm32,

        .rr_pc,
        .rr_op,
        .rr_altop,
        .rr_rd,
        .rr_rs_val,
        .rr_rt_val,
        .rr_imm32,

        .rr_stall,
        .rr_flush,
        .exec_stall,
        .exec_flush,

        .dprf_ra,
        .dprf_rb,
        .dprf_ra_val,
        .dprf_rb_val,

        .fwd_a_addr,
        .fwd_a_val,
        .fwd_b_addr,
        .fwd_b_val
    );





endmodule: core
