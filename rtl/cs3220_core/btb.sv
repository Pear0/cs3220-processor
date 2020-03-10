module btb(
    input i_clk, i_reset,
    input [31:0] pc,

    input load,
    input [31:0] ld_addr, ld_target,

    output reg [31:0] next_pc
);

/*
31--------------------------------------------0
| TAG [31:8]                     | INDEX[7:0] |
-----------------------------------------------
*/

reg [255:0] valid;
reg [23:0] tag      [256];
reg [31:0] target   [256];

reg [23:0] i_tag;
reg [7:0]  index;


initial begin
    valid = 0;
end

always @(*) begin
    i_tag = pc[31:8];
    index = pc[7:0];
end

wire [7:0] load_index = ld_addr[7:0];

always @(posedge i_clk) begin
    if (i_reset) begin
        valid <= 0;
    end
    else if (load) begin
        valid[load_index] <= 1'b1;
        tag[load_index] <= ld_addr[31:8];
        target[load_index] <= ld_target;
    end
end

always @(*) begin
if (tag[index] == i_tag && valid[index]) begin
    next_pc = target[index];
end
else begin
    next_pc = {i_tag, index} + 4;
end
end


endmodule