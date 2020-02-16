module compat_shift
    #(
        parameter WIDTH=1,
        parameter WIDTHDIST=1,    // should be log2(WIDTH)
        parameter TYPE="LOGICAL", // LOGICAL or ARITHMETIC
        parameter PIPELINE=0
    )
    (
        input clock, aclr, clken,

        input [WIDTH-1:0] data,
        input [WIDTHDIST-1:0] distance,
        input direction, // 0 = left, 1 = right

        output [WIDTH-1:0] result
    );

// synthesis read_comments_as_HDL on
// localparam IMPL = "quartus";
// synthesis read_comments_as_HDL off

// altera translate_off
    localparam IMPL="fallback";
// altera translate_on

    generate
        if (IMPL == "quartus") begin

            if (PIPELINE > 0) begin
                lpm_clshift#(
                    .LPM_WIDTH(WIDTH),
                    .LPM_WIDTHDIST(WIDTHDIST),
                    .LPM_SHIFTTYPE(TYPE), // "LOGICAL", "ROTATE", "ARITHMETIC"
                    .LPM_PIPELINE(PIPELINE)
                ) quartus_shift(
                    .clock(clock),
                    .aclr(aclr),
                    .clken(clken),
                    .data(data),
                    .direction(direction),
                    .distance(distance)
                );
            end else begin
                lpm_clshift#(
                    .LPM_WIDTH(WIDTH),
                    .LPM_WIDTHDIST(WIDTHDIST),
                    .LPM_SHIFTTYPE(TYPE), // "LOGICAL", "ROTATE", "ARITHMETIC"
                    .LPM_PIPELINE(0)
                ) quartus_shift0(
                    .data(data),
                    .direction(direction),
                    .distance(distance)
                );
            end

        end
        else begin

            wire [WIDTH-1:0] numer_pipe_end;
            wire [WIDTHDIST-1:0] denom_pipe_end;
            if (PIPELINE == 0) begin
                assign numer_pipe_end = data;
                assign denom_pipe_end = distance;
            end else begin
                reg [WIDTH-1:0] numer_pipe [0:PIPELINE-1];
                reg [WIDTHDIST-1:0] denom_pipe [0:PIPELINE-1];

                genvar pipe_stage;
                for (pipe_stage = 0; pipe_stage < PIPELINE-1; pipe_stage = pipe_stage+1) begin : pipe_stages
                    always @(posedge clock or posedge aclr) begin
                        if (aclr) begin
                            numer_pipe[pipe_stage+1] <= 0;
                            denom_pipe[pipe_stage+1] <= 0;
                        end
                        else if (clken) begin
                            numer_pipe[pipe_stage+1] <= numer_pipe[pipe_stage];
                            denom_pipe[pipe_stage+1] <= denom_pipe[pipe_stage];
                        end
                    end
                end

                always @(posedge clock or posedge aclr) begin
                    if (aclr) begin
                        numer_pipe[0] <= 0;
                        denom_pipe[0] <= 0;
                    end
                    else if (clken) begin
                        numer_pipe[0] <= data;
                        denom_pipe[0] <= distance;
                    end
                end

                assign numer_pipe_end = numer_pipe[PIPELINE-1];
                assign denom_pipe_end = denom_pipe[PIPELINE-1];
            end

            /* * * * * * * * * * * * * * * * * * * * * * */
            /*  Do the actual fallback computation here  */
            /* * * * * * * * * * * * * * * * * * * * * * */


            if (TYPE == "ARITHMETIC") begin
                always @(*) begin
                    if (direction)
                        result = $signed($signed(numer_pipe_end) >>> denom_pipe_end);
                    else
                        result = numer_pipe_end << denom_pipe_end;
                end
            end
            else begin // LOGICAL
                always @(*) begin
                    if (direction)
                        result = numer_pipe_end >> denom_pipe_end;
                    else
                        result = numer_pipe_end << denom_pipe_end;
                end
            end

        end
    endgenerate

endmodule: compat_shift