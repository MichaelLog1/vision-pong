module accumulate #(
    int unsigned WIDTH = 160,
    int unsigned HEIGHT = 240,
    localparam MAX_SUM_X = HEIGHT*WIDTH*(WIDTH-1)+1,
    localparam MAX_SUM_Y = WIDTH*HEIGHT*(HEIGHT-1)/2+1
) (
    input logic clk,
    input logic rst_n,
    input logic in_mask,
    input logic in_sof,
    input logic in_eol,
    input logic in_eof,
    input logic in_valid,
    output logic [$clog2(MAX_SUM_X)-1:0] out_sum_x,
    output logic [$clog2(MAX_SUM_Y)-1:0] out_sum_y,
    output logic [$clog2(WIDTH*HEIGHT+1)-1:0] out_pixel_count,
    output logic out_valid,
    output logic [15:0] x_min,
    output logic [15:0] y_min,
    output logic [15:0] x_max,
    output logic [15:0] y_max
);

    typedef enum logic {
        IDLE,
        ACCUMULATE
    } state_t;
    state_t state_r;

    logic [$clog2(WIDTH)-1:0] col_r;
    logic [$clog2(HEIGHT)-1:0] row_r;
    logic [$clog2(MAX_SUM_X)-1:0] sum_x_r;
    logic [$clog2(MAX_SUM_Y)-1:0] sum_y_r;
    logic [$clog2(WIDTH*HEIGHT+1)-1:0] pixel_count_r;
    logic out_valid_r;
    logic [$clog2(WIDTH)-1:0] col_min_r;
    logic [$clog2(HEIGHT)-1:0] row_min_r; 
    logic [$clog2(WIDTH)-1:0] col_max_r;
    logic [$clog2(HEIGHT)-1:0] row_max_r;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_r <= IDLE;
            col_r <= '0;
            row_r <= '0;
            sum_x_r <= '0;
            sum_y_r <= '0;
            pixel_count_r <= '0;
            out_valid_r <= '0;
            col_min_r <= WIDTH-1;
            row_min_r <= HEIGHT-1;
            col_max_r <= 0;
            row_max_r <= 0;
        end else begin
            out_valid_r <= 1'b0;
            case (state_r)
                IDLE: begin
                    if (in_sof && in_valid) begin
                        state_r <= ACCUMULATE;
                        col_r <= 1;
                        row_r <= 0;
                        sum_x_r <= '0;
                        sum_y_r <= '0;

                        // initialize bounding box bounds
                        col_min_r <= WIDTH-1;
                        row_min_r <= HEIGHT-1;
                        col_max_r <= 0;
                        row_max_r <= 0;

                        if (in_mask) begin
                            pixel_count_r <= 1;
                            col_min_r <= '0;
                            row_min_r <= '0;
                        end else begin
                            pixel_count_r <= '0;
                        end
                    end
                end

                ACCUMULATE: begin
                    if (in_valid) begin

                        if (in_mask) begin
                            sum_x_r <= sum_x_r + { col_r, 1'b0 }; // multiply by 2
                            sum_y_r <= sum_y_r + row_r;
                            pixel_count_r <= pixel_count_r + 1;

                            if (col_r < col_min_r) begin
                                col_min_r <= col_r;
                            end

                            if (col_r > col_max_r) begin
                                col_max_r <= col_r;
                            end

                            // in raster order, the first mask we see will be the min
                            if (pixel_count_r == 0) begin
                                row_min_r <= row_r;
                            end

                            // in raster order, the last mask we see will be the max
                            row_max_r <= row_r;
                        end

                        if (in_eol) begin
                            col_r <= 0;
                            row_r <= row_r + 1;
                        end else begin
                            col_r <= col_r + 1;
                        end

                        if (in_eof) begin
                            out_valid_r <= 1'b1;
                            state_r <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

    assign out_sum_x = sum_x_r;
    assign out_sum_y = sum_y_r;
    assign out_pixel_count = pixel_count_r;
    assign out_valid = out_valid_r;
    assign x_min = col_min_r << 1;
    assign y_min = row_min_r;
    assign x_max = (col_max_r << 1) + 1;
    assign y_max = row_max_r;
endmodule