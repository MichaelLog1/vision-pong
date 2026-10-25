`timescale 1 ns / 10 ps

module erode_tb #(
    int unsigned WIDTH = 320,
    int unsigned HEIGHT = 240,
    int unsigned N = 4
);
    localparam TOTAL_BYTES = WIDTH*HEIGHT*N/2;

    logic clk = 1'b0;
    logic rst_n;
    logic in_mask;
    logic in_sof;
    logic in_eol;
    logic in_eof;
    logic in_valid;
    logic in_ready;
    logic erode_en;
    logic out_mask;
    logic out_sof;
    logic out_eol;
    logic out_eof;
    logic out_valid;

    logic conf [1];
    logic stimulus [TOTAL_BYTES];
    logic expected [TOTAL_BYTES];
    int errors = 0;

    erode #(
        .WIDTH(WIDTH / 2),
        .HEIGHT(HEIGHT)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .in_mask(in_mask),
        .in_sof(in_sof),
        .in_eol(in_eol),
        .in_eof(in_eof),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .erode_en(erode_en),
        .out_mask(out_mask),
        .out_sof(out_sof),
        .out_eol(out_eol),
        .out_eof(out_eof),
        .out_valid(out_valid)
    );

    initial begin : generate_clock
        forever #5 clk <= ~clk;
    end

    initial begin
        $readmemh("./rtl/mem/erode_stimulus.mem", stimulus);
        $readmemh("./rtl/mem/erode_expected.mem", expected);
        $readmemh("./rtl/mem/erode_config.mem", conf);
    end

    initial begin : driver
        $timeformat(-9, 0, " ns");
        rst_n <= 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n <= 1'b1;

        erode_en <= conf[0];

        for (int i = 0; i < TOTAL_BYTES; i++) begin
            do @(posedge clk); while (!in_ready); 

            if (i % (WIDTH/2*HEIGHT) == 0) begin
                in_sof <= 1'b1;
            end else begin
                in_sof <= 1'b0;
            end

            if ((i + 1) % (WIDTH / 2) == 0) begin
                in_eol <= 1'b1;
            end else begin
                in_eol <= 1'b0;
            end
            
            if ((i + 1) % (WIDTH/2*HEIGHT) == 0) begin
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

        for (int i = 0; i < TOTAL_BYTES; i++) begin
            do @(posedge clk); while (!out_valid);
            assert (out_sof == (i % (WIDTH/2*HEIGHT) == 0));
            assert (out_eol == (i % (WIDTH/2) == WIDTH/2 - 1));
            assert (out_eof == (i % (WIDTH/2*HEIGHT) == WIDTH/2*HEIGHT - 1));
            if (out_mask !== expected[i]) errors++;
        end

        if (errors == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL: %0d errors", errors);
            $fatal;
        end

        disable generate_clock;
    end

    assert property (@(posedge clk) disable iff (!rst_n) out_sof |-> out_valid);
    assert property (@(posedge clk) disable iff (!rst_n) out_eol |-> out_valid);
    assert property (@(posedge clk) disable iff (!rst_n) out_eof |-> out_valid);

endmodule