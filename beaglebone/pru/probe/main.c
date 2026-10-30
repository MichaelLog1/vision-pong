#include <stdint.h>
#include <pru_ctrl.h>

volatile register uint32_t __R31;
volatile uint32_t *shared = (volatile uint32_t *)0x00010000;

#define VSYNC (1u << 8) // bit 8
#define HREF (1u << 9) // bit 9
#define MASK (VSYNC | HREF)

void main(void) {

    uint32_t prev_r31 = __R31;
    uint32_t href_rise = 0;
    uint32_t frame_period = 0;
    uint32_t vsync_width = 0;
    uint32_t line_count = 0;
    uint32_t href_high_total = 0;

    // initialize shared memeory
    for (int i = 0; i < 8; i++) {
        shared[i] = 0;
    }

    shared[0] = 0x50524230;
    PRU1_CTRL.CTRL_bit.CTR_EN = 0;
    PRU1_CTRL.CYCLE = 0;
    PRU1_CTRL.CTRL_bit.CTR_EN = 1;
        
    while (1) {

    

        // read r31 into a local
        uint32_t curr_r31 = __R31;
        uint32_t changed_r31 = (curr_r31 ^ prev_r31) & MASK; // tracks vsync and href bit changes
        uint32_t now = PRU1_CTRL.CYCLE; // keep track of where we're at

        // if no changes, go back
        if (!changed_r31) {
            continue;
        }

        uint32_t rise = changed_r31 & curr_r31;
        uint32_t fall = changed_r31 & ~curr_r31;

        // updates
        shared[1]++; // heartbeat
        shared[2] = curr_r31;
        shared[3] = now;

        // falling edge of vsync (frame start)
        if (fall & VSYNC) {
            frame_period = now;

            // write frame period, vsync width, line count, href high total to shared ram
            shared[4] = frame_period;
            shared[5] = vsync_width;
            shared[6] = line_count;
            shared[7] = href_high_total;

            line_count = 0;
            href_high_total = 0;

            // reset cycle
            PRU1_CTRL.CTRL_bit.CTR_EN = 0;
            PRU1_CTRL.CYCLE = 0;
            PRU1_CTRL.CTRL_bit.CTR_EN = 1;
        }

        if (rise & VSYNC) {
            vsync_width = now;
        }

        if (rise & HREF) {
            line_count++;
            href_rise = now;
        }

        if (fall & HREF) {
            href_high_total += (now - href_rise); // count how many cycles href has been high for
        }

        prev_r31 = curr_r31;
    }
}
