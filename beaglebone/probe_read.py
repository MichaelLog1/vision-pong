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
    prev_heartbeat = None
    prev_cycle = None

    try:
        while(True):
            now = time.monotonic()
            magic = shared.word(PROBE_MAGIC)                     # shared[0]
            heartbeat = shared.word(PROBE_HEARTBEAT)             # shared[1]
            r31 = shared.word(PROBE_R31)                         # shared[2]
            cycle = ctrl.word(PRU_CTRL_CYCLE)                    # shared[3] and crtl[3]
            frame_period = shared.word(PROBE_FRAME_PERIOD)       # shared[4]
            vsync_width = shared.word(PROBE_VSYNC_WIDTH)         # shared[5]
            line_count = shared.word(PROBE_LINE_COUNT)           # shared[6]
            href_high_total = shared.word(PROBE_HREF_HIGH_TOTAL) # shared[7]

            # magic
            if (magic != PROBE_MAGIC_VALUE):
                print(f"Magic: 0x{magic:08x} MAGIC INCORRECT")

            # heartbeat
            if prev_heartbeat is not None and prev_time is not None:
                print(f"Heartbeat change/s: {((heartbeat - prev_heartbeat) & 0xFFFFFFFF) / (now - prev_time)}")

            # cycle
            print(f"Cycle: 0x{cycle:08x}")

            if (frame_period == 0):
                print(f"fps: divide by zero")
            else:
                print(f"fps: {200000000 / frame_period}")

            print(f"lines/frame: {line_count}")
            print(f"vsync pulse width: {vsync_width / 200} us")

            if (line_count == 0):
                print(f"estimated PCLK: divide by zero")
                print(f"timer/active line: divide by zero")
            else:
                print(f"timer/active line: {href_high_total/line_count/200} us")
                print(f"estimated PCLK: {640 / (href_high_total/line_count) * 200} MHz")

            # pixel data
            data, vsync, href, pclk = shared.decode_r31(r31)
            print(f"r31 data: 0x{data:02x}, vsync: {vsync}, href: {href}, pclk: {pclk}")

            
            
            prev_heartbeat = heartbeat
            prev_cycle = cycle
            prev_time = now

            time.sleep(1)
    except KeyboardInterrupt: pass
    finally: shared.close(); ctrl.close()
    
if __name__ == "__main__":
    main()