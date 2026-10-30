#include <stdint.h>
#include <pru_ctrl.h>

volatile register uint32_t __R31;
volatile uint32_t *shared = (volatile uint32_t *)0x00010000;

void main(void) {

    shared[0] = 0;
    shared[1] = 0;
    shared[2] = 0;
    shared[3] = 0;
    
    shared[0] = 0x50524230; // ASCII for "PRB0"
    PRU1_CTRL.CTRL_bit.CTR_EN = 0;
    PRU1_CTRL.CYCLE = 0;
    PRU1_CTRL.CTRL_bit.CTR_EN = 1;

        
    while (1) {
        shared[1]++;       // heartbeat
        shared[2] = __R31; // live pin states
        shared[3] = PRU1_CTRL.CYCLE;
    }
}
