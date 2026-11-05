module outputs #(
    parameter int unsigned FRAME_WIDTH = 160,
    parameter int unsigned FRAME_HEIGHT = 240,
    parameter int unsigned DOWN_COUNT = 200,
    parameter int unsigned CLK_PER_US = 100, // assume 100 MHz clock for now
    localparam int unsigned SUM_X_WIDTH = $clog2(FRAME_HEIGHT*FRAME_WIDTH*(FRAME_WIDTH-1)+1),
    localparam int unsigned SUM_Y_WIDTH = $clog2(FRAME_WIDTH*FRAME_HEIGHT*(FRAME_HEIGHT-1)/2+1),
    localparam int unsigned COUNT_WIDTH = $clog2(FRAME_WIDTH*FRAME_HEIGHT+1),
    localparam int unsigned DOWN_COUNT_WIDTH = $clog2(DOWN_COUNT+1)
) (
    input logic clk,
    input logic rst_n,
    input logic acc_valid1,
    input logic acc_valid2,
    input logic [SUM_X_WIDTH-1:0] sum_x1,
    input logic [SUM_Y_WIDTH-1:0] sum_y1,
    input logic [COUNT_WIDTH-1:0] count1,
    input logic [15:0] min_blob1,
    input logic [SUM_X_WIDTH-1:0] sum_x2,
    input logic [SUM_Y_WIDTH-1:0] sum_y2,
    input logic [COUNT_WIDTH-1:0] count2,
    input logic [15:0] min_blob2,
    input logic frame_end,
    output logic [15:0] p1_cnt,
    output logic [15:0] p1_cx,
    output logic [15:0] p1_cy,
    output logic [15:0] p2_cnt,
    output logic [15:0] p2_cx,
    output logic [15:0] p2_cy,
    output logic p1_valid,
    output logic p2_valid,
    output logic [7:0] frame_count,
    output logic drdy,
    output logic [15:0] latency
);

    logic x1_divz;
    logic y1_divz;
    logic x2_divz;
    logic y2_divz;
    logic x1_done;
    logic y1_done;
    logic x2_done;
    logic y2_done;
    logic [SUM_X_WIDTH-1:0] x1_div_out;
    logic [SUM_Y_WIDTH-1:0] y1_div_out;
    logic [SUM_X_WIDTH-1:0] x2_div_out;
    logic [SUM_Y_WIDTH-1:0] y2_div_out;

    logic x1_done_sticky;
    logic y1_done_sticky;
    logic x2_done_sticky;
    logic y2_done_sticky;

    logic [DOWN_COUNT_WIDTH-1:0] down_count_r;
    logic [$clog2(CLK_PER_US)-1:0] latency_prescaler_r;
    logic [15:0] latency_count_r;

    // outputs
    logic [15:0] p1_cnt_r;
    logic [15:0] p1_cx_r;
    logic [15:0] p1_cy_r;
    logic [15:0] p2_cnt_r;
    logic [15:0] p2_cx_r;
    logic [15:0] p2_cy_r;
    logic p1_valid_r;
    logic p2_valid_r;
    logic [7:0] frame_count_r;
    logic drdy_r;
    logic [15:0] latency_r;

    divide #(
        .DIVIDEND_WIDTH(SUM_X_WIDTH),
        .DIVISOR_WIDTH(COUNT_WIDTH)
    ) DIV_X1 (
        .clk(clk),
        .rst_n(rst_n),
        .in_dividend(sum_x1),
        .in_divisor(count1),
        .in_valid(acc_valid1),
        .out_quotient(x1_div_out),
        .out_divz(x1_divz),
        .out_done(x1_done)
    );

    divide #(
        .DIVIDEND_WIDTH(SUM_Y_WIDTH),
        .DIVISOR_WIDTH(COUNT_WIDTH)
    ) DIV_Y1 (
        .clk(clk),
        .rst_n(rst_n),
        .in_dividend(sum_y1),
        .in_divisor(count1),
        .in_valid(acc_valid1),
        .out_quotient(y1_div_out),
        .out_divz(y1_divz),
        .out_done(y1_done)
    );

    divide #(
        .DIVIDEND_WIDTH(SUM_X_WIDTH),
        .DIVISOR_WIDTH(COUNT_WIDTH)
    ) DIV_X2 (
        .clk(clk),
        .rst_n(rst_n),
        .in_dividend(sum_x2),
        .in_divisor(count2),
        .in_valid(acc_valid2),
        .out_quotient(x2_div_out),
        .out_divz(x2_divz),
        .out_done(x2_done)
    );

    divide #(
        .DIVIDEND_WIDTH(SUM_Y_WIDTH),
        .DIVISOR_WIDTH(COUNT_WIDTH)
    ) DIV_Y2 (
        .clk(clk),
        .rst_n(rst_n),
        .in_dividend(sum_y2),
        .in_divisor(count2),
        .in_valid(acc_valid2),
        .out_quotient(y2_div_out),
        .out_divz(y2_divz),
        .out_done(y2_done)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1_done_sticky <= 1'b0;
            y1_done_sticky <= 1'b0;
            x2_done_sticky <= 1'b0;
            y2_done_sticky <= 1'b0;
            p1_cnt_r <= '0;
            p1_cx_r <= '0;
            p1_cy_r <= '0;
            p2_cnt_r <= '0;
            p2_cx_r <= '0;
            p2_cy_r <= '0;
            p1_valid_r <= 1'b0;
            p2_valid_r <= 1'b0;
            frame_count_r <= '0;
            drdy_r <= 1'b0;
            down_count_r <= '0;
            latency_r <= '0;
            latency_prescaler_r <= CLK_PER_US-1;
            latency_count_r <= '0;
        end else begin

            // latency logic
            if (frame_end) begin
                latency_prescaler_r <= CLK_PER_US-1;
                latency_count_r <= '0;
            end else begin
                if (latency_prescaler_r == 0) begin
                    latency_prescaler_r <= CLK_PER_US-1;
                    latency_count_r <= (latency_count_r == 16'hFFFF) ? latency_count_r : latency_count_r + 1;
                end else begin
                    latency_prescaler_r <= latency_prescaler_r - 1;
                end
            end


            x1_done_sticky <= x1_done_sticky || x1_done;
            y1_done_sticky <= y1_done_sticky || y1_done;
            x2_done_sticky <= x2_done_sticky || x2_done;
            y2_done_sticky <= y2_done_sticky || y2_done;

            if (x1_done_sticky && y1_done_sticky && x2_done_sticky && y2_done_sticky) begin
                // publish
                x1_done_sticky <= 1'b0;
                y1_done_sticky <= 1'b0;
                x2_done_sticky <= 1'b0;
                y2_done_sticky <= 1'b0;

                // increment frame count
                frame_count_r <= frame_count_r + 1;

                // publish latency
                latency_r <= latency_count_r;

                if ((count1 >= min_blob1) && (count1 != 0)) begin
                    p1_cx_r <= x1_div_out[15:0];
                    p1_cy_r <= y1_div_out[15:0];
                    p1_valid_r <= 1'b1;
                end else begin
                    p1_valid_r <= 1'b0;
                end

                if ((count2 >= min_blob2) && (count2 != 0)) begin
                    p2_cx_r <= x2_div_out[15:0];
                    p2_cy_r <= y2_div_out[15:0];
                    p2_valid_r <= 1'b1;
                end else begin
                    p2_valid_r <= 1'b0;
                end

                p1_cnt_r <= count1;
                p2_cnt_r <= count2;

                // load a down counter for drdy
                down_count_r <= DOWN_COUNT;

            end

            if (down_count_r == 0) begin
                drdy_r <= 1'b0;
            end else begin
                drdy_r <= 1'b1;
                down_count_r <= down_count_r - 1;
            end
        end
    end

    assign p1_cnt = p1_cnt_r;
    assign p1_cx = p1_cx_r;
    assign p1_cy = p1_cy_r;
    assign p2_cnt = p2_cnt_r;
    assign p2_cx = p2_cx_r;
    assign p2_cy = p2_cy_r;
    assign p1_valid = p1_valid_r;
    assign p2_valid = p2_valid_r;
    assign frame_count = frame_count_r;
    assign drdy = drdy_r;
    assign latency = latency_r;

endmodule