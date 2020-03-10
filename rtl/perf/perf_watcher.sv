module perf_watcher#(
    parameter DIVW=16
)(
    input i_clk, i_reset,

    input [7:0] addr,
    output reg [31:0] data,

    perf_if perf
);

    localparam S_IDLE=0;
    localparam S_STALLED=1;
    localparam S_WAITING=2;

    reg [DIVW-1:0] refresh_counter;
    reg [3:0] state;

    reg [7:0] wait_counter;

    always @(posedge i_clk) begin
        if (i_reset) begin
            refresh_counter <= 0;
            state <= S_IDLE;
            data <= 32'hff;
            perf.addr <= 0;
            perf.stb <= 0;
            wait_counter <= 0;
        end
        else if (refresh_counter != 0)
            refresh_counter <= refresh_counter-1;
        else begin
            data <= {state, 12'b0, wait_counter, refresh_counter[7:0]};

            if (state == S_IDLE) begin
                perf.addr <= addr;
                perf.stb <= 1;
                state <= S_STALLED;
                wait_counter <= 255;
            end
            else if ((state == S_STALLED || state == S_WAITING) && perf.ack) begin
                perf.addr <= 0;
                perf.stb <= 0;
                data <= perf.data;
                state <= S_IDLE;
                refresh_counter <= refresh_counter-1; // restart the delay
            end
            else if (wait_counter == 0) begin
                data <= 32'hffffffff;
                state <= S_IDLE;
                refresh_counter <= refresh_counter-1; // restart the delay
            end
            else begin
                wait_counter <= wait_counter-1;

                if (state == S_STALLED && !perf.stall) begin
                    perf.addr <= 0;
                    perf.stb <= 0;
                    state <= S_WAITING; // possibly overriden below
                end
            end

        end
    end

endmodule: perf_watcher