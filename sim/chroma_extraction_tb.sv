`timescale 1 ns / 10 ps

module chroma_extraction_tb #(
    int unsigned WIDTH = 320,
    int unsigned HEIGHT = 240,
    int unsigned N = 4
);
    localparam TOTAL_BYTES = WIDTH*2*HEIGHT*N;

    logic       clk = 1'b0;
    logic       rst_n;
    logic       in_valid;
    logic [7:0] in_data;
    logic       in_sof;
    logic       in_eol;
    logic       in_eof;
    logic       out_valid;
    logic [7:0] out_u;
    logic [7:0] out_v;
    logic [7:0] out_y0;
    logic [7:0] out_y1;
    logic       out_sof;
    logic       out_eol;
    logic       out_eof;

    logic [7:0] stimulus [TOTAL_BYTES];
    int errors = 0;

    chroma_extraction DUT (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_data(in_data),
        .in_sof(in_sof),
        .in_eol(in_eol),
        .in_eof(in_eof),
        .out_valid(out_valid),
        .out_u(out_u),
        .out_v(out_v),
        .out_y0(out_y0),
        .out_y1(out_y1),
        .out_sof(out_sof),
        .out_eol(out_eol),
        .out_eof(out_eof)
    );

    initial begin : generate_clock
        forever #5 clk <= ~clk;
    end

    initial begin
        $readmemh("./rtl/mem/chroma_extraction_stimulus.mem", stimulus);
    end

    initial begin : driver
        $timeformat(-9, 0, " ns");
        rst_n <= 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n <= 1'b1;

        for (int i = 0; i < TOTAL_BYTES; i++) begin
            if (i == 0) begin
                in_sof <= 1'b1;
            end else begin
                in_sof <= 1'b0;
            end

            if ((i + 1) % (WIDTH * 2) == 0) begin
                in_eol <= 1'b1;
            end else begin
                in_eol <= 1'b0;
            end
            
            if ((i + 1) % (WIDTH*2*HEIGHT) == 0) begin
                in_eof <= 1'b1;
            end else begin
                in_eof <= 1'b0;
            end

            in_data <= stimulus[i];
            in_valid <= 1'b1;
            @(posedge clk);
            in_valid <= 1'b0;

            repeat ($urandom_range(20, 30)) @(posedge clk);  // wait some time
        end
    end

    initial begin : scoreboard_main
         @(posedge rst_n);

        for (int i = 0; i < (TOTAL_BYTES / 4); i++) begin
            do @(posedge clk); while (!out_valid);
            if (out_u !== { stimulus[i*4] }) errors++;
            if (out_y0 !== { stimulus[i*4+1] }) errors++;
            if (out_v !== { stimulus[i*4+2] }) errors++;
            if (out_y1 !== { stimulus[i*4+3] }) errors++;
        end

        if (errors == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL: %0d errors", errors);
        end

        disable generate_clock;
    end

    // sof, eol, and eof timings
    assert property (@(posedge clk) disable iff (!rst_n) (in_sof && in_valid) ##1 in_valid[-> 3] |=> out_sof);
    assert property (@(posedge clk) disable iff (!rst_n) (in_eol && in_valid) |=> out_eol);
    assert property (@(posedge clk) disable iff (!rst_n) (in_eof && in_valid) |=> out_eof);

    assert property (@(posedge clk) disable iff (!rst_n) out_sof |-> out_valid);
    assert property (@(posedge clk) disable iff (!rst_n) out_eol |-> out_valid);
    assert property (@(posedge clk) disable iff (!rst_n) out_eof |-> out_valid);

endmodule