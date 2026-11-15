module thumbnail #(
    parameter int unsigned WIDTH = 160,
    parameter int unsigned HEIGHT = 240
) (
    input logic clk,
    input logic rst_n,
    input logic pipe_rst_n,
    input logic [1:0] stage_sel,
    // chroma stage
    input logic c_valid,
    input logic c_sof,
    input logic c_eol,
    input logic c_eof,
    input logic [7:0] c_u,
    input logic [7:0] c_y0,
    input logic [7:0] c_v,
    input logic [7:0] c_y1,
    // threshold stage (both thresholds should be aligned)
    input logic t_valid,
    input logic t_sof,
    input logic t_eol,
    input logic t_eof,
    input logic t_mask1,
    input logic t_mask2,
    // erode stage (both erodes should be aligned)
    input logic e_valid,
    input logic e_sof,
    input logic e_eol,
    input logic e_eof,
    input logic e_mask1,
    input logic e_mask2,
    // control
    input logic swap,
    input logic advance,
    output logic new_frame,
    output logic [1:0] buf_stage,
    output logic [7:0] data
    

);
    localparam int unsigned DECIMATED_WIDTH = WIDTH/2;
    localparam int unsigned DECIMATED_HEIGHT = HEIGHT/4;
    localparam int unsigned BRAM_SIZE = DECIMATED_HEIGHT*DECIMATED_WIDTH;
    localparam int unsigned BRAM_WIDTH = 16;

    typedef enum logic [1:0] {
        STAGE_RAW,
        STAGE_CHROMA,
        STAGE_THRESHOLD,
        STAGE_ERODE
    } stage_t;

    typedef enum logic {
        IDLE,
        WRITING
    } state_t;
    state_t state_r;

    stage_t frame_stage_r;
    logic [$clog2(WIDTH)-1:0] col_r;
    logic [$clog2(HEIGHT)-1:0] row_r;
    logic frame_done_r;
    logic [$clog2(BRAM_SIZE)-1:0] write_ptr_r; // 13 bits
    logic [$clog2(BRAM_SIZE):0] read_ptr_r; // 14 bits: 13:1 is the address 0 is the byte select
    logic wr_buf_r;
    logic rd_buf_r;
    logic [BRAM_WIDTH-1:0] ping_pong [2**($clog2(BRAM_SIZE)+1)]; // indexed {wr/rd_buf_r, write_ptr_r} for ping pong
    logic wr_en;
    logic [$clog2(BRAM_SIZE):0] wr_addr; // 14 bits
    logic [$clog2(BRAM_SIZE):0] rd_addr; // 14 bits
    logic [BRAM_WIDTH-1:0] wr_data;
    logic [BRAM_WIDTH-1:0] rd_data; 
    logic new_frame_r;
    logic [1:0] buf_stage_r;
    logic [1:0] wr_stage_r;

    logic m_valid;
    logic m_sof;
    logic m_eol;
    logic m_eof;
    logic [15:0] m_pixel;

    logic keep;

    // colorizer rgb registers
    logic signed [7:0] c_u_centered;
    logic signed [7:0] c_v_centered;
    logic signed [18:0] rgb_r_acc;
    logic signed [18:0] rgb_g_acc;
    logic signed [18:0] rgb_b_acc;
    logic [7:0] rgb_r;
    logic [7:0] rgb_g;
    logic [7:0] rgb_b;

    // rgb comb
    logic signed [18:0] rgb_r_scaled, rgb_g_scaled, rgb_b_scaled;

    // colorizer false color registers
    logic [7:0] c_u_raw [2];
    logic [7:0] c_v_raw [2];
    logic [7:0] c_y0_raw [2];
    logic [7:0] false_u;
    logic [7:0] false_v;
    logic [7:0] false_y0;

    // colorizer latency delay registers
    logic [2:0] c_valid_delay;
    logic [2:0] c_sof_delay;
    logic [2:0] c_eol_delay;
    logic [2:0] c_eof_delay;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            frame_stage_r <= STAGE_RAW;
        end else begin
            if (c_valid && c_sof) begin
                frame_stage_r <= stage_t'(stage_sel);
            end
        end
    end

    // stage muxes
    always_comb begin
        if (frame_stage_r == STAGE_RAW) begin
            m_valid = c_valid_delay[2];
            m_sof = c_sof_delay[2];
            m_eol = c_eol_delay[2];
            m_eof = c_eof_delay[2];
            m_pixel = { rgb_b[7:3], rgb_g[7:2], rgb_r[7:3] };
        end else if (frame_stage_r == STAGE_CHROMA) begin
            m_valid = c_valid_delay[2];
            m_sof = c_sof_delay[2];
            m_eol = c_eol_delay[2];
            m_eof = c_eof_delay[2];
            m_pixel = { false_u[7:3], false_y0[7:2], false_v[7:3] };
        end else if (frame_stage_r == STAGE_THRESHOLD) begin
            m_valid = t_valid;
            m_sof = t_sof;
            m_eol = t_eol;
            m_eof = t_eof;
            if ({ t_mask2, t_mask1 } == 2'b11) begin
                m_pixel = 16'hFFFF;
            end else if ({ t_mask2, t_mask1 } == 2'b10) begin
                m_pixel = 16'hF800;
            end else if ({ t_mask2, t_mask1 } == 2'b01) begin
                m_pixel = 16'h001F;
            end else begin
                m_pixel = 16'h0000;
            end
        end else begin
            m_valid = e_valid;
            m_sof = e_sof;
            m_eol = e_eol;
            m_eof = e_eof;
            if ({ e_mask2, e_mask1 } == 2'b11) begin
                m_pixel = 16'hFFFF;
            end else if ({ e_mask2, e_mask1 } == 2'b10) begin
                m_pixel = 16'hF800;
            end else if ({ e_mask2, e_mask1 } == 2'b01) begin
                m_pixel = 16'h001F;
            end else begin
                m_pixel = 16'h0000;
            end
        end
    end

    // decimate by 4 (for the x axis in uyvy, this is every other pixel)
    assign keep = (col_r[0] == 0) && (row_r[1:0] == 0);

    // writer fsm
    always_ff @(posedge clk) begin
        if (!rst_n || !pipe_rst_n) begin
            state_r <= IDLE;
            frame_done_r <= 1'b0;
            col_r <= '0;
            row_r <= '0;
            wr_en <= 1'b0;
        end else begin
            frame_done_r <= 1'b0;
            wr_en <= 1'b0;
            case (state_r)
                IDLE: begin
                    // 
                    if (m_valid && m_sof && !new_frame_r && !(c_valid && c_sof && stage_sel != frame_stage_r)) begin
                        col_r <= 1;
                        row_r <= '0;
                        write_ptr_r <= '0;
                        wr_buf_r <= !rd_buf_r;
                        // write this pixel to index 0
                        wr_en <= 1'b1;
                        wr_addr <= {!rd_buf_r, ($clog2(BRAM_SIZE))'(0)};

                        // send colors depending on stage
                        wr_data <= m_pixel;

                        write_ptr_r <= 1;

                        // latch buf stage
                        wr_stage_r <= frame_stage_r;
                        
                        state_r <= WRITING;
                    end
                end

                WRITING: begin
                    if (m_valid) begin
                        // if we keep this, write it to bram
                        if (keep) begin
                            wr_en <= 1'b1;
                            wr_addr <= {wr_buf_r, write_ptr_r};

                            // send colors depending on stage
                            wr_data <= m_pixel;
                            
                            write_ptr_r <= write_ptr_r + 1;
                        end

                        // update row and col
                        col_r <= col_r + 1;

                        if (m_eol) begin
                            row_r <= row_r + 1;
                            col_r <= '0;
                        end

                        if (m_eof) begin
                            state_r <= IDLE;
                            // only signal a finished frame if all addresses have been written
                            if (write_ptr_r == BRAM_SIZE) begin
                                frame_done_r <= 1'b1;
                            end
                        end


                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (wr_en) begin
            ping_pong[wr_addr] <= wr_data;
        end

        rd_data <= ping_pong[rd_addr];
    end

    // swap logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            new_frame_r <= 1'b0;
            rd_buf_r <= 1'b1;
            read_ptr_r <= '0;
            buf_stage_r <= '0;
        end else begin
            if (frame_done_r) begin
                new_frame_r <= 1'b1;
            end

            if (advance && (read_ptr_r < 2*BRAM_SIZE)) begin
                read_ptr_r <= read_ptr_r + 1;
            end
            
            if (swap && new_frame_r) begin
                new_frame_r <= 1'b0;
                rd_buf_r <= !rd_buf_r;
                buf_stage_r <= wr_stage_r;
                read_ptr_r <= '0;
            end
        end
    end

    assign rd_addr = {rd_buf_r, read_ptr_r[13:1]};

    assign new_frame = new_frame_r;
    assign data = (read_ptr_r == 2*BRAM_SIZE) ? '0 : (read_ptr_r[0]) ? rd_data[7:0] : rd_data[15:8]; // byte select
    assign buf_stage = buf_stage_r;

    // colorizer pipeline
    always_ff @(posedge clk) begin
        // flip the msb and convert to signed to center around 0
        c_u_centered <= c_u ^ 8'h80;
        c_v_centered <= c_v ^ 8'h80;
        c_y0_raw[0] <= c_y0;
        c_u_raw[0] <= c_u;
        c_v_raw[0] <= c_v;

        // multiply adds
        rgb_r_acc <= ($signed({1'b0, c_y0_raw[0]}) << 8) + (359*c_v_centered);
        rgb_g_acc <= ($signed({1'b0, c_y0_raw[0]}) << 8) - (88*c_u_centered) - (183*c_v_centered);
        rgb_b_acc <= ($signed({1'b0, c_y0_raw[0]}) << 8) + (454*c_u_centered);
        c_u_raw[1] <= c_u_raw[0];
        c_v_raw[1] <= c_v_raw[0];
        c_y0_raw[1] <= c_y0_raw[0];

        // scale back, clamp, pack
        rgb_r <= rgb_r_scaled[18] ? 0 : (rgb_r_scaled > 255) ? 255 : rgb_r_scaled[7:0];
        rgb_g <= rgb_g_scaled[18] ? 0 : (rgb_g_scaled > 255) ? 255 : rgb_g_scaled[7:0];
        rgb_b <= rgb_b_scaled[18] ? 0 : (rgb_b_scaled > 255) ? 255 : rgb_b_scaled[7:0];

        false_u <= c_u_raw[1];
        false_v <= c_v_raw[1];
        false_y0 <= c_y0_raw[1];
    end

    assign rgb_r_scaled = rgb_r_acc >>> 8;
    assign rgb_g_scaled = rgb_g_acc >>> 8;
    assign rgb_b_scaled = rgb_b_acc >>> 8;

    // colorizer strobe delays
    always_ff @(posedge clk) begin
        if (!rst_n || !pipe_rst_n) begin
            c_valid_delay <= '0;
            c_sof_delay <= '0;
            c_eol_delay <= '0;
            c_eof_delay <= '0;
        end else begin
            c_valid_delay[0] <= c_valid;
            c_sof_delay[0] <= c_sof;
            c_eol_delay[0] <= c_eol;
            c_eof_delay[0] <= c_eof;

            c_valid_delay[1] <= c_valid_delay[0];
            c_sof_delay[1] <= c_sof_delay[0];
            c_eol_delay[1] <= c_eol_delay[0];
            c_eof_delay[1] <= c_eof_delay[0];

            c_valid_delay[2] <= c_valid_delay[1];
            c_sof_delay[2] <= c_sof_delay[1];
            c_eol_delay[2] <= c_eol_delay[1];
            c_eof_delay[2] <= c_eof_delay[1];            
        end
    end
endmodule