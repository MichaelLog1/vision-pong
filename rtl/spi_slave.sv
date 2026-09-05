module spi_slave (
    input logic clk,
    input logic rst_n,
    input logic spi_sclk,
    input logic spi_mosi,
    input logic spi_cs_n,
    output logic spi_miso,
    output logic spi_miso_oe,
    output logic drdy, // SPI int

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

    // player 1 color thresholds
    output logic [7:0] p1_u_min,
    output logic [7:0] p1_u_max,
    output logic [7:0] p1_v_min,
    output logic [7:0] p1_v_max,

    // player 2 color thresholds
    output logic [7:0] p2_u_min,
    output logic [7:0] p2_u_max,
    output logic [7:0] p2_v_min,
    output logic [7:0] p2_v_max,

    output logic [7:0] min_blob_size,  // if we need it, gates potentially extraneous color regions
    output logic [7:0] y_min,          // luma cutoff if we use it
    output logic erode_en,             // can get rid of erode stage just to see performance improvements
    output logic luma_gate_en,         // luma cutoff enable
    output logic [1:0] debug_stage_sel // debug output if needed
);
    // sync registers
    logic [2:0] spi_sclk_sync;
    logic [1:0] spi_mosi_sync;
    logic [1:0] spi_cs_n_sync;

    // registers
    logic is_read_r;
    logic [2:0] count_r;
    logic [6:0] addr_r;
    logic [7:0] mosi_shift_r;
    logic [7:0] miso_shift_r;
    logic [7:0] tx_byte_r;
    logic rx_valid_r;
    logic [7:0] min_blob_size_r;
    logic [7:0] y_min_r;
    logic erode_en_r;
    logic luma_gate_en_r;
    logic [1:0] debug_stage_sel_r;
    logic [7:0] p1_u_min_r;
    logic [7:0] p1_u_max_r;
    logic [7:0] p1_v_min_r;
    logic [7:0] p1_v_max_r;
    logic [7:0] p2_u_min_r;
    logic [7:0] p2_u_max_r;
    logic [7:0] p2_v_min_r;
    logic [7:0] p2_v_max_r;

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
            7'h00: rd_data = { p1_valid, p2_valid, 6'h00 };
            7'h01: rd_data = frame_count;
            // p1 centroid
            7'h02: rd_data = p1_cx[7:0];
            7'h03: rd_data = p1_cx[15:8];
            7'h04: rd_data = p1_cy[7:0];
            7'h05: rd_data = p1_cy[15:8];
            // p1 pixel count
            7'h06: rd_data = p1_cnt[7:0];
            7'h07: rd_data = p1_cnt[15:8];
            // p2 centroid
            7'h08: rd_data = p2_cx[7:0];
            7'h09: rd_data = p2_cx[15:8];
            7'h0A: rd_data = p2_cy[7:0];
            7'h0B: rd_data = p2_cy[15:8];
            // p2 pixel count
            7'h0C: rd_data = p2_cnt[7:0];
            7'h0D: rd_data = p2_cnt[15:8];
            // p1 uv bounds
            7'h20: rd_data = p1_u_min_r;
            7'h21: rd_data = p1_u_max_r;
            7'h22: rd_data = p1_v_min_r;
            7'h23: rd_data = p1_v_max_r;
            // p2 uv bounds
            7'h24: rd_data = p2_u_min_r;
            7'h25: rd_data = p2_u_max_r;
            7'h26: rd_data = p2_v_min_r;
            7'h27: rd_data = p2_v_max_r;
            // other config
            7'h28: rd_data = min_blob_size_r;
            7'h29: rd_data = {  4'h0, debug_stage_sel_r, luma_gate_en_r, erode_en_r };
            7'h2A: rd_data = y_min_r;


            7'h3F: rd_data = 8'hA5;
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
            min_blob_size_r <= 8'h10;
            y_min_r <= 8'h20;
            erode_en_r <= 1'b1;
            luma_gate_en_r <= 1'b0;
            debug_stage_sel_r <= 2'b00;
            p1_u_min_r <= '0;
            p1_u_max_r <= '0;
            p1_v_min_r <= '0;
            p1_v_max_r <= '0;
            p2_u_min_r <= '0;
            p2_u_max_r <= '0;
            p2_v_min_r <= '0;
            p2_v_max_r <= '0;
        end else begin
            case (state_r)
                IDLE: begin
                    if (!spi_cs_n_sync[1]) begin
                        state_r <= CMD;
                    end
                end

                CMD: begin
                    if (rx_valid_r) begin
                        is_read_r <= mosi_shift_r[7];
                        addr_r <= mosi_shift_r[6:0];
                        state_r <= PAYLOAD;
                        tx_byte_r <= rd_data;
                    end

                    if (spi_cs_n_sync[1]) begin
                        state_r <= IDLE;
                    end
                end

                PAYLOAD: begin
                    if (rx_valid_r) begin
                        addr_r <= addr_r + 1;
                        if (is_read_r) begin
                            tx_byte_r <= rd_data;
                        end else begin
                            case (addr_r)
                                7'h20: p1_u_min_r <= mosi_shift_r;
                                7'h21: p1_u_max_r <= mosi_shift_r;
                                7'h22: p1_v_min_r <= mosi_shift_r;
                                7'h23: p1_v_max_r <= mosi_shift_r;
                                7'h24: p2_u_min_r <= mosi_shift_r;
                                7'h25: p2_u_max_r <= mosi_shift_r;
                                7'h26: p2_v_min_r <= mosi_shift_r;
                                7'h27: p2_v_max_r <= mosi_shift_r;
                                7'h28: min_blob_size_r <= mosi_shift_r;
                                7'h29: { debug_stage_sel_r, luma_gate_en_r, erode_en_r } <= mosi_shift_r[3:0];
                                7'h2A: y_min_r <= mosi_shift_r;
                            endcase
                        end
                    end

                    if (spi_cs_n_sync[1]) begin
                        state_r <= IDLE;
                    end
                end
            endcase
        end
    end

    // registered outputs
    assign min_blob_size = min_blob_size_r;
    assign erode_en = erode_en_r;
    assign luma_gate_en = luma_gate_en_r;
    assign debug_stage_sel = debug_stage_sel_r;
    assign y_min = y_min_r;
    assign p1_u_min = p1_u_min_r;
    assign p1_u_max = p1_u_max_r;
    assign p1_v_min = p1_v_min_r;
    assign p1_v_max = p1_v_max_r;
    assign p2_u_min = p2_u_min_r;
    assign p2_u_max = p2_u_max_r;
    assign p2_v_min = p2_v_min_r;
    assign p2_v_max = p2_v_max_r;

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
    
endmodule