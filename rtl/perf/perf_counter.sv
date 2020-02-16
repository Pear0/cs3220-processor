module perf_counter#(
    parameter ADDR
)(
    input wire i_clk, i_reset,

    input wire incr,

    // Perf Interface
//    input wire [7:0] perf_addr,
//    input wire perf_stb,
//    output reg perf_ack,
//    output reg [31:0] perf_data

    perf_if perf
);

    reg [31:0] counter;
    initial counter = 0;

    wire addr_match = perf.stb && (perf.addr == ADDR);
    assign perf.stall = 0;

    always @(posedge i_clk) begin
        if (i_reset) begin
            counter <= 0;
        end
        else begin
            if (incr)
                counter <= counter+1;

            if (addr_match) begin
                perf.data <= counter;
                perf.ack <= 1;
            end
            else begin
                perf.data <= 0;
                perf.ack <= 0;
            end
        end
    end

endmodule: perf_counter