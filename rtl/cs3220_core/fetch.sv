module fetch(
    input wire i_clk, i_reset,

    output reg [31:0] o_pc,
    output reg [31:0] o_inst,

    input wire i_branch,
    input wire i_branch_addr,

    // memory interface
    output wire o_req_addr,
    output wire o_req_stb,
    input wire i_req_data,
    input wire i_req_valid
);

    reg [31:0] pc;
    reg branch_stalled;
    reg mem_wait;
    initial pc = 0;
    initial branch_stalled = 0;
    initial mem_wait = 0;

    assign o_req_addr = i_branch ? i_branch_addr : pc;
    assign o_req_stb = (!branch_stalled || i_branch) && (i_req_valid || !mem_wait);

    assign o_pc = o_req_addr;
    assign o_inst = i_req_valid ? i_req_data : 0;


    always @(posedge i_clk) begin
        if (i_reset) begin
            pc <= 32'h100;
            branch_stalled <= 0;
            mem_wait <= 0;
        end
        else begin

            if (o_req_stb && !i_req_valid)
                mem_wait <= 1;
            else if (i_req_valid)
                mem_wait <= 0;

            if ((o_req_stb || mem_wait) && i_req_valid) begin
                pc <= pc + 4;
            end
        end
    end

endmodule

