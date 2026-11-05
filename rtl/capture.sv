module capture #(
    parameter int unsigned WIDTH_BYTES = 640,
    parameter int unsigned HEIGHT = 240
) (
    input logic clk,
    input logic rst_n,
    input logic cam_pclk,
    input logic cam_href,
    input logic cam_vsync,
    input logic [7:0] cam_d,
    output logic out_valid,
    output logic [7:0] out_data,
    output logic out_sof,
    output logic out_eol,
    output logic out_eof,
    output logic cfg_apply,
    output logic frame_end,
    output logic pipe_rst_n // reset the pipeline, frame desync
);

    typedef enum logic [2:0] {
        INIT,
        VBLANK,
        WAIT_SOF,
        ACTIVE,
        DONE
    } state_t;
    // registers
    state_t state_r;
    logic [$clog2(WIDTH_BYTES)-1:0] width_count_r;
    logic [$clog2(HEIGHT)-1:0] height_count_r;

    // sync
    logic [2:0] pclk_sync;
    logic [2:0] href_sync;
    logic [7:0] data_sync [2];
    logic [2:0] vsync_sync;

    // registered outputs
    logic out_valid_r;
    logic [7:0] out_data_r;
    logic out_sof_r;
    logic out_eol_r;
    logic out_eof_r;
    logic cfg_apply_r;
    logic frame_end_r;
    logic pipe_rst_n_r;

    logic pclk_rise;
    logic vsync_fall;
    logic vsync_rise;
    logic href_fall;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_r <= INIT;
            width_count_r <= '0;
            height_count_r <= '0;
            out_valid_r <= 1'b0;
            out_data_r <= '0;
            out_sof_r <= 1'b0;
            out_eol_r <= 1'b0;
            out_eof_r <= 1'b0;
            cfg_apply_r <= 1'b0;
            frame_end_r <= 1'b0;
            pipe_rst_n_r <= 1'b1;
        end else begin
            // register defaults
            out_valid_r <= 1'b0;
            out_sof_r <= 1'b0;
            out_eol_r <= 1'b0;
            out_eof_r <= 1'b0;
            cfg_apply_r <= 1'b0;
            frame_end_r <= 1'b0;
            pipe_rst_n_r <= 1'b1;

            case (state_r)
                INIT: begin
                    if (vsync_fall) begin
                        cfg_apply_r <= 1'b1;
                        state_r <= VBLANK;
                    end
                end

                VBLANK: begin
                    if (vsync_rise) begin
                        width_count_r <= '0;
                        height_count_r <= '0;
                        state_r <= WAIT_SOF;
                    end
                end

                WAIT_SOF: begin
                    if (pclk_rise && href_sync[1]) begin
                        out_data_r <= data_sync[1];
                        out_sof_r <= 1'b1;
                        out_valid_r <= 1'b1;
                        width_count_r <= 1;
                        state_r <= ACTIVE;
                    end

                    if (vsync_fall) begin
                        cfg_apply_r <= 1'b1;
                        pipe_rst_n_r <= 1'b0;
                        state_r <= VBLANK;
                    end
                end

                ACTIVE: begin
                    if (pclk_rise && href_sync[1]) begin
                        out_data_r <= data_sync[1];
                        out_valid_r <= 1'b1;
                        if (width_count_r == WIDTH_BYTES - 1 && height_count_r == HEIGHT - 1) begin
                            out_eof_r <= 1'b1;
                            out_eol_r <= 1'b1;
                            width_count_r <= '0;
                            height_count_r <= '0;
                            frame_end_r <= 1'b1;
                            state_r <= DONE;
                        end else if (width_count_r == WIDTH_BYTES - 1) begin
                            out_eol_r <= 1'b1;
                            width_count_r <= '0;
                            height_count_r <= height_count_r + 1;
                        end else begin
                            width_count_r <= width_count_r + 1;
                        end
                    end

                    if (vsync_fall) begin
                        cfg_apply_r <= 1'b1;
                        pipe_rst_n_r <= 1'b0;
                        state_r <= VBLANK;
                    end

                    // we wrapped the 640 bytes, bad frame
                    if (href_fall && width_count_r != 0) begin
                        pipe_rst_n_r <= 1'b0;
                        state_r <= DONE;
                    end
                end

                DONE: begin
                    if (vsync_fall) begin
                        cfg_apply_r <= 1'b1;
                        state_r <= VBLANK;
                    end
                end
            endcase
        end
    end

    assign out_valid = out_valid_r;
    assign out_data = out_data_r;
    assign out_sof = out_sof_r;
    assign out_eol = out_eol_r;
    assign out_eof = out_eof_r;
    assign cfg_apply = cfg_apply_r;
    assign frame_end = frame_end_r;
    assign pipe_rst_n = pipe_rst_n_r;

    // synchronization
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pclk_sync <= '0;
            href_sync <= '0;
            vsync_sync <= '1;
            data_sync[0] <= '0;
            data_sync[1] <= '0;
        end else begin
            pclk_sync[0] <= cam_pclk;
            pclk_sync[1] <= pclk_sync[0];
            pclk_sync[2] <= pclk_sync[1];

            href_sync[0] <= cam_href;
            href_sync[1] <= href_sync[0];
            href_sync[2] <= href_sync[1];

            // we can synchronize this multi bit signal like this
            // because of the synchronized pclk strobe
            // assumptions:
            // - 19.2 MHz source and 100 MHz dst mean a good margin
            // - equal skew on all bits
            data_sync[0] <= cam_d;
            data_sync[1] <= data_sync[0];

            vsync_sync[0] <= cam_vsync;
            vsync_sync[1] <= vsync_sync[0];
            vsync_sync[2] <= vsync_sync[1];
        end
    end

    assign pclk_rise = pclk_sync[1] && !pclk_sync[2];
    assign href_fall = !href_sync[1] && href_sync[2];
    assign vsync_fall = !vsync_sync[1] && vsync_sync[2];
    assign vsync_rise = vsync_sync[1] && !vsync_sync[2];

endmodule