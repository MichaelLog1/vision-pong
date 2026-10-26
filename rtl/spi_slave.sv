module spi_slave (
    input logic clk,
    input logic rst_n,
    input logic spi_sclk,
    input logic spi_mosi,
    input logic spi_cs_n,
    output logic spi_miso,
    output logic spi_miso_oe,
    output logic drdy, // SPI int

    input logic cfg_apply,

    // pipeline inputs
    input logic p1_valid,
    input logic p2_valid,
    input logic [7:0] frame_count,
    input logic [15:0] p1_cnt,
    input logic [15:0] p1_cx,
    input logic [15:0] p1_cy,
    input logic [15:0] p2_cnt,
    input logic [15:0] p2_cx,
    input logic [15:0] p2_cy,

    input logic [7:0] probe_u,
    input logic [7:0] probe_v,
    input logic [7:0] probe_y,

    // thumbnail
    input logic thumbnail_new_frame,
    input logic [1:0] thumbnail_stage_sel,
    input logic [7:0] thumbnail_data,

    // p1 bbox
    input logic [15:0] p1_bbox_x_min,
    input logic [15:0] p1_bbox_y_min,
    input logic [15:0] p1_bbox_x_max,
    input logic [15:0] p1_bbox_y_max,

    // p2 bbox
    input logic [15:0] p2_bbox_x_min,
    input logic [15:0] p2_bbox_y_min,
    input logic [15:0] p2_bbox_x_max,
    input logic [15:0] p2_bbox_y_max,

    // player 1 color thresholds
    output logic [7:0] p1_u_min,
    output logic [7:0] p1_u_max,
    output logic [7:0] p1_v_min,
    output logic [7:0] p1_v_max,
    output logic [7:0] p1_y_min,

    // player 2 color thresholds
    output logic [7:0] p2_u_min,
    output logic [7:0] p2_u_max,
    output logic [7:0] p2_v_min,
    output logic [7:0] p2_v_max,
    output logic [7:0] p2_y_min,

    output logic [15:0] p1_min_blob,  // if we need it, gates potentially extraneous color regions
    output logic [15:0] p2_min_blob,
    output logic erode_en,             // can get rid of erode stage just to see performance improvements
    output logic [1:0] debug_stage_sel // debug output if needed
);
    localparam device_id = 8'hA5;

    // sync registers
    logic [2:0] spi_sclk_sync;
    logic [1:0] spi_mosi_sync;
    logic [1:0] spi_cs_n_sync;

    // staging registers
    logic erode_en_r;
    logic [1:0] debug_stage_sel_r;
    logic [7:0] p1_u_min_r;
    logic [7:0] p1_u_max_r;
    logic [7:0] p1_v_min_r;
    logic [7:0] p1_v_max_r;
    logic [7:0] p1_y_min_r;
    logic [7:0] p2_u_min_r;
    logic [7:0] p2_u_max_r;
    logic [7:0] p2_v_min_r;
    logic [7:0] p2_v_max_r;
    logic [7:0] p2_y_min_r;
    logic [15:0] p1_min_blob_r;
    logic [15:0] p2_min_blob_r;

    // active registers
    logic active_erode_en_r;
    logic [1:0] active_debug_stage_sel_r;
    logic [7:0] active_p1_u_min_r;
    logic [7:0] active_p1_u_max_r;
    logic [7:0] active_p1_v_min_r;
    logic [7:0] active_p1_v_max_r;
    logic [7:0] active_p1_y_min_r;
    logic [7:0] active_p2_u_min_r;
    logic [7:0] active_p2_u_max_r;
    logic [7:0] active_p2_v_min_r;
    logic [7:0] active_p2_v_max_r;
    logic [7:0] active_p2_y_min_r;
    logic [15:0] active_p1_min_blob_r;
    logic [15:0] active_p2_min_blob_r;

    // snapshot array
    logic freeze_r;
    logic freeze_p1_valid_r;
    logic freeze_p2_valid_r;
    logic [7:0] freeze_frame_count_r;
    logic [15:0] freeze_p1_cx_r;
    logic [15:0] freeze_p1_cy_r;
    logic [15:0] freeze_p1_cnt_r;
    logic [15:0] freeze_p2_cx_r;
    logic [15:0] freeze_p2_cy_r;
    logic [15:0] freeze_p2_cnt_r;
    
    // spi control registers
    logic is_read_r;
    logic [2:0] count_r;
    logic [6:0] addr_r;
    logic [7:0] mosi_shift_r;
    logic [7:0] miso_shift_r;
    logic [7:0] tx_byte_r;
    logic rx_valid_r;

    // comb
    logic sclk_rise;
    logic sclk_fall;
    logic [6:0] rd_addr;
    logic [7:0] rd_data;

    typedef enum logic [1:0] {
        IDLE,
        CMD,
        PAYLOAD
    } state_t;
    state_t state_r;

    typedef enum logic {
        WAIT,
        COUNT
    } shift_state_t;
    shift_state_t shift_state_r;

    // try to have one play where the decoding is done instead of two
    always_comb begin
        case (rd_addr)
            7'h01: rd_data = {  5'h0, erode_en_r, debug_stage_sel_r }; // ctrl
            7'h10: rd_data = { freeze_p1_valid_r, freeze_p2_valid_r, 6'h00 };            // status
            7'h11: rd_data = freeze_frame_count_r;                              // frame num
            7'h12: rd_data = freeze_p1_cx_r[7:0];                               // p1_x
            7'h13: rd_data = freeze_p1_cx_r[15:8];
            7'h14: rd_data = freeze_p1_cy_r[7:0];                               // p1_y
            7'h15: rd_data = freeze_p1_cy_r[15:8];
            7'h16: rd_data = freeze_p1_cnt_r[7:0];                              // p1_cnt
            7'h17: rd_data = freeze_p1_cnt_r[15:8];
            7'h18: rd_data = freeze_p2_cx_r[7:0];                               // p2_x
            7'h19: rd_data = freeze_p2_cx_r[15:8];
            7'h1A: rd_data = freeze_p2_cy_r[7:0];                               // p2_y
            7'h1B: rd_data = freeze_p2_cy_r[15:8];
            7'h1C: rd_data = freeze_p2_cnt_r[7:0];                              // p2_cnt
            7'h1D: rd_data = freeze_p2_cnt_r[15:8];
            7'h1E: rd_data = '0; // TODO: latency in us, saturating at 0xffff
            7'h1F: rd_data = '0;
            7'h20: rd_data = p1_u_min_r;
            7'h21: rd_data = p1_u_max_r;
            7'h22: rd_data = p1_v_min_r;
            7'h23: rd_data = p1_v_max_r;
            7'h24: rd_data = p2_u_min_r;
            7'h25: rd_data = p2_u_max_r;
            7'h26: rd_data = p2_v_min_r;
            7'h27: rd_data = p2_v_max_r;
            7'h28: rd_data = p1_y_min_r;
            7'h29: rd_data = p2_y_min_r;
            7'h2A: rd_data = p1_min_blob_r[7:0];
            7'h2B: rd_data = p1_min_blob_r[15:8];
            7'h2C: rd_data = p2_min_blob_r[7:0];
            7'h2D: rd_data = p2_min_blob_r[15:8];
            7'h30: rd_data = probe_u;
            7'h31: rd_data = probe_v;
            7'h32: rd_data = probe_y;
            7'h3F: rd_data = device_id;
            7'h40: rd_data = { 5'h00, thumbnail_stage_sel, thumbnail_new_frame }; // [0] new frame, [2:1] stage of buffered frame
            7'h41: rd_data = thumbnail_data;
            7'h50: rd_data = p1_bbox_x_min[7:0];
            7'h51: rd_data = p1_bbox_x_min[15:8];
            7'h52: rd_data = p1_bbox_y_min[7:0];
            7'h53: rd_data = p1_bbox_y_min[15:8];
            7'h54: rd_data = p1_bbox_x_max[7:0];
            7'h55: rd_data = p1_bbox_x_max[15:8];
            7'h56: rd_data = p1_bbox_y_max[7:0];
            7'h57: rd_data = p1_bbox_y_max[15:8];
            7'h58: rd_data = p2_bbox_x_min[7:0];
            7'h59: rd_data = p2_bbox_x_min[15:8];
            7'h5A: rd_data = p2_bbox_y_min[7:0];
            7'h5B: rd_data = p2_bbox_y_min[15:8];
            7'h5C: rd_data = p2_bbox_x_max[7:0];
            7'h5D: rd_data = p2_bbox_x_max[15:8];
            7'h5E: rd_data = p2_bbox_y_max[7:0];
            7'h5F: rd_data = p2_bbox_y_max[15:8];
            default: rd_data = '0;
        endcase
    end

    assign rd_addr = (state_r == CMD) ? mosi_shift_r[6:0] : addr_r + 1;

    always_ff @(posedge clk) begin
        if (!rst_n) begin   
            state_r <= IDLE;
            is_read_r <= 1'b1;
            addr_r <= '0;
            tx_byte_r <= '0;
            freeze_r <= 1'b0;
            p1_min_blob_r <= 16'h0040;
            p2_min_blob_r <= 16'h0040;
            erode_en_r <= 1'b1;
            debug_stage_sel_r <= 2'b00;
            p1_u_min_r <= '0;
            p1_u_max_r <= '0;
            p1_v_min_r <= '0;
            p1_v_max_r <= '0;
            p1_y_min_r <= 32;
            p2_u_min_r <= '0;
            p2_u_max_r <= '0;
            p2_v_min_r <= '0;
            p2_v_max_r <= '0;
            p2_y_min_r <= 32;
        end else begin
            case (state_r)
                IDLE: begin
                    if (!spi_cs_n_sync[1]) begin
                        state_r <= CMD;
                    end
                end

                CMD: begin
                    if (rx_valid_r) begin
                        is_read_r <= !mosi_shift_r[7];
                        addr_r <= mosi_shift_r[6:0];
                        state_r <= PAYLOAD;
                        tx_byte_r <= rd_data;

                        // we dont want to be in the middle of a frame read and the frame data changes.
                        // we will use this as a sort of 'lock' to keep the data stable during a read
                        if ((!mosi_shift_r[7]) && (mosi_shift_r[6:0] >= 7'h10 && mosi_shift_r[6:0] <= 7'h1F)) freeze_r <= 1'b1;
                    end

                    if (spi_cs_n_sync[1]) begin
                        state_r <= IDLE;
                        freeze_r <= 1'b0;
                    end
                end

                PAYLOAD: begin
                    if (rx_valid_r) begin
                        addr_r <= addr_r + 1;
                        if (is_read_r) begin
                            tx_byte_r <= rd_data;
                        end else begin
                            case (addr_r)
                                7'h01: { erode_en_r, debug_stage_sel_r } <= mosi_shift_r[2:0];
                                7'h20: p1_u_min_r <= mosi_shift_r;
                                7'h21: p1_u_max_r <= mosi_shift_r;
                                7'h22: p1_v_min_r <= mosi_shift_r;
                                7'h23: p1_v_max_r <= mosi_shift_r;
                                7'h24: p2_u_min_r <= mosi_shift_r;
                                7'h25: p2_u_max_r <= mosi_shift_r;
                                7'h26: p2_v_min_r <= mosi_shift_r;
                                7'h27: p2_v_max_r <= mosi_shift_r; 
                                7'h28: p1_y_min_r <= mosi_shift_r;
                                7'h29: p2_y_min_r <= mosi_shift_r;
                                7'h2A: p1_min_blob_r[7:0] <= mosi_shift_r;
                                7'h2B: p1_min_blob_r[15:8] <= mosi_shift_r;
                                7'h2C: p2_min_blob_r[7:0] <= mosi_shift_r;
                                7'h2D: p2_min_blob_r[15:8] <= mosi_shift_r;
                            endcase
                        end
                    end

                    if (spi_cs_n_sync[1]) begin
                        state_r <= IDLE;
                        freeze_r <= 1'b0;
                    end
                end
            endcase
        end
    end

    // registered outputs
    assign erode_en = active_erode_en_r;
    assign debug_stage_sel = active_debug_stage_sel_r;
    assign p1_u_min = active_p1_u_min_r;
    assign p1_u_max = active_p1_u_max_r;
    assign p1_v_min = active_p1_v_min_r;
    assign p1_v_max = active_p1_v_max_r;
    assign p1_y_min = active_p1_y_min_r;
    assign p2_u_min = active_p2_u_min_r;
    assign p2_u_max = active_p2_u_max_r;
    assign p2_v_min = active_p2_v_min_r;
    assign p2_v_max = active_p2_v_max_r;
    assign p2_y_min = active_p2_y_min_r;
    assign p1_min_blob = active_p1_min_blob_r;
    assign p2_min_blob = active_p2_min_blob_r;
    

    // shift register
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            shift_state_r <= WAIT;
            count_r <= '0;
            mosi_shift_r <= '0;
            miso_shift_r <= '0;
            rx_valid_r <= 1'b0;
        end else begin
            rx_valid_r <= 1'b0;
            case (shift_state_r)
                WAIT: begin
                    if (!spi_cs_n_sync[1]) begin
                        shift_state_r <= COUNT;
                    end
                end

                COUNT: begin
                    if (spi_cs_n_sync[1]) begin
                        shift_state_r <= WAIT;
                        count_r <= '0;
                    end else if (sclk_rise) begin
                        count_r <= count_r + 1;
                        mosi_shift_r <= { mosi_shift_r[6:0], spi_mosi_sync[1] };
                    end else if (sclk_fall) begin
                        if (count_r == 0) begin
                            miso_shift_r <= tx_byte_r;
                        end else begin
                            miso_shift_r <= { miso_shift_r[6:0], 1'b0 };
                        end
                    end
                    rx_valid_r <= sclk_rise && (count_r == 3'd7);
                end
            endcase
        end
    end

    assign spi_miso = miso_shift_r[7];
    assign spi_miso_oe = !spi_cs_n_sync[1];

    // synchronization
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            spi_sclk_sync <= '0;
            spi_mosi_sync <= '0;
            spi_cs_n_sync <= '1;
        end else begin
            // sclk dualff
            spi_sclk_sync[0] <= spi_sclk;
            spi_sclk_sync[1] <= spi_sclk_sync[0];
            spi_sclk_sync[2] <= spi_sclk_sync[1]; // third bit for edge detection

            // mosi dualff
            spi_mosi_sync[0] <= spi_mosi;
            spi_mosi_sync[1] <= spi_mosi_sync[0];

            // cs dualff
            spi_cs_n_sync[0] <= spi_cs_n;
            spi_cs_n_sync[1] <= spi_cs_n_sync[0];
        end
    end

    assign sclk_rise = !spi_sclk_sync[2] && spi_sclk_sync[1];
    assign sclk_fall = spi_sclk_sync[2] && !spi_sclk_sync[1];
    
    // active registers
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            active_erode_en_r <= 1'b1;
            active_debug_stage_sel_r <= 2'b00;
            active_p1_u_min_r <= '0;
            active_p1_u_max_r <= '0;
            active_p1_v_min_r <= '0;
            active_p1_v_max_r <= '0;
            active_p1_y_min_r <= 32;
            active_p2_u_min_r <= '0;
            active_p2_u_max_r <= '0;
            active_p2_v_min_r <= '0;
            active_p2_v_max_r <= '0;
            active_p2_y_min_r <= 32;
            active_p1_min_blob_r <= 16'h0040;
            active_p2_min_blob_r <= 16'h0040;
        end else begin
            // skip the apply if we are in the middle of a write
            if (cfg_apply && !(!spi_cs_n_sync[1] && !is_read_r)) begin
                active_erode_en_r <= erode_en_r;
                active_debug_stage_sel_r <= debug_stage_sel_r;
                active_p1_u_min_r <= p1_u_min_r;
                active_p1_u_max_r <= p1_u_max_r;
                active_p1_v_min_r <= p1_v_min_r;
                active_p1_v_max_r <= p1_v_max_r;
                active_p1_y_min_r <= p1_y_min_r;
                active_p2_u_min_r <= p2_u_min_r;
                active_p2_u_max_r <= p2_u_max_r;
                active_p2_v_min_r <= p2_v_min_r;
                active_p2_v_max_r <= p2_v_max_r;
                active_p2_y_min_r <= p2_y_min_r;
                active_p1_min_blob_r <= p1_min_blob_r;
                active_p2_min_blob_r <= p2_min_blob_r;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            freeze_p1_valid_r <= 1'b0;
            freeze_p2_valid_r <= 1'b0;
            freeze_frame_count_r <= '0;
            freeze_p1_cx_r <= '0;
            freeze_p1_cy_r <= '0;
            freeze_p1_cnt_r <= '0;
            freeze_p2_cx_r <= '0;
            freeze_p2_cy_r <= '0;
            freeze_p2_cnt_r <= '0;
        end else begin
            if (!freeze_r &&  ((state_r == CMD) && (!mosi_shift_r[7]) && (mosi_shift_r[6:0] >= 7'h10 && mosi_shift_r[6:0] <= 7'h1F))) begin
                freeze_p1_valid_r <= p1_valid;
                freeze_p2_valid_r <= p2_valid;
                freeze_frame_count_r <= frame_count;
                freeze_p1_cx_r <= p1_cx;
                freeze_p1_cy_r <= p1_cy;
                freeze_p1_cnt_r <= p1_cnt;
                freeze_p2_cx_r <= p2_cx;
                freeze_p2_cy_r <= p2_cy;
                freeze_p2_cnt_r <= p2_cnt;
            end
        end
    end

endmodule