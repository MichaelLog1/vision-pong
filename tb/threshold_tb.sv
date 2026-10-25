`timescale 1 ns / 10 ps

module threshold_tb #(
    int unsigned WIDTH = 320,
    int unsigned HEIGHT = 240,
    int unsigned N = 4
);
    localparam TOTAL_BYTES = WIDTH*HEIGHT*N/2;

    logic clk = 1'b0;
    logic rst_n;
    logic [7:0] in_u;
    logic [7:0] in_v;
    logic [7:0] in_y0;
    logic [7:0] in_y1;
    logic [7:0] in_u_min;
    logic [7:0] in_u_max;
    logic [7:0] in_v_min;
    logic [7:0] in_v_max;
    logic in_luma_gate_en;
    logic [7:0] in_y_min;
    logic in_sof;
    logic in_eol;
    logic in_eof;
    logic in_valid;
    logic out_mask;
    logic out_sof;
    logic out_eol;
    logic out_eof;
    logic out_valid;

    logic [7:0] conf [6];
    logic [31:0] stimulus [TOTAL_BYTES];
    logic expected [TOTAL_BYTES];
    int errors = 0;

    threshold DUT (
        .clk(clk),
        .rst_n(rst_n),
        .in_u(in_u),
        .in_v(in_v),
        .in_y0(in_y0),
        .in_y1(in_y1),
        .in_u_min(in_u_min),
        .in_u_max(in_u_max),
        .in_v_min(in_v_min),
        .in_v_max(in_v_max),
        .in_luma_gate_en(in_luma_gate_en),
        .in_y_min(in_y_min),
        .in_sof(in_sof),
        .in_eol(in_eol),
        .in_eof(in_eof),
        .in_valid(in_valid),
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
        $readmemh("./rtl/mem/threshold_stimulus.mem", stimulus);
        $readmemh("./rtl/mem/threshold_expected.mem", expected);
        $readmemh("./rtl/mem/threshold_config.mem", conf);
    end

    initial begin : driver
        $timeformat(-9, 0, " ns");
        rst_n <= 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n <= 1'b1;

        in_u_min <= conf[0];
        in_u_max <= conf[1];
        in_v_min <= conf[2];
        in_v_max <= conf[3];
        in_y_min <= conf[4];
        in_luma_gate_en <= conf[5];

        for (int i = 0; i < TOTAL_BYTES; i++) begin
            if (i == 0) begin
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

            in_u <= stimulus[i][31:24];
            in_y0 <= stimulus[i][23:16];
            in_v <= stimulus[i][15:8];
            in_y1 <= stimulus[i][7:0];
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

    // sof, eol, and eof timings
    assert property (@(posedge clk) disable iff (!rst_n) (in_sof && in_valid) |=> out_sof);
    assert property (@(posedge clk) disable iff (!rst_n) (in_eol && in_valid) |=> out_eol);
    assert property (@(posedge clk) disable iff (!rst_n) (in_eof && in_valid) |=> out_eof);

    assert property (@(posedge clk) disable iff (!rst_n) out_sof |-> out_valid);
    assert property (@(posedge clk) disable iff (!rst_n) out_eol |-> out_valid);
    assert property (@(posedge clk) disable iff (!rst_n) out_eof |-> out_valid);

endmodule