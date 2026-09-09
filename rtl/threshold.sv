module threshold (
    input logic clk,
    input logic rst_n,
    input logic [7:0] in_u,
    input logic [7:0] in_v,
    input logic [7:0] in_y0,
    input logic [7:0] in_y1,
    input logic [7:0] in_u_min,
    input logic [7:0] in_u_max,
    input logic [7:0] in_v_min,
    input logic [7:0] in_v_max,
    input logic in_luma_gate_en,
    input logic [7:0] in_y_min,
    input logic in_sof,
    input logic in_eol,
    input logic in_eof,
    input logic in_valid,
    output logic out_mask,
    output logic out_sof,
    output logic out_eol,
    output logic out_eof,
    output logic out_valid
);

// registers
logic out_mask_r;
logic out_valid_r;
logic out_sof_r;
logic out_eol_r;
logic out_eof_r;

logic u_in_range;
logic v_in_range;
logic y_in_range;
assign u_in_range = ((in_u >= in_u_min) && (in_u <= in_u_max));
assign v_in_range = ((in_v >= in_v_min) && (in_v <= in_v_max));
assign y_in_range = in_luma_gate_en ? ((in_y0 >= in_y_min) && (in_y1 >= in_y_min)) : 1'b1;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        out_mask_r <= 1'b0;
        out_valid_r <= 1'b0;
        out_sof_r <= 1'b0;
        out_eol_r <= 1'b0;
        out_eof_r <= 1'b0;
    end else begin
        out_valid_r <= 1'b0;
        out_sof_r <= 1'b0;
        out_eol_r <= 1'b0;
        out_eof_r <= 1'b0;
        if (in_valid) begin
            out_valid_r <= 1'b1;
            out_mask_r <= u_in_range && v_in_range && y_in_range;
            out_sof_r <= in_sof;
            out_eol_r <= in_eol;
            out_eof_r <= in_eof;
        end
    end
end

assign out_mask = out_mask_r;
assign out_valid = out_valid_r;
assign out_sof = out_sof_r;
assign out_eol = out_eol_r;
assign out_eof = out_eof_r;
    
endmodule