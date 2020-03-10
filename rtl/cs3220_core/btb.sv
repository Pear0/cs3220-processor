module btb(
    input i_clk, i_reset,
    input [31:0] pc,

    input load,
    input [31:0] ld_addr, ld_target,

    output reg [31:0] next_pc
);

/*
31--------------------------------------------0
| TAG [31:10]                 |INDEX[7:2]|2'b0|
-----------------------------------------------
*/

reg [255:0] valid;
reg [21:0] tag      [256];
reg [31:0] target   [256];

reg [21:0] i_tag;
reg [7:0]  index;


initial begin
    valid = 0;
end

always @(*) begin
    i_tag = pc[31:10];
    index = pc[9:2];
end

wire [7:0] load_index = ld_addr[9:2];

always @(posedge i_clk) begin
    if (i_reset) begin
        valid <= 0;
    end
    else if (load) begin
        valid[load_index] <= 1'b1;
        tag[load_index] <= ld_addr[31:10];
        target[load_index] <= ld_target;
    end
end

always @(*) begin
if (tag[index] == i_tag && valid[index]) begin
    next_pc = target[index];
end
else begin
    next_pc = {i_tag, index, 2'b0} + 4;
end
end


endmodule