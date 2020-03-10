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
reg [7:0] btb_index;
initial r_pc = 32'h100;

assign mem_req_addr = r_pc;
assign mem_req_stb = 1'b1;

always @(posedge i_clk) begin
    if (i_reset || decode_flush) begin
        fetch_inst <= 32'h0;
        if (exec_ld_pc) begin
            r_pc <= exec_br_pc;
            btb_index <= exec_br_pc[9:2];
        end else begin
            fetch_pc <= 32'h0;
            r_pc <= 32'h100;
            btb_index <= 8'h0;
        end
    end 
    // Assuming memory always respond immediately
    else if (!decode_stall) begin
        r_pc <= next_pc;
        btb_index <= next_pc[9:2];
        fetch_inst <= mem_req_data;
        fetch_pc <= r_pc;
    end
end

reg [31:0] next_pc;

// btb lol(
//     .i_clk(i_clk), .i_reset(i_reset),
//     .pc(r_pc),

//     .load(exec_ld_pc),
//     .ld_addr(rr_pc), 
//     .ld_target(exec_br_pc),

//     .next_pc(next_pc)
// );

/*
31--------------------------------------------0
| TAG [31:10]                 |INDEX[7:2]|2'b0|
-----------------------------------------------
*/

reg [0:0] valid [256];
reg [21:0] tag      [256];
reg [31:0] target   [256];

reg [21:0] i_tag;

generate
genvar i;
for (i = 0; i < 256; i = i + 1) begin : gen_reset
    initial valid[i] = 0;
end
endgenerate

always @(*) begin
    i_tag = r_pc[31:10];
end

wire [7:0] load_index = rr_pc[9:2];

reg [7:0] reset_cntr;
initial reset_cntr = 0;

always @(posedge i_clk) begin
    if (i_reset) begin
        valid[reset_cntr] <= 0;
        reset_cntr <= reset_cntr + 1;
    end
    else if (exec_ld_pc) begin
        valid[load_index] <= 1'b1;
        tag[load_index] <= rr_pc[31:10];
        target[load_index] <= exec_br_pc;
    end
end

always @(*) begin
if (tag[btb_index] == i_tag && valid[btb_index]) begin
    next_pc = target[btb_index];
end
else begin
    next_pc = r_pc + 4;
end
end


endmodule : fetch_stage

