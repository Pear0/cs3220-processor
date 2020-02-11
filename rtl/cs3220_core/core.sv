`default_nettype none

module core(
    input wire i_clk, i_reset,

    output wire wb_cyc, wb_stb, wb_we,
    output wire [29:0] wb_addr,
    input wire [31:0] wb_miso,
    output wire [3:0] wb_sel,
    input wire wb_ack, wb_stall, wb_err,
    output wire [31:0] wb_mosi
);

    wire [31:0] mem_req_addr;
    wire mem_req_stb;
    wire [31:0] mem_req_data;
    wire mem_req_valid;

    wire [31:0] fetch_pc, fetch_inst;
    wire exec_ld_pc;
    wire [31:0] exec_br_pc;

    wire [31:0] decode_pc;
    wire [5:0] decode_op;
    wire [7:0] decode_altop;
    wire [3:0] decode_rd, decode_rs, decode_rt;
    wire [31:0] decode_imm32;
    wire decode_stall, decode_flush;

    wire [3:0] fwd_exec_addr, fwd_mem_addr, fwd_a_addr, fwd_b_addr;
    wire [31:0] fwd_exec_val, fwd_mem_val, fwd_a_val, fwd_b_val;

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


    wire mem_stall, mem_flush;

    simple_memory imem(
        .i_clk,
        .i_reset,

        .mem_req_addr,
        .mem_req_stb,
        .mem_req_valid,
        .mem_req_data
    );

    fetch_stage fetch(
        .i_clk,
        .i_reset,
        .fetch_pc,
        .fetch_inst,

        .exec_ld_pc,
        .exec_br_pc,

        .decode_stall,
        .decode_flush,

        .mem_req_addr,
        .mem_req_stb,
        .mem_req_valid,
        .mem_req_data

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

    wire [31:0] exec_rd_val, mem_rd_val, wr_data;
    wire [3:0] exec_rd, mem_rd, wr_addr;

    assign wr_addr = mem_rd != 0 ? mem_rd:exec_rd;
    assign wr_data = mem_rd != 0 ? mem_rd_val:exec_rd_val;

    assign fwd_b_val = wr_data;
    assign fwd_b_addr = wr_addr;

    tl45_dprf dprf(
        .clk(i_clk),
        .reset(i_reset),

        .readAdd1(dprf_ra),
        .readAdd2(dprf_rb),
        .writeAdd(wr_addr),
        .dataO1(dprf_ra_val),
        .dataO2(dprf_rb_val),
        .dataI(wr_data)
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
        .exec_stall(exec_stall || mem_stall),
        .exec_flush(exec_flush || mem_flush),

        .dprf_ra,
        .dprf_rb,
        .dprf_ra_val,
        .dprf_rb_val,

        .fwd_a_addr,
        .fwd_a_val,
        .fwd_b_addr,
        .fwd_b_val
    );

    assign fwd_a_addr = fwd_mem_addr != 0 ? fwd_mem_addr:fwd_exec_addr;
    assign fwd_a_val = fwd_mem_addr != 0 ? fwd_mem_val:fwd_exec_val;

    execute_stage exec(
        .i_clk,
        .i_reset,

        .rr_pc,
        .rr_op,
        .rr_altop,
        .rr_rd,
        .rr_rs_val,
        .rr_rt_val,
        .rr_imm32,

        .exec_stall,
        .exec_flush,

        .exec_br_pc,
        .exec_ld_pc,

        .exec_of_reg(fwd_exec_addr),
        .exec_of_val(fwd_exec_val),

        .exec_rd,
        .exec_rd_val
    );

    memory_stage mem_stage(
        .i_clk,
        .i_reset,
        .writeback_stall(0),
        .writeback_flush(0),
        .mem_stall,
        .mem_flush,

        .wb_cyc,
        .wb_stb,
        .wb_we,
        .wb_addr,
        .wb_mosi,
        .wb_sel,
        .wb_ack,
        .wb_stall,
        .wb_err,
        .wb_miso,

        .rr_op,
        .rr_altop,
        .rr_rd,
        .rr_rs_val,
        .rr_rt_val,
        .rr_imm32,
        .rr_pc,

        .mem_of_reg(fwd_mem_addr),
        .mem_of_val(fwd_mem_val),

        .mem_rd,
        .mem_rd_val
    );


endmodule: core
