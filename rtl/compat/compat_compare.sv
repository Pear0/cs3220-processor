module compat_compare
    #(
        parameter WIDTH=1,
        // we assume signed: parameter REPRESENTATION="UNSIGNED", // UNSIGNED or SIGNED
        parameter PIPELINE=0
    )
    (
        input clock, aclr, clken,

        input [WIDTH-1:0] dataa,
        input [WIDTH-1:0] datab,

        output alb, aeb, agb, ageb, aneb, aleb
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
                lpm_compare#(
                    .LPM_WIDTH(WIDTH),
                    .LPM_REPRESENTATION("SIGNED"),
                    .LPM_PIPELINE(PIPELINE)
                ) quartus_compare(
                    .clock(clock),
                    .aclr(aclr),
                    .clken(clken),
                    .dataa(dataa),
                    .datab(datab),
                    .alb(alb), .aeb(aeb), .agb(agb),
                    .ageb(ageb), .aneb(aneb), .aleb(aleb)
                );
            end else begin
                lpm_compare#(
                    .LPM_WIDTH(WIDTH),
                    .LPM_REPRESENTATION("SIGNED"),
                    .LPM_PIPELINE(0)
                ) quartus_commpare0(
                    .dataa(dataa),
                    .datab(datab),
                    .alb(alb), .aeb(aeb), .agb(agb),
                    .ageb(ageb), .aneb(aneb), .aleb(aleb)
                );
            end

        end
        else begin

            wire [WIDTH-1:0] dataa_pipe_end;
            wire [WIDTH-1:0] datab_pipe_end;
            if (PIPELINE == 0) begin
                assign dataa_pipe_end = dataa;
                assign datab_pipe_end = datab;
            end else begin
                reg [WIDTH-1:0] dataa_pipe [0:PIPELINE-1];
                reg [WIDTH-1:0] datab_pipe [0:PIPELINE-1];

                genvar pipe_stage;
                for (pipe_stage = 0; pipe_stage < PIPELINE-1; pipe_stage = pipe_stage+1) begin : pipe_stages
                    always @(posedge clock or posedge aclr) begin
                        if (aclr) begin
                            dataa_pipe[pipe_stage+1] <= 0;
                            datab_pipe[pipe_stage+1] <= 0;
                        end
                        else if (clken) begin
                            dataa_pipe[pipe_stage+1] <= dataa_pipe[pipe_stage];
                            datab_pipe[pipe_stage+1] <= datab_pipe[pipe_stage];
                        end
                    end
                end

                always @(posedge clock or posedge aclr) begin
                    if (aclr) begin
                        dataa_pipe[0] <= 0;
                        datab_pipe[0] <= 0;
                    end
                    else if (clken) begin
                        dataa_pipe[0] <= dataa;
                        datab_pipe[0] <= datab;
                    end
                end

                assign dataa_pipe_end = dataa_pipe[PIPELINE-1];
                assign datab_pipe_end = datab_pipe[PIPELINE-1];
            end

            /* * * * * * * * * * * * * * * * * * * * * * */
            /*  Do the actual fallback computation here  */
            /* * * * * * * * * * * * * * * * * * * * * * */

            // alb, aeb, agb, ageb, aneb, aleb
            assign alb = $signed(dataa_pipe_end) < $signed(datab_pipe_end);
            assign aeb = $signed(dataa_pipe_end) == $signed(datab_pipe_end);
            assign agb = $signed(dataa_pipe_end) > $signed(datab_pipe_end);
            assign ageb = agb || aeb;
            assign aneb = !aeb;
            assign aleb = alb || aeb;

        end
    endgenerate

endmodule: compat_compare