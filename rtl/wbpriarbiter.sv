`default_nettype	none
module	wbpriarbiter(i_clk,
	// Bus A
	i_a_cyc, i_a_stb, i_a_we, i_a_adr, i_a_dat, i_a_sel, o_a_ack, o_a_stall, o_a_err,
	// Bus B
	i_b_cyc, i_b_stb, i_b_we, i_b_adr, i_b_dat, i_b_sel, o_b_ack, o_b_stall, o_b_err,
	// Both buses
	o_cyc, o_stb, o_we, o_adr, o_dat, o_sel, i_ack, i_stall, i_err);
	parameter			DW=32, AW=32;
	parameter	[0:0]		OPT_ZERO_ON_IDLE = 1'b0;
	//
	input	wire			i_clk;
	// Bus A
	input	wire			i_a_cyc, i_a_stb, i_a_we;
	input	wire	[(AW-1):0]	i_a_adr;
	input	wire	[(DW-1):0]	i_a_dat;
	input	wire	[(DW/8-1):0]	i_a_sel;
	output	wire			o_a_ack, o_a_stall, o_a_err;
	// Bus B
	input	wire			i_b_cyc, i_b_stb, i_b_we;
	input	wire	[(AW-1):0]	i_b_adr;
	input	wire	[(DW-1):0]	i_b_dat;
	input	wire	[(DW/8-1):0]	i_b_sel;
	output	wire			o_b_ack, o_b_stall, o_b_err;
	//
	output	wire			o_cyc, o_stb, o_we;
	output	wire	[(AW-1):0]	o_adr;
	output	wire	[(DW-1):0]	o_dat;
	output	wire	[(DW/8-1):0]	o_sel;
	input	wire			i_ack, i_stall, i_err;

	// Go high immediately (new cycle) if ...
	//	Previous cycle was low and *someone* is requesting a bus cycle
	// Go low immadiately if ...
	//	We were just high and the owner no longer wants the bus
	// WISHBONE Spec recommends no logic between a FF and the o_cyc
	//	This violates that spec.  (Rec 3.15, p35)
	reg	r_a_owner;

	initial	r_a_owner = 1'b1;
	always @(posedge i_clk)
		if (!i_b_cyc)
			r_a_owner <= 1'b1;
		// Allow B to set its CYC line w/o activating this interface
		else if ((i_b_cyc)&&(i_b_stb)&&(!i_a_cyc))
			r_a_owner <= 1'b0;

	// Realistically, if neither master owns the bus, the output is a
	// don't care.  Thus we trigger off whether or not 'A' owns the bus.
	// If 'B' owns it all we care is that 'A' does not.  Likewise, if
	// neither owns the bus than the values on these various lines are
	// irrelevant.

	assign o_cyc = (r_a_owner) ? i_a_cyc : i_b_cyc;
	assign o_we  = (r_a_owner) ? i_a_we  : i_b_we;
	assign o_stb   = (r_a_owner) ? i_a_stb   : i_b_stb;
	generate if (OPT_ZERO_ON_IDLE)
	begin
		assign	o_adr     = (o_stb)?((r_a_owner) ? i_a_adr  : i_b_adr):0;
		assign	o_dat     = (o_stb)?((r_a_owner) ? i_a_dat  : i_b_dat):0;
		assign	o_sel     = (o_stb)?((r_a_owner) ? i_a_sel  : i_b_sel):0;
		assign	o_a_ack   = (o_cyc)&&( r_a_owner) ? i_ack   : 1'b0;
		assign	o_b_ack   = (o_cyc)&&(!r_a_owner) ? i_ack   : 1'b0;
		assign	o_a_stall = (o_cyc)&&( r_a_owner) ? i_stall : 1'b1;
		assign	o_b_stall = (o_cyc)&&(!r_a_owner) ? i_stall : 1'b1;
		assign	o_a_err   = (o_cyc)&&( r_a_owner) ? i_err : 1'b0;
		assign	o_b_err   = (o_cyc)&&(!r_a_owner) ? i_err : 1'b0;
	end else begin
		assign o_adr   = (r_a_owner) ? i_a_adr   : i_b_adr;
		assign o_dat   = (r_a_owner) ? i_a_dat   : i_b_dat;
		assign o_sel   = (r_a_owner) ? i_a_sel   : i_b_sel;

		// We cannot allow the return acknowledgement to ever go high if
		// the master in question does not own the bus.  Hence we force it
		// low if the particular master doesn't own the bus.
		assign	o_a_ack   = ( r_a_owner) ? i_ack   : 1'b0;
		assign	o_b_ack   = (!r_a_owner) ? i_ack   : 1'b0;

		// Stall must be asserted on the same cycle the input master asserts
		// the bus, if the bus isn't granted to him.
		assign	o_a_stall = ( r_a_owner) ? i_stall : 1'b1;
		assign	o_b_stall = (!r_a_owner) ? i_stall : 1'b1;

		//
		//
		assign	o_a_err = ( r_a_owner) ? i_err : 1'b0;
		assign	o_b_err = (!r_a_owner) ? i_err : 1'b0;
	end endgenerate

`ifdef	FORMAL
`ifdef	WBPRIARBITER
`define	ASSUME	assume
`else
`define	ASSUME	assert
`endif

	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	initial	assume(!i_a_cyc);
	initial	assume(!i_a_stb);

	initial	assume(!i_b_cyc);
	initial	assume(!i_b_stb);

	initial	assume(!i_ack);
	initial	assume(!i_err);

	always @(posedge i_clk)
	begin
		if (o_cyc)
			assert((i_a_cyc)||(i_b_cyc));
		if ((f_past_valid)&&($past(o_cyc))&&(o_cyc))
			assert($past(r_a_owner) == r_a_owner);
		if ((f_past_valid)&&($past(!o_cyc))&&($past(i_a_stb)))
			assert(r_a_owner);
		if ((f_past_valid)&&($past(!o_cyc))&&($past(i_b_stb)))
			assert(!r_a_owner);
	end

	reg	f_reset;
	initial	f_reset = 1'b1;
	always @(posedge i_clk)
		f_reset <= 1'b0;
	always @(*)
		if (!f_past_valid)
			assert(f_reset);

	parameter	F_LGDEPTH=3;

	wire	[(F_LGDEPTH-1):0]	f_nreqs, f_nacks, f_outstanding,
			f_a_nreqs, f_a_nacks, f_a_outstanding,
			f_b_nreqs, f_b_nacks, f_b_outstanding;

	fwb_master #(.F_MAX_STALL(0),
			.F_LGDEPTH(F_LGDEPTH),
			.F_MAX_ACK_DELAY(0),
			.F_OPT_RMW_BUS_OPTION(1),
			.F_OPT_DISCONTINUOUS(1))
		f_wbm(i_clk, f_reset,
			o_cyc, o_stb, o_we, o_adr, o_dat, o_sel,
			i_ack, i_stall, 32'h0, i_err,
			f_nreqs, f_nacks, f_outstanding);
	fwb_slave  #(.F_MAX_STALL(0),
			.F_LGDEPTH(F_LGDEPTH),
			.F_MAX_ACK_DELAY(0),
			.F_OPT_RMW_BUS_OPTION(1),
			.F_OPT_DISCONTINUOUS(1))
		f_wba(i_clk, f_reset,
			i_a_cyc, i_a_stb, i_a_we, i_a_adr, i_a_dat, i_a_sel,
			o_a_ack, o_a_stall, 32'h0, o_a_err,
			f_a_nreqs, f_a_nacks, f_a_outstanding);
	fwb_slave  #(.F_MAX_STALL(0),
			.F_LGDEPTH(F_LGDEPTH),
			.F_MAX_ACK_DELAY(0),
			.F_OPT_RMW_BUS_OPTION(1),
			.F_OPT_DISCONTINUOUS(1))
		f_wbb(i_clk, f_reset,
			i_b_cyc, i_b_stb, i_b_we, i_b_adr, i_b_dat, i_b_sel,
			o_b_ack, o_b_stall, 32'h0, o_b_err,
			f_b_nreqs, f_b_nacks, f_b_outstanding);

	always @(posedge i_clk)
		if (r_a_owner)
		begin
			assert(f_b_nreqs == 0);
			assert(f_b_nacks == 0);
			assert(f_a_outstanding == f_outstanding);
		end else begin
			assert(f_a_nreqs == 0);
			assert(f_a_nacks == 0);
			assert(f_b_outstanding == f_outstanding);
		end

	always @(posedge i_clk)
		if ((r_a_owner)&&(i_b_cyc))
			assume(i_b_stb);

	always @(posedge i_clk)
		if ((r_a_owner)&&(i_a_cyc))
			assume(i_a_stb);

`endif
endmodule