#include <stdint.h>
#include <pru_ctrl.h>

volatile register uint32_t __R31;
volatile uint32_t *shared = (volatile uint32_t *)0x00010000;

#define VSYNC (1u << 8) // bit 8
#define HREF (1u << 9) // bit 9
#define PCLK (1u << 10) // bit 10
#define MASK (VSYNC | HREF)

void main(void) {

    uint32_t frame_count = 0;
    uint32_t blank;
    uint32_t active;
    uint32_t max;
    uint32_t min;

    // initialize shared memeory
    int i;
    for (i = 0; i < 8; i++) {
        shared[i] = 0;
    }

    shared[0] = 0x50524230;
    PRU1_CTRL.CTRL_bit.CTR_EN = 0;
    PRU1_CTRL.CYCLE = 0;
    PRU1_CTRL.CTRL_bit.CTR_EN = 1;
        
    while (1) {
        uint32_t curr_r31 = __R31;
        // wait until vsync goes high
        while (!(curr_r31 & VSYNC)) {
            curr_r31 = __R31;
        }

        // now wait for vsync to go low
        while (curr_r31 & VSYNC) {
            curr_r31 = __R31;
        }

        min = UINT32_MAX;
        max = 0;
    
        for (i = 0; i < 240; i++) {
            blank = 0;
            // while HREF is low, count PCLK rising edges
            while (!(curr_r31 & HREF)) {
                // wait until pclk goes high
                while (!(curr_r31 & PCLK)) {
                    curr_r31 = __R31;
                }

                // now wait for pclk to go low
                while (curr_r31 & PCLK) {
                    curr_r31 = __R31;
                }
                blank++;
            }
            active = 0;
            // while HREF is high, count PCLK rising edges
            while (curr_r31 & HREF) {
                // wait until pclk goes high
                while (!(curr_r31 & PCLK)) {
                    curr_r31 = __R31;
                }

                // now wait for pclk to go low
                while (curr_r31 & PCLK) {
                    curr_r31 = __R31;
                }
                active++;
            }
            if (active < min) {
                min = active;
            }

            if (active > max) {
                max = active;
            }            
        }

        // write to shared ram
        shared[4] = min;
        shared[5] = max;
        shared[6] = blank;
        frame_count++;
        shared[7] = frame_count;
    }
}
