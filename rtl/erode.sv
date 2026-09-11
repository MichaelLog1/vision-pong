module erode #(
    int unsigned WIDTH = 160,
    int unsigned HEIGHT = 240
) (
    input logic clk,
    input logic rst_n,
    input logic in_mask,
    input logic in_sof,
    input logic in_eol,
    input logic in_eof,
    input logic in_valid,
    output logic in_ready,
    input logic erode_en,
    output logic out_mask,
    output logic out_sof,
    output logic out_eol,
    output logic out_eof,
    output logic out_valid
);
    localparam SHIFT_LEN = (2*WIDTH + 3);
    
    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        STREAM,
        DRAIN
    } state_t;
    state_t state_r, next_state;

    logic out_mask_r, next_out_mask;
    logic out_valid_r, next_out_valid;
    logic [$clog2(WIDTH)-1:0] col_r, next_col;
    logic [$clog2(HEIGHT)-1:0] row_r, next_row;
    logic [$clog2(WIDTH)-1:0] setup_cnt_r, next_setup_cnt;
    logic [SHIFT_LEN-1:0] shift_r, next_shift;
    logic out_sof_r, next_sof;
    logic out_eol_r, next_eol;
    logic out_eof_r, next_eof;
    logic erode_en_r, next_erode_en;

    logic is_border;
    logic and_of_9;

    // register process
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_r <= IDLE;
            out_mask_r <= 1'b0;
            out_valid_r <= 1'b0;
            shift_r <= '0;
            row_r <= '0;
            col_r <= '0;
            setup_cnt_r <= '0;
            out_sof_r <= '0;
            out_eol_r <= '0;
            out_eof_r <= '0;
            erode_en_r <= '0;
        end else begin
            state_r <= next_state;
            out_mask_r <= next_out_mask;
            out_valid_r <= next_out_valid;
            shift_r <= next_shift;
            col_r <= next_col;
            row_r <= next_row;
            setup_cnt_r <= next_setup_cnt;
            out_sof_r <= next_sof;
            out_eol_r <= next_eol;
            out_eof_r <= next_eof;
            erode_en_r <= next_erode_en;
        end
    end

    assign is_border = (row_r == 0) || (row_r == HEIGHT-1) || (col_r == 0) || (col_r == WIDTH-1);
    assign and_of_9 = next_shift[0] && 
                      next_shift[1] && 
                      next_shift[2] && 
                      next_shift[WIDTH] && 
                      next_shift[WIDTH+1] && 
                      next_shift[WIDTH+2] && 
                      next_shift[2*WIDTH] && 
                      next_shift[2*WIDTH+1] && 
                      next_shift[2*WIDTH+2];

    always_comb begin
        next_state = state_r;
        next_out_mask = out_mask_r;
        next_out_valid = 1'b0;
        next_shift = shift_r;
        next_row = row_r;
        next_col = col_r;
        next_setup_cnt = setup_cnt_r;
        next_sof = 1'b0;
        next_eol = 1'b0;
        next_eof = 1'b0;
        next_erode_en = erode_en_r;

        case (state_r)
            IDLE: begin
                if (in_sof && in_valid) begin
                    next_state = SETUP;
                    next_shift = { shift_r[SHIFT_LEN-2:0], in_mask };
                    next_row = 0;
                    next_col = 0;
                    next_setup_cnt = 0;
                    next_erode_en = erode_en;
                end
            end

            SETUP: begin
                if (in_valid) begin
                    next_setup_cnt = setup_cnt_r + 1;
                    next_shift = { shift_r[SHIFT_LEN-2:0], in_mask };
                    if (setup_cnt_r == WIDTH-1) begin
                        next_state = STREAM;
                    end
                end
            end

            STREAM: begin
                if (in_valid) begin
                    next_col = col_r + 1;
                    next_out_valid = 1'b1;
                    next_shift = { shift_r[SHIFT_LEN-2:0], in_mask };

                    // mask logic
                    next_out_mask = erode_en_r ? (is_border ? 1'b0 : and_of_9) : next_shift[WIDTH + 1];

                    if (col_r == WIDTH-1) begin
                        next_col = '0;
                        next_row = row_r + 1;
                        next_eol = 1'b1;
                    end

                    if (in_eof) begin
                        next_state = DRAIN;
                    end

                    if (col_r == 0 && row_r == 0) begin
                        next_sof = 1'b1;
                    end
                end
            end

            DRAIN: begin
                // this state covers the last WIDTH+1 cycles
                next_shift = { shift_r[SHIFT_LEN-2:0], 1'b0 };

                next_out_mask = erode_en_r ? (is_border ? 1'b0 : and_of_9) : next_shift[WIDTH + 1];
                next_out_valid = 1'b1;

                next_col = col_r + 1;
                if (col_r == WIDTH-1) begin
                    next_col = '0;
                    next_row = row_r + 1;
                    next_eol = 1'b1;
                end
                
                if (col_r == WIDTH-1 && row_r == HEIGHT-1) begin
                    next_state = IDLE;
                    next_eof = 1'b1;
                end
            end
        endcase
    end

    assign out_valid = out_valid_r;
    assign out_mask = out_mask_r;
    assign out_sof = out_sof_r;
    assign out_eol = out_eol_r;
    assign out_eof = out_eof_r;
    assign in_ready = (state_r != DRAIN);

    assert property (@(posedge clk) disable iff (!rst_n) in_valid |-> in_ready);
    assert property (@(posedge clk) disable iff (!rst_n) (in_eof && in_valid) |-> (row_r == HEIGHT-2 && col_r == WIDTH-2 && state_r == STREAM));

endmodule