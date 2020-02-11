module cs3220_syn
    (
        input  wire i_sys_clk,
        input  wire i_resetn,

        input  wire [9:0] i_switches,
        output wire [9:0] o_leds,

        `ifdef VERILATOR
        output wire o_die,
        `endif

    `ifndef VERILATOR
        output wire [6:0] ssegs [0:5]
    `else
        output wire [41:0] ssegs
    `endif
    );

    wire i_clk = i_sys_clk;
    reg i_reset;
	 `ifdef VERILATOR
	 always @(*)
		i_reset = !i_resetn;
	 `else
		reg i_reset_buf;
		initial i_reset = 1;
		initial i_reset_buf = 1;
		always @(posedge i_clk)
			{i_reset, i_reset_buf} <= {i_reset_buf, !i_resetn};
	 `endif


    wire wb_cyc, wb_stb, wb_we;
    wire [29:0] wb_addr;
    reg [31:0] wb_miso;
    wire [3:0] wb_sel;
    reg wb_ack, wb_stall, wb_err;
    wire [31:0] wb_mosi;

    wire [31:0] mem_data; // MEM
    wire [31:0] sseg_data, switch_data;
    wire mem_stall, sseg_stall, switch_stall;
    wire mem_ack, sseg_ack, switch_ack;

    wire mem_sel, sseg_sel, switch_sel;

// Yaotian's Memory Map
// ------- BUS ADDRESS SAPCE ----------- --SEL
//
// 00 0000 0000 0000 0000 0000 0000 0000 00
// 00 0000 0000 0000 00xx xxxx xxxx xxxx xx - SRAM   (64KBytes) (0x0000_0000 -> 0x0000_ffff)

// 11 1111 1111 1111 1111 1100 0000 1000 00 - LEDS   (4 Bytes) (0xFFFF_F020 -> 0xFFFF_F023)
// 11 1111 1111 1111 1111 1100 0000 0000 xx - SSEG   (4 Bytes) (0xFFFF_F000 -> 0xFFFF_F003)
//(31)

    assign mem_sel      = (wb_addr[29:14] == 16'h0); // mem selected
    assign sseg_sel     = (wb_addr[29:0 ] == 30'b11_1111_1111_1111_1111_1100_0000_0000); // SSEG
    assign switch_sel   = (wb_addr[29:0 ] == 30'b11_1111_1111_1111_1111_1100_0000_1000);


// SEL
    wire none_sel;
    assign none_sel =
           (!mem_sel)
        && (!sseg_sel)
		  && (!switch_sel)
        ;

    always @(posedge i_clk)
		if (mem_err)
         wb_err <= mem_err;
      else
			wb_err <= (wb_stb) && (none_sel);

// Master Bus Respond
    always @(posedge i_clk)
        wb_ack <= 
           mem_ack
        || sseg_ack
		  || switch_ack
        ;

    always @(posedge i_clk)
        if (mem_ack)
            wb_miso <= mem_data;
        else if (sseg_ack)
            wb_miso <= sseg_data;
		  else if (switch_ack)
				wb_miso <= switch_data;
        else
            wb_miso <= 32'h0;

        
    assign wb_stall =
           (mem_sel) && (mem_stall)
        || (sseg_sel) && (sseg_stall)
		  || (switch_sel) && (switch_stall)
        ;

    wire mem_err;

    m4k_mem dmem(
        .i_clk, .i_reset,
        .wb_cyc, .wb_stb(wb_stb && mem_sel), .wb_we,
        .wb_addr,
        .wb_idata(wb_mosi),
        .wb_sel,
        .wb_ack(mem_ack), .wb_stall(mem_stall), .wb_err(mem_err),
        .wb_odata(mem_data)
    );

    `ifdef VERILATOR
    assign o_die = (wb_stb && sseg_sel && wb_we) && (wb_mosi != 1);
    `endif

    wb_sevenseg seg(
        .i_clk,
        .i_reset,
        .i_wb_cyc(wb_cyc), .i_wb_stb(wb_stb && sseg_sel), .i_wb_we(wb_we),
        .i_wb_addr(wb_addr), .i_wb_data(wb_mosi), .i_wb_sel(wb_sel),
        .o_wb_ack(sseg_ack), .o_wb_stall(sseg_stall),
        .o_wb_data(sseg_data),
        .displays(ssegs),
        .i_alt_data(0),
        .i_alt_sel(0)
    );

    wb_switch_led sw_ed(
        .i_clk,
        .i_reset,
        .i_wb_cyc(wb_cyc), .i_wb_stb(wb_stb && switch_sel), .i_wb_we(wb_we),
        .i_wb_addr(wb_addr), .i_wb_data(wb_mosi), .i_wb_sel(wb_sel),
        .o_wb_ack(switch_ack), .o_wb_stall(switch_stall),
        .o_wb_data(switch_data),
        .o_leds,
        .i_switches
    );

    core core(
        .i_clk,
        .i_reset,

        .wb_cyc,
        .wb_stb,
        .wb_we,
        .wb_addr,
        .wb_mosi,
        .wb_sel,
        .wb_ack,
        .wb_stall,
        .wb_err,
        .wb_miso
    );

endmodule: cs3220_syn
