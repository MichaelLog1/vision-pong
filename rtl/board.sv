module board #(
    parameter int unsigned HEARTBEAT_CLOCKS = 50000000
) (
    // camera inputs
    input logic cam_d2,
    input logic cam_d3,
    input logic cam_d4,
    input logic cam_d5,
    input logic cam_d6,
    input logic cam_d7,
    input logic cam_d8,
    input logic cam_d9,
    input logic cam_vs,
    input logic cam_hs,
    input logic cam_pc,

    // spi
    input logic spi_sclk,
    input logic spi_mosi,
    input logic spi_cs_n,
    output logic spi_miso,

    // interrupt
    output logic drdy,

    // heartbeat led
    output logic led_o,

    // wrapper ports
    inout wire DDR_cas_n,
    inout wire DDR_cke,
    inout wire DDR_ck_n,
    inout wire DDR_ck_p,
    inout wire DDR_cs_n,
    inout wire DDR_reset_n,
    inout wire DDR_odt,
    inout wire DDR_ras_n,
    inout wire DDR_we_n,
    inout wire [2:0] DDR_ba,
    inout wire [14:0] DDR_addr,
    inout wire [3:0] DDR_dm,
    inout wire [31:0] DDR_dq,
    inout wire [3:0] DDR_dqs_n,
    inout wire [3:0] DDR_dqs_p,
    inout wire [53:0] FIXED_IO_mio,
    inout wire FIXED_IO_ddr_vrn,
    inout wire FIXED_IO_ddr_vrp,
    inout wire FIXED_IO_ps_srstb,
    inout wire FIXED_IO_ps_clk,
    inout wire FIXED_IO_ps_porb
);

    logic fclk;
    logic fclk_rst_n;
    logic led_o_r;
    logic [$clog2(HEARTBEAT_CLOCKS)-1:0] heartbeat_count_r;
    
    design_1_sv WRAPPER (
        .DDR_cas_n(DDR_cas_n),
        .DDR_cke(DDR_cke),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cs_n(DDR_cs_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_we_n(DDR_we_n),
        .DDR_ba(DDR_ba),
        .DDR_addr(DDR_addr),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .fclk(fclk),
        .fclk_rst_n(fclk_rst_n)
    );

    top DUT (
        .clk(fclk),
        .rst_n(fclk_rst_n),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),
        .spi_miso(spi_miso),
        .pclk(cam_pc),
        .href(cam_hs),
        .vsync(cam_vs),
        .data({ cam_d9, cam_d8, cam_d7, cam_d6, cam_d5, cam_d4, cam_d3, cam_d2 }),
        .drdy(drdy)
    );

    // heartbeat counter
    always_ff @(posedge fclk) begin
        if (!fclk_rst_n) begin
            heartbeat_count_r <= '0;
            led_o_r <= 1'b0;
        end else begin
            if (heartbeat_count_r == HEARTBEAT_CLOCKS - 1) begin
                heartbeat_count_r <= '0;
                led_o_r <= !led_o_r;
            end else begin
                heartbeat_count_r <= heartbeat_count_r + 1;
            end
        end
    end

    assign led_o = led_o_r;

endmodule
