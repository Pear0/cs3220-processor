interface perf_if();

    logic [7:0] addr;
    logic stb;
    logic stall;
    logic ack;
    logic [31:0] data;

endinterface : perf_if