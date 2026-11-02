#include <stdint.h>
#include <pru_ctrl.h>
#include <pru_cfg.h>

#define RING_BASE   0x9FE00000
#define FRAME_BYTES (320 * 240 * 2)
#define SLOT_HDR    64
#define SLOT_STRIDE (FRAME_BYTES + SLOT_HDR)
#define SLOT0       (RING_BASE + 0x1000)
#define VSYNC       (1u << 8) // bit 8
#define HREF        (1u << 9) // bit 9
#define PCLK        (1u << 10) // bit 10

typedef enum {
    STARTING,
    WAITING_FOR_VSYNC,
    CAPTURING,
    PUBLISHING,
    DDR_TEST_FAILED
} state_t;

volatile register uint32_t __R31;
volatile uint32_t *shared = (volatile uint32_t *)0x00010000; // PRU shared ram
volatile uint32_t *ring = (volatile uint32_t *)0x9FE00000; // DDR
uint32_t buffer[160]; // 4 * 160 = 640 byte buffer

void main(void) {
    uint8_t *write_ptr = (uint8_t *)buffer;
    uint32_t slot_base;
    volatile uint32_t *slot_hdr;
    volatile uint32_t *pixels;
    volatile uint32_t temp_force;
    uint32_t slot = 3;
    int i, j;

    uint32_t frame_counter = 0;
    uint32_t flagged_frames = 0;
    uint32_t t_done;
    uint8_t frame_flags;

    

    // write shared ram init values
    shared[0] = 0x31435056;         // magic
    shared[1] = (uint32_t)STARTING; // stage
    shared[2] = 0;                  // frame count
    shared[3] = 0;                  // flagged frames
    shared[4] = 0;                  // self test results (if this bit is asserted, DDR doesnt work)

    ring[0] = 0;
    // clear standy init
    CT_CFG.SYSCFG_bit.STANDBY_INIT = 0;

    // test the DDR
    ring[0] = 0xF0F0F0F0;
    if (ring[0] != 0xF0F0F0F0) {
        // set stage to error and loop forever
        shared[1] = (uint32_t)DDR_TEST_FAILED;
        shared[4] = 1;
        while (1);
    }

    // write ring header
    ring[1] = 0;          // placeholder
    ring[2] = 320;        // width
    ring[3] = 240;        // height
    ring[4] = 2;          // bytes per pixel
    ring[5] = 153600;     // bytes per frame
    ring[6] = 4;          // number of memory slots
    ring[7] = 153664;     // stride between slots
    ring[8] = slot;       // last slot written
    ring[9] = 0;          // frame counter (heartbeat)
    ring[10] = 0;         // dropped frames
    ring[11] = 200000000; // pru clock rate
    ring[0] = 0x31435056; // magic



    // reset CYCLE count and enable it
    PRU1_CTRL.CTRL_bit.CTR_EN = 0;
    PRU1_CTRL.CYCLE = 0;
    PRU1_CTRL.CTRL_bit.CTR_EN = 1;

    while (1) {

        // reset flags
        frame_flags = 0;

        shared[1] = (uint32_t)WAITING_FOR_VSYNC;

        // wait for VSYNC fall
        while (!(__R31 & VSYNC));
        while (__R31 & VSYNC);

        PRU1_CTRL.CTRL_bit.CTR_EN = 0;
        PRU1_CTRL.CYCLE = 0;
        PRU1_CTRL.CTRL_bit.CTR_EN = 1;

        slot = (slot + 1) % 4;
        slot_base = SLOT0 + slot * SLOT_STRIDE;
        slot_hdr = (volatile uint32_t *)slot_base;
        pixels = (volatile uint32_t *)(slot_base + SLOT_HDR);

        slot_hdr[0] = 0; // update seq
        shared[1] = (uint32_t)CAPTURING;

        // handle each of the 240 lines
        for (i = 0; i < 240; i++) {
            
            write_ptr = (uint8_t *)buffer;
            // wait for HREF to go high
            while (!(__R31 & HREF));

            while (__R31 & HREF) {
                // wait until pclk goes high
                while (!(__R31 & PCLK));

                // pixel data should be ready now
                *(write_ptr++) = __R31 & 0xFF;

                // wait for pclk to go low
                while (__R31 & PCLK);
            }
            
            // check to make sure we got all 640 bytes
            if (write_ptr - (uint8_t *)buffer != 640) {
                frame_flags |= 0x2; // set bit 1
            }

            // copy local buffer into DDR
            for (j = 0; j < 160; j++) {
                pixels[i * 160 + j] = buffer[j];
            }

            // if HREF has already risen, set a flag
            if (__R31 & HREF) {
                frame_flags |= 0x1; // set bit 0

            }
        }
        t_done = PRU1_CTRL.CYCLE;
        frame_counter++;

        // force a read to DDR to make sure everything's done writing
        temp_force = pixels[239 * 160 + 159]; // the last pixel

        shared[1] = (uint32_t)PUBLISHING;

        // update slot header
        slot_hdr[1] = 0; // t_vsync (this will always be zero since we're just resetting CYCLE for now)
        slot_hdr[2] = t_done; // t_done
        slot_hdr[3] = frame_flags; // flags
        slot_hdr[0] = frame_counter;
        
        // update ring header
        ring[8] = slot;
        ring[9] = frame_counter;

        // update shared status
        shared[2] = frame_counter;
        if (frame_flags != 0) {
            flagged_frames++;
            shared[3] = flagged_frames;
        }
    }
        
}
