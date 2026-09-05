module chroma_extraction (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       in_valid,
    input  logic [7:0] in_data,
    input  logic       in_sof,
    input  logic       in_eol,
    input  logic       in_eof,
    output logic       out_valid,
    output logic [7:0] out_u,
    output logic [7:0] out_v,
    output logic [7:0] out_y0,
    output logic [7:0] out_y1,
    output logic       out_sof,
    output logic       out_eol,
    output logic       out_eof
);

    typedef enum logic {  
        IDLE,
        EXTRACT
    } state_t;
    state_t state_r;

    logic out_valid_r;
    logic [1:0] count_r;
    logic [7:0] out_u_r;
    logic [7:0] out_v_r;
    logic [7:0] out_y0_r;
    logic [7:0] out_y1_r;
    logic out_sof_r;
    logic out_eol_r;
    logic out_eof_r;
    logic sof_r;


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_r <= IDLE;
            count_r <= '0;
            out_u_r <= '0;
            out_v_r <= '0;
            out_y0_r <= '0;
            out_y1_r <= '0;
            sof_r <= '0;
            out_sof_r <= '0;
            out_eol_r <= '0;
            out_eof_r <= '0;
            out_valid_r <= '0;
        end else begin
            out_valid_r <= 1'b0;
            out_sof_r <= 1'b0;
            out_eol_r <= 1'b0;
            out_eof_r <= 1'b0;

            // stickies
            sof_r <= sof_r || in_sof;

            case (state_r)
                IDLE: begin
                    if (in_sof && in_valid) begin
                        state_r <= EXTRACT;
                        out_u_r <= in_data;
                        count_r <= count_r + 1;
                    end
                end
                
                EXTRACT: begin
                    if (in_valid) begin
                        count_r <= count_r + 1;
                        if (count_r == 0) begin
                            out_u_r <= in_data;
                        end

                        if (count_r == 1) begin
                            out_y0_r <= in_data;
                        end

                        if (count_r == 2) begin
                            out_v_r <= in_data;
                        end

                        if (count_r == 3) begin
                            out_y1_r <= in_data;
                            out_valid_r <= 1'b1;

                            // if our sticky bits are currently asserted, the next byte should
                            // assert the corresponding signal
                            if (sof_r) begin
                                out_sof_r <= 1'b1;
                                sof_r <= 1'b0;
                            end

                            if (in_eol) begin
                                out_eol_r <= 1'b1;
                                count_r <= '0;
                            end

                            if (in_eof) begin
                                out_eof_r <= 1'b1;
                            end
                        end
                    end
                end
            endcase
        end
    end

    assign out_valid = out_valid_r;
    assign out_u = out_u_r;
    assign out_v = out_v_r;
    assign out_y0 = out_y0_r;
    assign out_y1 = out_y1_r;
    assign out_sof = out_sof_r;
    assign out_eol = out_eol_r;
    assign out_eof = out_eof_r;
    
endmodule