module divide #(
    parameter int unsigned DIVIDEND_WIDTH = 4,
    parameter int unsigned DIVISOR_WIDTH = 2
) (
    input logic clk,
    input logic rst_n,
    input logic [DIVIDEND_WIDTH-1:0] in_dividend,
    input logic [DIVISOR_WIDTH-1:0] in_divisor,
    input logic in_valid,
    output logic [DIVIDEND_WIDTH-1:0] out_quotient,
    output logic out_divz,
    output logic out_done
);

    if (DIVIDEND_WIDTH < 2) $fatal(1, "Divisor width must be >= 2, got %0d", DIVISOR_WIDTH);

    localparam ITERATION_COUNT = DIVIDEND_WIDTH;

    typedef enum logic {
        IDLE,
        DIVIDE
    } state_t;
    state_t state_r, next_state;

    logic [DIVIDEND_WIDTH-1:0] dividend_r, next_dividend, remainder_r, next_remainder;
    logic [DIVISOR_WIDTH-1:0] divisor_r, next_divisor;
    logic [DIVIDEND_WIDTH-1:0] quotient_r, next_quotient;
    logic [$clog2(ITERATION_COUNT)-1:0] count_r, next_count;
    logic out_divz_r, next_out_divz;
    logic out_done_r, next_out_done;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_r <= IDLE;
            dividend_r <= '0;
            divisor_r <= '0;
            remainder_r <= '0;
            quotient_r <= '0;
            count_r <= '0;
            out_divz_r <= '0;
            out_done_r <= '0;
        end else begin
            state_r <= next_state;
            dividend_r <= next_dividend;
            divisor_r <= next_divisor;
            remainder_r <= next_remainder;
            quotient_r <= next_quotient;
            count_r <= next_count;
            out_divz_r <= next_out_divz;
            out_done_r <= next_out_done;
        end
    end

    always_comb begin
        // defaults to remove latches
        next_state = state_r;
        next_dividend = dividend_r;
        next_divisor = divisor_r;
        next_remainder = remainder_r;
        next_quotient = quotient_r;
        next_count = count_r;
        next_out_divz = out_divz_r;
        next_out_done = 1'b0;

        case (state_r)
            IDLE: begin
                if (in_valid) begin
                    // prevent divide by 0
                    if (in_divisor == 0) begin
                        next_state = IDLE;
                        next_quotient = '0;
                        next_out_divz = 1'b1;
                        next_out_done = 1'b1;
                    end else begin
                        next_state = DIVIDE;
                        next_dividend = in_dividend;
                        next_divisor = in_divisor;
                        next_count = '0;
                        next_remainder = '0;
                        next_out_divz = 1'b0;
                    end
                end
            end

            DIVIDE: begin
                next_count = count_r + 1;
                // shift in dividend MSB to remainder
                next_remainder = { remainder_r[DIVIDEND_WIDTH-2:0], dividend_r[DIVIDEND_WIDTH-1] };
                next_dividend = { dividend_r[DIVIDEND_WIDTH-2:0], 1'b0};

                if (next_remainder >= divisor_r) begin
                    // update remainder
                    next_remainder = next_remainder - divisor_r;
                    next_quotient = { quotient_r[DIVIDEND_WIDTH-2:0], 1'b1 };
                end else begin
                    next_quotient = { quotient_r[DIVIDEND_WIDTH-2:0], 1'b0 };
                end

                if (count_r == ITERATION_COUNT - 1) begin
                    next_state = IDLE;
                    next_out_done = 1'b1;
                end
            end
        endcase
    end
    
    assign out_quotient = quotient_r;
    assign out_divz = out_divz_r;
    assign out_done = out_done_r;


    
endmodule