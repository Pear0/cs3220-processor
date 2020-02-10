module m4k_mem
(
    input wire i_clk, i_reset,
    input wire wb_cyc, wb_stb, wb_we,
    input wire [29:0] wb_addr,
    input wire [31:0] wb_idata,
    input wire [3:0] wb_sel,
    output wire wb_ack, wb_stall, wb_err,
    output reg [31:0] wb_odata
);

reg [3:0][7:0] memory[16384];

localparam IDLE = 1'h0, WBACK = 1'h1;
reg [0:0] state;
initial begin
    state = IDLE;
end

assign wb_ack = state == WBACK;
assign wb_stall = !(state == IDLE);
assign wb_err = 0;

always @(posedge i_clk) begin
    if (i_reset) begin
        state <= IDLE;
    end
    else if (state == IDLE)
        if (wb_stb && wb_cyc) begin
            if (wb_we) begin
                if (wb_sel[0])
                    memory[wb_addr[15:2]][0] <= wb_idata[7:0];
                if (wb_sel[1])
                    memory[wb_addr[15:2]][1] <= wb_idata[15:8];
                if (wb_sel[2])
                    memory[wb_addr[15:2]][2] <= wb_idata[23:16];
                if (wb_sel[3])
                    memory[wb_addr[15:2]][3] <= wb_idata[31:24];
            end else begin
                wb_odata <= memory[wb_addr[15:2]];
            end
            state <= WBACK;
        end
    else if (state == WBACK) begin
        state <= IDLE;
    end
end


endmodule