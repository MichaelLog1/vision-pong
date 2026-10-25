`timescale 1 ns / 10 ps

module accumulate_tb #(
    int unsigned WIDTH = 320,
    int unsigned HEIGHT = 240,
    int unsigned N = 4
);
    localparam WIDTH2 = WIDTH/2;
    localparam TOTAL_BYTES = WIDTH2*HEIGHT*N;
    localparam MAX_SUM_X = HEIGHT*WIDTH2*(WIDTH2-1)+1;
    localparam MAX_SUM_Y = WIDTH2*HEIGHT*(HEIGHT-1)/2+1;

    logic clk = 1'b0;
    logic rst_n;
    logic in_mask;
    logic in_sof;
    logic in_eol;
    logic in_eof;
    logic in_valid;
    logic [$clog2(MAX_SUM_X)-1:0] out_sum_x;
    logic [$clog2(MAX_SUM_Y)-1:0] out_sum_y;
    logic [$clog2(WIDTH2*HEIGHT+1)-1:0] out_pixel_count;
    logic out_valid;

    logic stimulus [TOTAL_BYTES];
    logic [$clog2(MAX_SUM_X) + $clog2(MAX_SUM_Y) + $clog2(WIDTH2*HEIGHT+1)-1:0] expected [N];
    int errors = 0;

    accumulate #(
        .WIDTH(WIDTH2),
        .HEIGHT(HEIGHT)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .in_mask(in_mask),
        .in_sof(in_sof),
        .in_eol(in_eol),
        .in_eof(in_eof),
        .in_valid(in_valid),
        .out_sum_x(out_sum_x),
        .out_sum_y(out_sum_y),
        .out_pixel_count(out_pixel_count),
        .out_valid(out_valid)
    );

    initial begin : generate_clock
        forever #5 clk <= ~clk;
    end

    initial begin
        $readmemh("./rtl/mem/accumulate_stimulus.mem", stimulus);
        $readmemh("./rtl/mem/accumulate_expected.mem", expected);
    end

    initial begin : driver
        $timeformat(-9, 0, " ns");
        rst_n <= 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n <= 1'b1;

        for (int i = 0; i < TOTAL_BYTES; i++) begin

            if (i % (WIDTH2*HEIGHT) == 0) begin
                in_sof <= 1'b1;
            end else begin
                in_sof <= 1'b0;
            end

            if ((i + 1) % (WIDTH2) == 0) begin
                in_eol <= 1'b1;
            end else begin
                in_eol <= 1'b0;
            end
            
            if ((i + 1) % (WIDTH2*HEIGHT) == 0) begin
                in_eof <= 1'b1;
            end else begin
                in_eof <= 1'b0;
            end

            in_mask <= stimulus[i];
            in_valid <= 1'b1;
            @(posedge clk);
            in_valid <= 1'b0;
            repeat ($urandom_range(20, 30)) @(posedge clk);  // wait some time
        end
    end

    initial begin : scoreboard_main
        @(posedge rst_n);

        for (int i = 0; i < N; i++) begin
            do @(posedge clk); while (!out_valid);
            if (out_pixel_count !== expected[i][$clog2(MAX_SUM_X) + $clog2(MAX_SUM_Y) + $clog2(WIDTH2*HEIGHT+1)-1:$clog2(MAX_SUM_X) + $clog2(MAX_SUM_Y)]) errors++;
            if (out_sum_x !== expected[i][$clog2(MAX_SUM_X) + $clog2(MAX_SUM_Y)-1:$clog2(MAX_SUM_Y)]) errors++;
            if (out_sum_y !== expected[i][$clog2(MAX_SUM_Y)-1:0]) errors++;
        end

        if (errors == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL: %0d errors", errors);
            $fatal;
        end

        disable generate_clock;
    end
endmodule