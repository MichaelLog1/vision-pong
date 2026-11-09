module top #(
    parameter int unsigned WIDTH = 320,
    parameter int unsigned HEIGHT = 240    
) (
    input logic clk,
    input logic rst_n,
    
    // spi
    input logic spi_sclk,
    input logic spi_mosi,
    input logic spi_cs_n,
    output logic spi_miso,

    // camera
    input logic pclk,
    input logic href,
    input logic vsync,
    input logic [7:0] data,

    output logic drdy
);
    localparam int unsigned CHROMA_WIDTH = WIDTH / 2;
    localparam int unsigned WIDTH_BYTES = CHROMA_WIDTH * 4;
    localparam int unsigned MAX_SUM_X = HEIGHT*CHROMA_WIDTH*(CHROMA_WIDTH-1)+1;
    localparam int unsigned MAX_SUM_Y = CHROMA_WIDTH*HEIGHT*(HEIGHT-1)/2+1;

    // register map
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

    logic spi_miso_internal;
    logic spi_miso_oe_internal;

    // capture outputs
    logic capture_valid;
    logic [7:0] capture_data;
    logic capture_sof;
    logic capture_eol;
    logic capture_eof;
    logic cfg_apply;
    logic capture_frame_end;
    logic pipe_rst_n;

    // chroma extraction outputs
    logic chroma_valid;
    logic [7:0] chroma_u;
    logic [7:0] chroma_v;
    logic [7:0] chroma_y0;
    logic [7:0] chroma_y1;
    logic chroma_sof;
    logic chroma_eol;
    logic chroma_eof;
    logic [7:0] chroma_probe_u;
    logic [7:0] chroma_probe_v;
    logic [7:0] chroma_probe_y;

    // p1 threshold outputs
    logic threshold_p1_mask;
    logic threshold_p1_sof;
    logic threshold_p1_eol;
    logic threshold_p1_eof;
    logic threshold_p1_valid;

    // p2 threshold outputs
    logic threshold_p2_mask;
    logic threshold_p2_sof;
    logic threshold_p2_eol;
    logic threshold_p2_eof;
    logic threshold_p2_valid;

    // p1 erode outputs
    logic erode_p1_mask;
    logic erode_p1_sof;
    logic erode_p1_eol;
    logic erode_p1_eof;
    logic erode_p1_valid;

    // p2 erode outputs
    logic erode_p2_mask;
    logic erode_p2_sof;
    logic erode_p2_eol;
    logic erode_p2_eof;
    logic erode_p2_valid;

    // p1 accumulate outputs
    logic [$clog2(MAX_SUM_X)-1:0] accumulate_p1_sum_x;
    logic [$clog2(MAX_SUM_Y)-1:0] accumulate_p1_sum_y;
    logic [$clog2(CHROMA_WIDTH*HEIGHT+1)-1:0] accumulate_p1_count;
    logic accumulate_p1_valid;
    logic [15:0] accumulate_p1_x_min;
    logic [15:0] accumulate_p1_y_min;
    logic [15:0] accumulate_p1_x_max;
    logic [15:0] accumulate_p1_y_max;

    // p2 accumulate outputs
    logic [$clog2(MAX_SUM_X)-1:0] accumulate_p2_sum_x;
    logic [$clog2(MAX_SUM_Y)-1:0] accumulate_p2_sum_y;
    logic [$clog2(CHROMA_WIDTH*HEIGHT+1)-1:0] accumulate_p2_count;
    logic accumulate_p2_valid;
    logic [15:0] accumulate_p2_x_min;
    logic [15:0] accumulate_p2_y_min;
    logic [15:0] accumulate_p2_x_max;
    logic [15:0] accumulate_p2_y_max;

    // outputs outpus
    logic [15:0] outputs_p1_cnt;
    logic [15:0] outputs_p1_cx;
    logic [15:0] outputs_p1_cy;
    logic [15:0] outputs_p2_cnt;
    logic [15:0] outputs_p2_cx;
    logic [15:0] outputs_p2_cy;
    logic outputs_p1_valid;
    logic outputs_p2_valid;
    logic [7:0] outputs_frame_count;
    logic outputs_drdy;
    logic [15:0] outputs_latency;
    logic [7:0] outputs_probe_u;
    logic [7:0] outputs_probe_v;
    logic [7:0] outputs_probe_y;
    logic [15:0] outputs_p1_bbox_x_min;
    logic [15:0] outputs_p1_bbox_y_min;
    logic [15:0] outputs_p1_bbox_x_max;
    logic [15:0] outputs_p1_bbox_y_max;
    logic [15:0] outputs_p2_bbox_x_min;
    logic [15:0] outputs_p2_bbox_y_min;
    logic [15:0] outputs_p2_bbox_x_max;
    logic [15:0] outputs_p2_bbox_y_max;

    // thumbnail outputs
    logic thumbnail_swap;
    logic thumbnail_advance;
    logic thumbnail_new_frame;
    logic [1:0] thumbnail_buf_stage;
    logic [7:0] thumbnail_data;

    spi_slave SPI (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),
        .spi_miso(spi_miso_internal),
        .spi_miso_oe(spi_miso_oe_internal),
        .cfg_apply(cfg_apply),
        .fab_latency(outputs_latency),
        .p1_valid(outputs_p1_valid),
        .p2_valid(outputs_p2_valid),
        .frame_count(outputs_frame_count),
        .p1_cnt(outputs_p1_cnt),
        .p1_cx(outputs_p1_cx),
        .p1_cy(outputs_p1_cy),
        .p2_cnt(outputs_p2_cnt),
        .p2_cx(outputs_p2_cx),
        .p2_cy(outputs_p2_cy),
        .probe_u(outputs_probe_u),
        .probe_v(outputs_probe_v),
        .probe_y(outputs_probe_y),
        .thumbnail_new_frame(thumbnail_new_frame),
        .thumbnail_stage_sel(thumbnail_buf_stage),
        .thumbnail_data(thumbnail_data),
        .p1_bbox_x_min(outputs_p1_bbox_x_min),
        .p1_bbox_y_min(outputs_p1_bbox_y_min),
        .p1_bbox_x_max(outputs_p1_bbox_x_max),
        .p1_bbox_y_max(outputs_p1_bbox_y_max),
        .p2_bbox_x_min(outputs_p2_bbox_x_min),
        .p2_bbox_y_min(outputs_p2_bbox_y_min),
        .p2_bbox_x_max(outputs_p2_bbox_x_max),
        .p2_bbox_y_max(outputs_p2_bbox_y_max),
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
        .debug_stage_sel(debug_stage_sel),
        .swap(thumbnail_swap),
        .advance(thumbnail_advance)
    );

    assign spi_miso = (spi_miso_oe_internal == 1'b1) ? spi_miso_internal : 1'bz;

    capture #(
        .WIDTH_BYTES(WIDTH_BYTES),
        .HEIGHT(HEIGHT)
    ) CAP (
        .clk(clk),
        .rst_n(rst_n),
        .cam_pclk(pclk),
        .cam_href(href),
        .cam_vsync(vsync),
        .cam_d(data),
        .out_valid(capture_valid),
        .out_data(capture_data),
        .out_sof(capture_sof),
        .out_eol(capture_eol),
        .out_eof(capture_eof),
        .cfg_apply(cfg_apply),
        .frame_end(capture_frame_end),
        .pipe_rst_n(pipe_rst_n)
    );

    chroma_extraction CHROMA (
        .clk(clk),
        .rst_n(rst_n && pipe_rst_n),
        .in_valid(capture_valid),
        .in_data(capture_data),
        .in_sof(capture_sof),
        .in_eol(capture_eol),
        .in_eof(capture_eof),
        .out_valid(chroma_valid),
        .out_u(chroma_u),
        .out_v(chroma_v),
        .out_y0(chroma_y0),
        .out_y1(chroma_y1),
        .out_sof(chroma_sof),
        .out_eol(chroma_eol),
        .out_eof(chroma_eof),
        .out_probe_u(chroma_probe_u),
        .out_probe_v(chroma_probe_v),
        .out_probe_y(chroma_probe_y)
    );

    threshold P1_THRESHOLD (
        .clk(clk),
        .rst_n(rst_n && pipe_rst_n),
        .in_u(chroma_u),
        .in_v(chroma_v),
        .in_y0(chroma_y0),
        .in_y1(chroma_y1),
        .in_u_min(p1_u_min),
        .in_u_max(p1_u_max),
        .in_v_min(p1_v_min),
        .in_v_max(p1_v_max),
        .in_y_min(p1_y_min),
        .in_sof(chroma_sof),
        .in_eol(chroma_eol),
        .in_eof(chroma_eof),
        .in_valid(chroma_valid),
        .out_mask(threshold_p1_mask),
        .out_sof(threshold_p1_sof),
        .out_eol(threshold_p1_eol),
        .out_eof(threshold_p1_eof),
        .out_valid(threshold_p1_valid)
    );

    threshold P2_THRESHOLD (
        .clk(clk),
        .rst_n(rst_n && pipe_rst_n),
        .in_u(chroma_u),
        .in_v(chroma_v),
        .in_y0(chroma_y0),
        .in_y1(chroma_y1),
        .in_u_min(p2_u_min),
        .in_u_max(p2_u_max),
        .in_v_min(p2_v_min),
        .in_v_max(p2_v_max),
        .in_y_min(p2_y_min),
        .in_sof(chroma_sof),
        .in_eol(chroma_eol),
        .in_eof(chroma_eof),
        .in_valid(chroma_valid),
        .out_mask(threshold_p2_mask),
        .out_sof(threshold_p2_sof),
        .out_eol(threshold_p2_eol),
        .out_eof(threshold_p2_eof),
        .out_valid(threshold_p2_valid)
    );

    erode P1_ERODE (
        .clk(clk),
        .rst_n(rst_n && pipe_rst_n),
        .in_mask(threshold_p1_mask),
        .in_sof(threshold_p1_sof),
        .in_eol(threshold_p1_eol),
        .in_eof(threshold_p1_eof),
        .in_valid(threshold_p1_valid),
        .in_ready(),
        .erode_en(erode_en),
        .out_mask(erode_p1_mask),
        .out_sof(erode_p1_sof),
        .out_eol(erode_p1_eol),
        .out_eof(erode_p1_eof),
        .out_valid(erode_p1_valid)
    );

    erode P2_ERODE (
        .clk(clk),
        .rst_n(rst_n && pipe_rst_n),
        .in_mask(threshold_p2_mask),
        .in_sof(threshold_p2_sof),
        .in_eol(threshold_p2_eol),
        .in_eof(threshold_p2_eof),
        .in_valid(threshold_p2_valid),
        .in_ready(),
        .erode_en(erode_en),
        .out_mask(erode_p2_mask),
        .out_sof(erode_p2_sof),
        .out_eol(erode_p2_eol),
        .out_eof(erode_p2_eof),
        .out_valid(erode_p2_valid)
    );

    accumulate #(
        .WIDTH(CHROMA_WIDTH),
        .HEIGHT(HEIGHT)
    ) P1_ACCUMULATE (
        .clk(clk),
        .rst_n(rst_n && pipe_rst_n),
        .in_mask(erode_p1_mask),
        .in_sof(erode_p1_sof),
        .in_eol(erode_p1_eol),
        .in_eof(erode_p1_eof),
        .in_valid(erode_p1_valid),
        .out_sum_x(accumulate_p1_sum_x),
        .out_sum_y(accumulate_p1_sum_y),
        .out_pixel_count(accumulate_p1_count),
        .out_valid(accumulate_p1_valid),
        .x_min(accumulate_p1_x_min),
        .y_min(accumulate_p1_y_min),
        .x_max(accumulate_p1_x_max),
        .y_max(accumulate_p1_y_max)
    );

    accumulate #(
        .WIDTH(CHROMA_WIDTH),
        .HEIGHT(HEIGHT)
    ) P2_ACCUMULATE (
        .clk(clk),
        .rst_n(rst_n && pipe_rst_n),
        .in_mask(erode_p2_mask),
        .in_sof(erode_p2_sof),
        .in_eol(erode_p2_eol),
        .in_eof(erode_p2_eof),
        .in_valid(erode_p2_valid),
        .out_sum_x(accumulate_p2_sum_x),
        .out_sum_y(accumulate_p2_sum_y),
        .out_pixel_count(accumulate_p2_count),
        .out_valid(accumulate_p2_valid),
        .x_min(accumulate_p2_x_min),
        .y_min(accumulate_p2_y_min),
        .x_max(accumulate_p2_x_max),
        .y_max(accumulate_p2_y_max)
    );

    outputs #(
        .FRAME_WIDTH(CHROMA_WIDTH),
        .FRAME_HEIGHT(HEIGHT),
        .DOWN_COUNT(200),
        .CLK_PER_US(100) // assume 100 MHz
    ) OUTPUTS (
        .clk(clk),
        .rst_n(rst_n),
        .acc_valid1(accumulate_p1_valid),
        .acc_valid2(accumulate_p2_valid),
        .sum_x1(accumulate_p1_sum_x),
        .sum_y1(accumulate_p1_sum_y),
        .count1(accumulate_p1_count),
        .min_blob1(p1_min_blob),
        .sum_x2(accumulate_p2_sum_x),
        .sum_y2(accumulate_p2_sum_y),
        .count2(accumulate_p2_count),
        .min_blob2(p2_min_blob),
        .frame_end(capture_frame_end),
        .in_probe_u(chroma_probe_u),
        .in_probe_v(chroma_probe_v),
        .in_probe_y(chroma_probe_y),
        .in_p1_bbox_x_min(accumulate_p1_x_min),
        .in_p1_bbox_y_min(accumulate_p1_y_min),
        .in_p1_bbox_x_max(accumulate_p1_x_max),
        .in_p1_bbox_y_max(accumulate_p1_y_max),
        .in_p2_bbox_x_min(accumulate_p2_x_min),
        .in_p2_bbox_y_min(accumulate_p2_y_min),
        .in_p2_bbox_x_max(accumulate_p2_x_max),
        .in_p2_bbox_y_max(accumulate_p2_y_max),
        .p1_cnt(outputs_p1_cnt),
        .p1_cx(outputs_p1_cx),
        .p1_cy(outputs_p1_cy),
        .p2_cnt(outputs_p2_cnt),
        .p2_cx(outputs_p2_cx),
        .p2_cy(outputs_p2_cy),
        .p1_valid(outputs_p1_valid),
        .p2_valid(outputs_p2_valid),
        .frame_count(outputs_frame_count),
        .drdy(outputs_drdy),
        .latency(outputs_latency),
        .probe_u(outputs_probe_u),
        .probe_v(outputs_probe_v),
        .probe_y(outputs_probe_y),
        .p1_bbox_x_min(outputs_p1_bbox_x_min),
        .p1_bbox_y_min(outputs_p1_bbox_y_min),
        .p1_bbox_x_max(outputs_p1_bbox_x_max),
        .p1_bbox_y_max(outputs_p1_bbox_y_max),
        .p2_bbox_x_min(outputs_p2_bbox_x_min),
        .p2_bbox_y_min(outputs_p2_bbox_y_min),
        .p2_bbox_x_max(outputs_p2_bbox_x_max),
        .p2_bbox_y_max(outputs_p2_bbox_y_max)
    );

    assign drdy = outputs_drdy;

    thumbnail #(
        .WIDTH(),
        .HEIGHT()
    ) THUMBNAIL (
        .clk(clk),
        .rst_n(rst_n),
        .pipe_rst_n(pipe_rst_n),
        .stage_sel(debug_stage_sel),
        .c_valid(chroma_valid),
        .c_sof(chroma_sof),
        .c_eol(chroma_eol),
        .c_eof(chroma_eof),
        .c_u(chroma_u),
        .c_y0(chroma_y0),
        .c_v(chroma_v),
        .c_y1(chroma_y1),
        .t_valid(threshold_p1_valid),
        .t_sof(threshold_p1_sof),
        .t_eol(threshold_p1_eol),
        .t_eof(threshold_p1_eof),
        .t_mask1(threshold_p1_mask),
        .t_mask2(threshold_p2_mask),
        .e_valid(erode_p1_valid),
        .e_sof(erode_p1_sof),
        .e_eol(erode_p1_eol),
        .e_eof(erode_p1_eof),
        .e_mask1(erode_p1_mask),
        .e_mask2(erode_p2_mask),
        .swap(thumbnail_swap),
        .advance(thumbnail_advance),
        .new_frame(thumbnail_new_frame),
        .buf_stage(thumbnail_buf_stage),
        .data(thumbnail_data)
    );

endmodule
