`default_nettype none

module tl45_dprf(
	input wire [3:0] readAdd1,
	input wire [3:0] readAdd2,
	input wire [3:0] writeAdd,
	input wire [31:0] dataI,
	input wire wrREG,
	input wire clk,
	input wire reset,
	output reg [31:0] dataO1,
	output reg [31:0] dataO2
);

reg [31:0] registers[16];

	reg [4:0] i;
initial begin
	for (i = 0; i < 16; i++)
		registers[i[3:0]] = 0;
end

// Read Port 1 selection
always @(posedge clk)
begin
	if (readAdd1 == 0)
		dataO1 <= 0;
	else if (readAdd1 == writeAdd)
		dataO1 <= dataI;
	else
		dataO1 <= registers[readAdd1];
end

// Read Port 2 selection
always @(posedge clk)
begin
	if (readAdd2 == 0)
		dataO2 <= 0;
	else if (readAdd2 == writeAdd)
		dataO2 <= dataI;
	else
		dataO2 <= registers[readAdd2];
end

// Write
always @(posedge clk)
begin
	if (wrREG && (writeAdd > 0)) begin
		registers[writeAdd] <= dataI;
	end
end

`ifdef FORMAL

`endif

endmodule : tl45_dprf