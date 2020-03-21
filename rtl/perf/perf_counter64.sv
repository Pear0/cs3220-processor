module perf_counter64#(
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


`ifdef ENABLE_PERF

    reg [63:0] counter;
    initial counter = 0;

    wire addr_match_low = perf.stb && (perf.addr == ADDR);
    wire addr_match_high = perf.stb && (perf.addr == ADDR+1);
    assign perf.stall = 0;

    always @(posedge i_clk) begin
        if (i_reset) begin
            counter <= 0;
        end
        else begin
            if (incr)
                counter <= counter+1;

            if (addr_match_low) begin
                perf.data <= counter[31:0];
                perf.ack <= 1;
            end
            else if (addr_match_high) begin
                perf.data <= counter[63:32];
                perf.ack <= 1;
            end
            else begin
                perf.data <= 0;
                perf.ack <= 0;
            end
        end
    end
`else

    assign perf.data = 0;
    assign perf.ack = 0;
    assign perf.stall = 0;

`endif

endmodule: perf_counter64