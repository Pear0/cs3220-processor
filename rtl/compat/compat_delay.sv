module compat_delay
    #(
        parameter WIDTH=1,
        parameter PIPELINE=0
    )
    (
        input clock, aclr, clken,

        input [WIDTH-1:0] in,
        output [WIDTH-1:0] out
    );

    generate
        begin

            wire [WIDTH-1:0] dataa_pipe_end;
            if (PIPELINE == 0) begin
                assign dataa_pipe_end = in;
            end else begin
                reg [WIDTH-1:0] dataa_pipe [0:PIPELINE-1];

                genvar pipe_stage;
                for (pipe_stage = 0; pipe_stage < PIPELINE-1; pipe_stage = pipe_stage+1) begin : pipe_stages
                    always @(posedge clock or posedge aclr) begin
                        if (aclr) begin
                            dataa_pipe[pipe_stage+1] <= 0;
                        end
                        else if (clken) begin
                            dataa_pipe[pipe_stage+1] <= dataa_pipe[pipe_stage];
                        end
                    end
                end

                always @(posedge clock or posedge aclr) begin
                    if (aclr) begin
                        dataa_pipe[0] <= 0;
                    end
                    else if (clken) begin
                        dataa_pipe[0] <= in;
                    end
                end

                assign dataa_pipe_end = dataa_pipe[PIPELINE-1];
            end

            /* * * * * * * * * * * * * * * * * * * * * * */
            /*  Do the actual fallback computation here  */
            /* * * * * * * * * * * * * * * * * * * * * * */

            assign out = dataa_pipe_end;

        end
    endgenerate

endmodule: compat_delay