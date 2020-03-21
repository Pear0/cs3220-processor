`default_nettype none

/*
 * Major changes to this stage include the branch prediction logic.
 */

module fetch_stage(
    input wire i_clk, i_reset,

    output reg [31:0] fetch_pc,
    output reg [31:0] fetch_predicted_pc,
    output reg [31:0] fetch_inst,

    input wire [31:0] exec_br_origin,
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
    if (i_reset || exec_ld_pc) begin
        fetch_inst <= 32'h0;
        if (decode_flush) begin
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

/*
31--------------------------------------------0
| TAG [31:10]                 |INDEX[7:2]|2'b0|
-----------------------------------------------
*/
reg [31:0] target   [256];
reg [0:0] confidence [256];

wire [7:0] load_index = exec_br_origin[9:2];

always @(posedge i_clk) begin
    if (exec_ld_pc) begin
        if (confidence[load_index] == 0) begin
            target[load_index] <= exec_br_pc;
            confidence[load_index] <= 1;
        end else begin
            confidence[load_index] <= 0;
        end
    end else begin
        confidence[load_index] <= 1;
    end
end

wire is_br = mem_req_data[31:29] == 3'b001;

assign fetch_predicted_pc = r_pc;

always @(*) begin
if (is_br) begin
    next_pc = target[btb_index];
end
else begin
    next_pc = r_pc + 4;
end
end


endmodule : fetch_stage

