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

    def bytes_range(self, start, end):
        return self.mm[start:end]

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
    prev_captures = 0

    try:
        while(True):
            captures = shared.word(4)
            if (prev_captures == captures):
                prev_captures = captures
                time.sleep(0.003)
                continue

            # captures has changed, we have a new line to read
            now = time.monotonic()

            # read pixel data, starting from byte 64 to 703
            pixel_data = []
            for i in shared.bytes_range(64, 704):
                pixel_data.append(i)

            magic = shared.word(0)
            bytes_in_line = shared.word(1)
            minimum = shared.word(2)
            maximum = shared.word(3)

            if magic != PROBE_MAGIC_VALUE:
                print(f"INCORRECT MAGIC: 0x{magic:08x}")

            print(f"bytes in line: {bytes_in_line}")

            # do something with the pixels
            for i in range(8):
                u_sum = 0
                v_sum = 0
                y1_sum = 0
                y0_sum = 0
                for j in range(80):
                    if (j % 4 == 0):
                        u_sum += pixel_data[i*80 + j]
                    elif (j % 4 == 1):
                        y0_sum += pixel_data[i*80 + j]
                    elif (j % 4 == 2):
                        v_sum += pixel_data[i*80 + j]
                    elif (j % 4 == 3):
                        y1_sum += pixel_data[i*80 + j]
                u = u_sum / 20
                v = v_sum / 20
                y0 = y0_sum / 20
                y1 = y1_sum / 20
                print(f"U: {u}, Y0: {y0}, V: {v}, Y1: {y1}")
            prev_time = now
            prev_captures = captures

            time.sleep(1)
    except KeyboardInterrupt: pass
    finally: shared.close(); ctrl.close()
    
if __name__ == "__main__":
    main()