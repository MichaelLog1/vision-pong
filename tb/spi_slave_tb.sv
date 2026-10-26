module spi_slave_tb #(
    int unsigned SCLK_HALF_PERIOD = 5
);

    logic clk = 1'b0;
    logic rst_n;
    logic spi_sclk;
    logic spi_mosi;
    logic spi_cs_n;
    logic spi_miso;
    logic spi_miso_oe;
    logic drdy;
    logic cfg_apply;
    logic p1_valid;
    logic p2_valid;
    logic [7:0] frame_count;
    logic [15:0] p1_cnt;
    logic [15:0] p1_cx;
    logic [15:0] p1_cy;
    logic [15:0] p2_cnt;
    logic [15:0] p2_cx;
    logic [15:0] p2_cy;
    logic [7:0] probe_u;
    logic [7:0] probe_v;
    logic [7:0] probe_y;
    logic thumbnail_new_frame;
    logic [1:0] thumbnail_stage_sel;
    logic [7:0] thumbnail_data;
    logic [15:0] p1_bbox_x_min;
    logic [15:0] p1_bbox_y_min;
    logic [15:0] p1_bbox_x_max;
    logic [15:0] p1_bbox_y_max;
    logic [15:0] p2_bbox_x_min;
    logic [15:0] p2_bbox_y_min;
    logic [15:0] p2_bbox_x_max;
    logic [15:0] p2_bbox_y_max;
    logic [7:0] p1_u_min;
    logic [7:0] p1_u_max;
    logic [7:0] p1_v_min;
    logic [7:0] p1_v_max;
    logic [7:0] p1_y_min;
    logic [7:0] p2_u_min;
    logic [7:0] p2_u_max;
    logic [7:0] p2_v_min;
    logic [7:0] p2_v_max;
    logic [7:0] p2_y_min;
    logic [15:0] p1_min_blob;
    logic [15:0] p2_min_blob;
    logic erode_en;
    logic [1:0] debug_stage_sel;

    int errors = 0;

    spi_slave DUT (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),
        .spi_miso(spi_miso),
        .spi_miso_oe(spi_miso_oe),
        .drdy(drdy),
        .cfg_apply(cfg_apply),
        .p1_valid(p1_valid),
        .p2_valid(p2_valid),
        .frame_count(frame_count),
        .p1_cnt(p1_cnt),
        .p1_cx(p1_cx),
        .p1_cy(p1_cy),
        .p2_cnt(p2_cnt),
        .p2_cx(p2_cx),
        .p2_cy(p2_cy),
        .probe_u(probe_u),
        .probe_v(probe_v),
        .probe_y(probe_y),
        .thumbnail_new_frame(thumbnail_new_frame),
        .thumbnail_stage_sel(thumbnail_stage_sel),
        .thumbnail_data(thumbnail_data),
        .p1_bbox_x_min(p1_bbox_x_min),
        .p1_bbox_y_min(p1_bbox_y_min),
        .p1_bbox_x_max(p1_bbox_x_max),
        .p1_bbox_y_max(p1_bbox_y_max),
        .p2_bbox_x_min(p2_bbox_x_min),
        .p2_bbox_y_min(p2_bbox_y_min),
        .p2_bbox_x_max(p2_bbox_x_max),
        .p2_bbox_y_max(p2_bbox_y_max),
        .p1_u_min(p1_u_min),
        .p1_u_max(p1_u_max),
        .p1_v_min(p1_v_min),
        .p1_v_max(p1_v_max),
        .p1_y_min(p1_y_min),
        .p2_u_min(p2_u_min),
        .p2_u_max(p2_u_max),
        .p2_v_min(p2_v_min),
        .p2_v_max(p2_v_max),
        .p2_y_min(p2_y_min),
        .p1_min_blob(p1_min_blob),
        .p2_min_blob(p2_min_blob),
        .erode_en(erode_en),
        .debug_stage_sel(debug_stage_sel)
    );

    initial begin : generate_clock
        forever #5 clk <= ~clk;
    end

    task automatic do_reset();
        rst_n <= 1'b0;
        spi_cs_n <= 1'b1;
        spi_sclk <= 1'b0;
        spi_mosi <= 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n <= 1'b1;
    endtask

    task automatic spi_cs_assert();
        @(posedge clk);
        spi_cs_n <= 1'b0;
        repeat (5) @(posedge clk);
    endtask

    task automatic spi_cs_deassert();
        @(posedge clk);
        spi_cs_n <= 1'b1;
        repeat (5) @(posedge clk);
    endtask

    task automatic spi_transfer_byte(input logic [7:0] bin, output logic [7:0] bout);
        for (int i = 0; i < 8; i++) begin
            spi_transfer_bit(bin[7-i], bout[7-i]);
        end
    endtask

    task automatic spi_transfer_bit(input logic bin, output logic bout);
        @(posedge clk);
        spi_sclk <= 1'b0;
        spi_mosi <= bin;
        repeat (SCLK_HALF_PERIOD) @(posedge clk);
        spi_sclk <= 1'b1;
        bout = spi_miso;
        repeat (SCLK_HALF_PERIOD) @(posedge clk);
        spi_sclk <= 1'b0;
    endtask

    task automatic spi_write(input logic [6:0] addr, input logic [7:0] data[$]);
        logic [7:0] rx;
        spi_cs_assert();
        spi_transfer_byte({ 1'b1, addr }, rx);
        for (int i = 0; i < data.size(); i++) begin
            spi_transfer_byte(data[i], rx);
        end
        spi_cs_deassert();
    endtask

    task automatic spi_read(input int num_bytes, input logic [6:0] addr, output logic [7:0] data[$]);
        logic [7:0] rx;
        spi_cs_assert();
        spi_transfer_byte({ 1'b0, addr }, rx);
        for (int i = 0; i < num_bytes; i++) begin
            spi_transfer_byte(8'h00, rx);
            data.push_back(rx);
        end
        spi_cs_deassert();
    endtask

    initial begin : driver
        logic [7:0] data[$];
        $timeformat(-9, 0, " ns");

        cfg_apply <= 1'b0;
        probe_u <= '0;
        probe_v <= '0;
        probe_y <= '0;
        p1_valid <= 1'b0;
        p2_valid <= 1'b0;
        frame_count <= '0;
        p1_cnt <= '0;
        p1_cx <= '0;
        p1_cy <= '0;
        p2_cnt <= '0;
        p2_cx <= '0;
        p2_cy <= '0;
        thumbnail_new_frame <= 1'b0;
        thumbnail_stage_sel <= '0;
        thumbnail_data <= '0;
        p1_bbox_x_min <= '0;
        p1_bbox_y_min <= '0;
        p1_bbox_x_max <= '0;
        p1_bbox_y_max <= '0;
        p2_bbox_x_min <= '0;
        p2_bbox_y_min <= '0;
        p2_bbox_x_max <= '0;
        p2_bbox_y_max <= '0;
        do_reset();

        // test 1: read id back
        spi_read(1, 7'h3F, data);
        if (data[0] !== 8'hA5) $error("ID didn't match expected value.");
        data.delete();

        // test 2: write to a threshold register then read back
        data.push_back(8'd5);
        spi_write(7'h20, data);
        data.delete();
        spi_read(1, 7'h20, data);
        if (data[0] !== 8'd5) $error("error.");
        data.delete();

        // test 3: multi bit write then readback
        data.push_back(8'h74);
        data.push_back(8'hD1);
        data.push_back(8'h11);
        data.push_back(8'h5E);
        spi_write(7'h20, data);
        data.delete();
        spi_read(4, 7'h20, data);
        if (data[0] !== 8'h74) $error("multi R/W test error 1.");
        if (data[1] !== 8'hD1) $error("multi R/W test error 2.");
        if (data[2] !== 8'h11) $error("multi R/W test error 3.");
        if (data[3] !== 8'h5E) $error("multi R/W test error 4.");
        data.delete();

        // TODO: drive all inputs and read them back.
            

        $display("Tests complete.");

        // done
        disable generate_clock;
    end

endmodule