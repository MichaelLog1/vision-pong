from config import PRU_SHARED_PHYS, PRU1_CTRL_PHYS, PROBE_MAGIC, PROBE_HEARTBEAT, PROBE_R31, PRU_CTRL_CYCLE, PROBE_MAGIC_VALUE

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
            magic = shared.word(PROBE_MAGIC)
            heartbeat = shared.word(PROBE_HEARTBEAT)
            r31 = shared.word(PROBE_R31)
            cycle = ctrl.word(PRU_CTRL_CYCLE)

            # magic
            if (magic == PROBE_MAGIC_VALUE):
                print(f"Magic: 0x{magic:08x} Magic Correct")
            else:
                print(f"Magic: 0x{magic:08x} MAGIC INCORRECT")

            # heartbeat
            if prev_heartbeat is not None and prev_time is not None:
                print(f"Heartbeat change/s: {((heartbeat - prev_heartbeat) & 0xFFFFFFFF) / (now - prev_time)}")

            # r31
            data, vsync, href, pclk = shared.decode_r31(r31)
            print(f"r31 data: 0x{data:02x}, vsync: {vsync}, href: {href}, pclk: {pclk}")

            # cycle
            print(f"Cycle: 0x{cycle:08x}")
            if prev_cycle is not None and prev_time is not None:
                print(f"Cycle change/s: {((cycle - prev_cycle) & 0xFFFFFFFF) / (now - prev_time)}")
                if (heartbeat == prev_heartbeat):
                    print("HEARTBEAT STALLED")
                else:
                    print(f"Cycle change/loop: {((cycle - prev_cycle) & 0xFFFFFFFF) / ((heartbeat - prev_heartbeat) & 0xFFFFFFFF)}")
                print(f"Cycle status: {ctrl.counter_status(cycle, prev_cycle)}")
            
            prev_heartbeat = heartbeat
            prev_cycle = cycle
            prev_time = now

            time.sleep(1)
    except KeyboardInterrupt: pass
    finally: shared.close(); ctrl.close()
    
if __name__ == "__main__":
    main()