module l1_icache
(
    i_clk, i_reset,
    // Request to higher level cache
    o_req_addr, o_req_stb,
    i_req_data, i_req_valid,
    // Data Request from Fetch
    i_req_addr, i_req_stb,
    o_req_data, o_req_valid
);

endmodule
