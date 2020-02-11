module cs3220_syn
    (
        input wire i_sys_clk,
        input wire i_resetn,
`ifndef VERILATOR
        output wire [6:0] ssegs [6]
`endif
    );

    wire i_clk = i_sys_clk;
    wire i_reset = !i_resetn;


    wire wb_cyc, wb_stb, wb_we;
    wire [29:0] wb_addr;
    wire [31:0] wb_idata;
    wire [3:0] wb_sel;
    wire wb_ack, wb_stall, wb_err;
    wire [31:0] wb_odata;

    wire [31:0] mem_data; // MEM
    wire [31:0] sseg_data;
    wire mem_stall, sseg_stall;
    wire mem_ack;
    wire sseg_ack;

    wire mem_sel, sseg_sel;

// Yaotian's Memory Map
// ------- BUS ADDRESS SAPCE ----------- --SEL
//
// 00 0000 0000 0000 0000 0000 0000 0000 00
// 00 0000 0000 0000 0000 xxxx xxxx xxxx xx - SRAM   (64KBytes) (0x0000_0000 -> 0x0000_7fff)

// 11 1111 1111 1111 1111 1100 0000 0000 00 - SSEG   (4 Bytes) (0x0100_0000 -> 0x0100_0003)
// 00 0000 0100 0000 0000 0000 0000 0001 xx - SW/LED (4 Bytes) (0x0100_0004 -> 0x0100_0007)
// 00 0000 0100 0000 0000 0000 0000 001x xx - LCD    (8 Bytes) (0x0100_0008 -> 0x0100_000f)

// 11 1111 1111 1111 1111 1111 1111 110x xx - TIMR (8 Bytes) (0xFFFF_FFF0 -> 0xFFFF_FFF7)
// 11 1111 1111 1111 1111 1111 1111 111x xx - UART (8 Bytes) (0xFFFF_FFF8 -> 0xFFFF_FFFF)
//(31)

    assign mem_sel  = (wb_addr[29:12] == 18'h0); // mem selected
    assign sseg_sel = (wb_addr[29:0 ] == 30'b11_1111_1111_1111_1111_1100_0000_0000); // SSEG


// SEL
    wire none_sel;
    assign none_sel =
        (!mem_sel)
            && (!sseg_sel)
        ;

    always @(posedge i_clk)
        wb_err <= (wb_stb) && (none_sel);

// Master Bus Respond
    always @(posedge i_clk)
        wb_ack <=
            mem_ack
                || sseg_ack
            ;

    always @(posedge i_clk)
        if (mem_ack)
            wb_idata <= mem_data;
        else if (sseg_ack)
            wb_idata <= sseg_data;
        else
            wb_idata <= 32'h0;

    assign wb_stall =
        ((mem_sel) && (mem_stall))
            || (sseg_sel) && (sseg_stall)
        ;

    wire mem_err;

    m4k_mem dmem(
        .i_clk, .i_reset,
        .wb_cyc, .wb_stb(wb_stb && mem_sel), .wb_we,
        .wb_addr,
        .wb_idata,
        .wb_sel,
        .wb_ack(mem_ack), .wb_stall(mem_stall), .wb_err(mem_err),
        .wb_odata(mem_data)
    );

    wb_sevenseg seg(
        .i_clk,
        .i_reset,
        .i_wb_cyc(wb_cyc), .i_wb_stb(wb_stb && sseg_sel), .i_wb_we(wb_we),
        .i_wb_addr(wb_addr), .i_wb_data(wb_idata), .i_wb_sel(wb_sel),
        .o_wb_ack(sseg_ack), .o_wb_stall(sseg_stall),
        .o_wb_data(sseg_data),
        .displays(ssegs),
        .i_alt_data(0),
        .i_alt_sel(0)
    );

    core core(
        .i_clk,
        .i_reset,

        .wb_cyc,
        .wb_stb,
        .wb_we,
        .wb_addr,
        .wb_odata,
        .wb_sel,
        .wb_ack,
        .wb_stall,
        .wb_err,
        .wb_idata,
    );

endmodule: cs3220_syn
