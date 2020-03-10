`default_nettype none

module fetch_stage(
    input wire i_clk, i_reset,

    output reg [31:0] fetch_pc,
    output reg [31:0] fetch_inst,

    input wire [31:0] rr_pc,
    input wire exec_ld_pc,
    input wire [31:0] exec_br_pc,

    input wire decode_flush,
    input wire decode_stall,

    // memory interface
    output wire [31:0] mem_req_addr,
    output wire mem_req_stb,
    input wire [31:0] mem_req_data,
    input wire mem_req_valid
);

reg [31:0] r_pc;
initial r_pc = 32'h100;

assign mem_req_addr = r_pc;
assign mem_req_stb = 1'b1;

always @(posedge i_clk) begin
    if (i_reset || decode_flush) begin
        fetch_inst <= 32'h0;
        if (exec_ld_pc) begin
            r_pc <= exec_br_pc;
        end else begin
            fetch_pc <= 32'h0;
            r_pc <= 32'h100;
        end
    end 
    // Assuming memory always respond immediately
    else if (!decode_stall) begin
        r_pc <= next_pc;
        fetch_inst <= mem_req_data;
        fetch_pc <= r_pc;
    end
end

wire [31:0] next_pc;

btb lol(
    .i_clk(i_clk), .i_reset(i_reset),
    .pc(r_pc),

    .load(exec_ld_pc),
    .ld_addr(rr_pc), 
    .ld_target(exec_br_pc),

    .next_pc(next_pc)
);


endmodule : fetch_stage

