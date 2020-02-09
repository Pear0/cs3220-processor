`default_nettype none

module fetch_stage(
    input wire i_clk, i_reset,

    output reg [31:0] fetch_pc,
    output reg [31:0] fetch_inst,

    input wire i_branch,
    input wire [31:0] i_branch_addr,

    input wire decode_flush,
    input wire decode_stall,

    // memory interface
    output wire [31:0] mem_req_addr,
    output wire mem_req_stb,
    input wire [31:0] mem_req_data,
    input wire mem_req_valid
);

    reg [31:0] pc;
    reg branch_stalled;
    reg mem_wait;
    initial pc = 0;
    initial branch_stalled = 0;
    initial mem_wait = 0;

    assign mem_req_addr = i_branch ? i_branch_addr : pc;
    assign mem_req_stb = (!branch_stalled || i_branch) && !mem_wait;

    assign fetch_pc = mem_req_addr;
    assign fetch_inst = mem_req_valid ? mem_req_data: 0;


    always @(posedge i_clk) begin
        if (i_reset) begin
            pc <= 32'h100;
            branch_stalled <= 0;
            mem_wait <= 0;
        end
        else begin

            if (mem_req_stb && !mem_req_valid)
                mem_wait <= 1;
            else if (mem_req_valid)
                mem_wait <= 0;

            if ((mem_req_stb || mem_wait) && mem_req_valid) begin
                pc <= pc + 4;
            end
        end
    end

endmodule : fetch_stage

