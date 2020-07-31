module perf_mux2(
    perf_if a,
    perf_if b,
    perf_if out
);

    assign a.addr = out.addr;
    assign a.stb = out.stb;
    assign b.addr = out.addr;
    assign b.stb = out.stb;

    assign out.stall = 0;

    assign out.ack = a.ack || b.ack;
    assign out.data = a.ack ? a.data : b.data;

endmodule : perf_mux2
