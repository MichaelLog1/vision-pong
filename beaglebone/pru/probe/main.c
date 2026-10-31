#include <stdint.h>
#include <pru_ctrl.h>

volatile register uint32_t __R31;
volatile uint32_t *shared = (volatile uint32_t *)0x00010000;
volatile uint8_t *buffer = (volatile uint8_t *)(0x10000 + 64);

#define VSYNC (1u << 8) // bit 8
#define HREF (1u << 9) // bit 9
#define PCLK (1u << 10) // bit 10
#define BUFFER_OFFSET 0x10000 + 64

void main(void) {

    volatile uint8_t *local_buffer = (volatile uint8_t *)(BUFFER_OFFSET);

    uint32_t bytes_in_line = 0;
    uint32_t captures = 0;
    uint32_t last_min_bytes = UINT32_MAX;
    uint32_t last_max_bytes = 0;
    uint32_t active = 0;

    int i;

    // initialize shared memory
    shared[0] = 0x50524230; // magic
    shared[1] = bytes_in_line;
    shared[2] = last_min_bytes;
    shared[3] = last_max_bytes;
    shared[4] = captures;

    // reset CYCLE count and enable the PRU
    PRU1_CTRL.CTRL_bit.CTR_EN = 0;
    PRU1_CTRL.CYCLE = 0;
    PRU1_CTRL.CTRL_bit.CTR_EN = 1;

    while (1) {
        
        // wait until vsync goes high
        while (!(__R31 & VSYNC));

        // now wait for vsync to go low
        while (__R31 & VSYNC);

        local_buffer = (volatile uint8_t *)(BUFFER_OFFSET);
        bytes_in_line = 0;
        last_min_bytes = UINT32_MAX;
        last_max_bytes = 0;
    
        for (i = 0; i < 240; i++) {
            if (i == 120) {
                active = 0;
                // wait for HREF to go high, signaling a new line
                while (!(__R31 & HREF));

                while (__R31 & HREF) {
                    // wait until pclk goes high
                    while (!(__R31 & PCLK));

                    // pixel data should be ready now
                    *(local_buffer++) = __R31 & 0xFF;
                    bytes_in_line++;
                    active++;

                    // now wait for pclk to go low
                    while (__R31 & PCLK);
                }

                if (active < last_min_bytes) {
                    last_min_bytes = active;
                }

                if (active > last_max_bytes) {
                    last_max_bytes = active;
                }  
            } else {
                // wait for HREF to go high, signaling a new line
                while (!(__R31 & HREF));

                // wait for HREF to go low
                while (__R31 & HREF);
            }            
        }

        shared[1] = bytes_in_line;
        shared[2] = last_min_bytes;
        shared[3] = last_max_bytes;
        shared[4] = ++captures;
    }
}
