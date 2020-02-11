module simple_memory(
    input wire i_clk, i_reset,

    // memory interface
    input wire [31:0] mem_req_addr,
    input wire mem_req_stb,
    output wire [31:0] mem_req_data,
    output wire mem_req_valid
);

    parameter IMEMADDRBITS=16;
    parameter IMEMWORDBITS=2;
    parameter IMEMWORDS=(1 << (IMEMADDRBITS-IMEMWORDBITS));

    // (* ram_init_file = IDMEMINITFILE *)
    (* ram_init_file = "../test_code/test1.mif" *) 
	 reg [31:0] memory [IMEMWORDS-1:0];

    assign mem_req_data = memory[mem_req_addr[IMEMADDRBITS-1:IMEMWORDBITS]];
    assign mem_req_valid = mem_req_stb;

endmodule: simple_memory