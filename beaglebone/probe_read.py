from config import PRU_SHARED_PHYS, PRU1_CTRL_PHYS, PROBE_MAGIC, PROBE_HEARTBEAT, PROBE_R31, PRU_CTRL_CYCLE, PROBE_MAGIC_VALUE, PROBE_FRAME_PERIOD, PROBE_VSYNC_WIDTH, PROBE_LINE_COUNT, PROBE_HREF_HIGH_TOTAL

import time
import os
import mmap

class PhysMem:
    def __init__(self, phys):
        self.fd = os.open("/dev/mem", os.O_RDONLY | os.O_SYNC)
        self.mm = mmap.mmap(self.fd, 4096, offset=phys,access=mmap.ACCESS_READ)
        self.words = memoryview(self.mm).cast("I")

    def word(self, i):
        return int(self.words[i])

    def decode_r31(self, r31):
        data = r31 & 0xFF
        vsync = (r31 >> 8) & 0x1
        href = (r31 >> 9) & 0x1
        pclk = (r31 >> 10) & 0x1
        return data, vsync, href, pclk

    def counter_status(self, prev, now):
        if (prev < now):
            return "counting"
        elif (prev > now):
            return "wrapped"
        elif (prev == 0xFFFFFFFF and now == 0xFFFFFFFF):
            return "stopped at max"
        else:
            return "stopped"


    def close(self):
        self.words.release()
        self.mm.close()
        os.close(self.fd)

def main():

    shared = PhysMem(PRU_SHARED_PHYS)
    ctrl = PhysMem(PRU1_CTRL_PHYS)

    prev_time = None
    prev_frame_count = None

    try:
        while(True):
            now = time.monotonic()
            magic = shared.word(0)
            minimum = shared.word(4)
            maximum = shared.word(5)
            blank = shared.word(6)
            frame_count = shared.word(7)

            if magic != PROBE_MAGIC_VALUE:
                print(f"INCORRECT MAGIC: 0x{magic:08x}")

            if (prev_frame_count is not None):
                print(f"elapsed time: {(now - prev_time) / (frame_count - prev_frame_count)}")
            else:
                print("elapsed time: division by zero")

            print(f"minimum: {minimum}")
            print(f"maximum: {maximum}")
            print(f"blank: {blank}")
            print(f"frame_count: {frame_count}")
            
            prev_time = now
            prev_frame_count = frame_count

            time.sleep(1)
    except KeyboardInterrupt: pass
    finally: shared.close(); ctrl.close()
    
if __name__ == "__main__":
    main()