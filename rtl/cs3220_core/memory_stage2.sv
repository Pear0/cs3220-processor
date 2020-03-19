`default_nettype none
`include "opcodes.sv"

module memory_stage2(
    input wire i_clk, i_reset,
    input wire writeback_stall, writeback_flush,
    output reg mem_stall, mem_flush,

    // Wishbone
    output reg wb_cyc, wb_stb, wb_we,
    output reg [31-2:0] wb_addr,
    output reg [31:0] wb_mosi,
    output reg [3:0] wb_sel,
    input wire wb_ack, wb_stall, wb_err,
    input wire [31:0] wb_miso,

    // Buffer In
    input wire [5:0] rr_op,
    input wire [7:0] rr_altop,
    input wire [3:0] rr_rd,
    input wire [31:0] rr_rs_val,
    input wire [31:0] rr_rt_val,
    input wire [31:0] rr_imm32,
    input wire [31:0] rr_pc,

    // Forwarding
    output reg mem_of_valid,
    output reg [3:0] mem_of_reg,
    output reg [31:0] mem_of_val,

    // Buffer Out
    output reg [3:0] mem_rd,
    output reg [31:0] mem_rd_val
);

// Wishbone
    initial begin
        wb_cyc = 0;
        wb_stb = 0;
        wb_we = 0;
        wb_mosi = 0;
        wb_addr = 0;
    end

    initial begin
        mem_of_valid = 0;
        mem_of_reg = 0;
        mem_of_val = 0;
    end

// Buffer Out
    initial begin
        mem_rd = 0;
        mem_rd_val = 0;
    end

    (* ram_init_file = `MEMINIT_FILE, ramstyle = "M10K, no_rw_check" *)
    reg [3:0] [7:0] memory [16384];


    wire start_tx;
//assign start_tx = (
//    rr_op == `OPCODE_LW ||
//    rr_op == `OPCODE_SW
//    );
    assign start_tx = rr_op[4];

    wire is_write;
//assign is_write = (rr_op == `OPCODE_SW);
    assign is_write = start_tx && rr_op[3];

    reg [31:0] mem_addr;
    always @(*)
        mem_addr = rr_rs_val+rr_imm32;

    wire is_io_addr;
    assign is_io_addr = mem_addr[16];

    wire [31:0] wr_val;
    assign wr_val = rr_rt_val;

    reg [3:0] wb_sel_val;
    always @(*)
        wb_sel_val = 4'b1111;

    reg [31:0] write_data;
    always @(*)
        write_data = wr_val;


    reg [31:0] in_data;
    always @(*)
        in_data = wb_miso;

    reg [13:0] mem_read_addr;

    wire [31:0] mem_read_value;
    assign mem_read_value = memory[mem_read_addr];

    localparam
        IDLE=0,
        READ_STROBE=1,
        READ_WAIT_ACK=2,
        READ_STALLED_OUT=3,
        READ_OUT=4,
        WRITE_STROBE=5,
        WRITE_WAIT_ACK=6,
        LAST_STATE=7,
        READ_MEM=8;

    reg [3:0] current_state;
    initial current_state = IDLE;

// wishbone combinational control signals
    assign wb_stb = (current_state == READ_STROBE) || (current_state == WRITE_STROBE);
    assign wb_we = (current_state == WRITE_STROBE);
    assign wb_cyc = (current_state != IDLE);

    reg internal_stall;
    initial internal_stall = 0;
    assign mem_stall = writeback_stall || internal_stall;

// internal state machine control signals
    wire state_strobe, state_wait_ack;
    assign state_strobe = (current_state == READ_STROBE) || (current_state == WRITE_STROBE);
    assign state_wait_ack = (current_state == READ_WAIT_ACK) || (current_state == WRITE_WAIT_ACK);

    always @(*)
        case (current_state)
            IDLE: internal_stall = start_tx && (is_io_addr || !is_write);
            READ_STROBE,
                WRITE_STROBE: internal_stall = 1;
            READ_WAIT_ACK,
                WRITE_WAIT_ACK: internal_stall = !(wb_err || wb_ack);
            READ_STALLED_OUT: internal_stall = 1;
            READ_OUT, READ_MEM: internal_stall = 0;
            default: internal_stall = 1;
        endcase

    reg [31:0] temp_read;

    always @(*)
        case (current_state)
            READ_MEM: begin
                mem_of_valid = !is_write;
                mem_of_reg = !is_write ? rr_rd:0;
                mem_of_val = !is_write ? mem_read_value:0;
            end
            READ_STALLED_OUT: begin
                mem_of_valid = !is_write;
                mem_of_reg = !is_write ? rr_rd:0;
                mem_of_val = !is_write ? temp_read:0;
            end
            READ_WAIT_ACK: begin
                mem_of_valid = !writeback_stall;
                mem_of_reg = !writeback_stall ? rr_rd:0;
                mem_of_val = !writeback_stall ? (wb_err ? 32'h13371337:wb_miso):0;
            end
            default: begin
                mem_of_valid = 0;
                mem_of_reg = 0;
                mem_of_val = 0;
            end
        endcase

    always @(posedge i_clk) begin
        if (i_reset || writeback_flush) begin // TODO i_pipe_flush not handled properly
            current_state <= IDLE;

            wb_addr <= 0;
            wb_mosi <= 0;
            wb_sel <= 0;

            mem_rd <= 0;
            mem_rd_val <= 0;

            mem_read_addr <= 0;
        end
        else if (writeback_stall) begin
        end
        else if (current_state == IDLE) begin
            if (start_tx && !is_io_addr) begin

                if (is_write) begin
                        memory[mem_addr[15:2]] <= write_data;
                end
                else begin
                    mem_read_addr <= mem_addr[15:2];
                    current_state <= READ_MEM;
                end

            end
            else begin

                mem_rd <= 0;
                mem_rd_val <= 0;
                if (start_tx) begin
                    current_state <= is_write ? WRITE_STROBE:READ_STROBE;
                    wb_addr <= mem_addr[31:2];
                    wb_sel <= wb_sel_val;

                    if (is_write)
                        wb_mosi <= write_data;
                end

            end
        end
        else if (current_state == READ_MEM) begin
            current_state <= IDLE;

            mem_rd <= rr_rd;
            mem_rd_val <= mem_read_value;

        end
        else if (state_strobe && !wb_stall) begin
            current_state <= current_state == READ_STROBE ? READ_WAIT_ACK:WRITE_WAIT_ACK;
            wb_addr <= 0;

            wb_mosi <= 0;
        end
        else if (state_wait_ack && wb_err) begin
            // for now we'll just squash bus error as a special read value.
            // for write, whatever.
            current_state <= current_state == READ_WAIT_ACK ? (writeback_stall ? READ_STALLED_OUT:IDLE):IDLE;

            if (!is_write) begin
                if (writeback_stall)
                    temp_read <= 32'h13371337;
                else begin
                    mem_rd <= rr_rd;
                    mem_rd_val <= 32'h13371337;
                end
            end
        end
        else if (state_wait_ack && wb_ack && !wb_err) begin

            if (current_state == READ_WAIT_ACK)
                current_state <= writeback_stall ? READ_STALLED_OUT:IDLE;
            else
                current_state <= IDLE;

            wb_sel <= 0;

            if (!is_write) begin
                if (writeback_stall)
                    temp_read <= in_data;
                else begin
                    mem_rd <= rr_rd;
                    mem_rd_val <= in_data;
                end
            end
        end
        else if (current_state == READ_STALLED_OUT && !writeback_stall) begin
            current_state <= IDLE;

            mem_rd <= rr_rd;
            mem_rd_val <= temp_read;

            temp_read <= 0;
        end
        else if (current_state == READ_OUT) begin
            current_state <= IDLE;
            mem_rd <= 0;
            mem_rd_val <= 0;
            mem_flush <= 0;
        end
    end


endmodule: memory_stage2


