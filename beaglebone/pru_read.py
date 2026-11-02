from config import PRU_SHARED_PHYS, RING_PHYS, RING_MAGIC_VALUE, RING_SLOT0_OFFSET, RING_SLOT_STRIDE, RING_SLOT_HEADER_BYTES, FRAME_BYTES, RING_SLOT_HEADER_FLAGS

import time
import os
import mmap

class PhysMem:
    def __init__(self, phys, size):
        self.fd = os.open("/dev/mem", os.O_RDONLY | os.O_SYNC)
        self.mm = mmap.mmap(self.fd, size, offset=phys,access=mmap.ACCESS_READ)
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
    prev_ring_seq = 0
    frames_dropped = 0
    frames_flagged = 0
    last_print_time = time.monotonic()

    frame_saved = False

    # physical memory handles
    shared = PhysMem(PRU_SHARED_PHYS, 4096)
    ring = PhysMem(RING_PHYS, 0x98000)

    # read magic, ensure its correct
    ring_magic = ring.word(0)
    if (ring_magic != RING_MAGIC_VALUE):
        print(f"INCORRECT RING MAGIC: 0x{ring_magic:08x}")
        exit(1)

    try:
        while (True):
            # once a second
            if (time.monotonic() - last_print_time > 1):
                last_print_time = time.monotonic()
                print(f"Stage: {shared.word(1)}")
                print(f"Frame count: {shared.word(2)}")
                print(f"Frames dropped: {frames_dropped}")
                print(f"Frames flagged by reader: {frames_flagged}")
                print(f"Frames flagged by firmware: {shared.word(3)}")

            ring_seq = ring.word(9)
            if (ring_seq == prev_ring_seq):
                time.sleep(0.003)
                continue

            ring_head = ring.word(8)
            slot_offset = (RING_SLOT0_OFFSET + ring_head * RING_SLOT_STRIDE)
            slot_word_index = slot_offset // 4
            prev_slot_seq = ring.word(slot_word_index)

            # read the frame
            pixel_data = ring.bytes_range(slot_offset + RING_SLOT_HEADER_BYTES, slot_offset + RING_SLOT_HEADER_BYTES + FRAME_BYTES)

            curr_slot_seq = ring.word(slot_word_index)
            # curr_slot_seq == 0 means the frame is currently being written
            if (curr_slot_seq != prev_slot_seq or curr_slot_seq == 0):
                # PRU started rewriting the slot during the copy
                continue

            if (prev_ring_seq != 0):
                frames_dropped = frames_dropped + curr_slot_seq - prev_ring_seq - 1

            # check slot's flags
            flags = ring.word(slot_word_index + RING_SLOT_HEADER_FLAGS)
            if (flags != 0):
                frames_flagged = frames_flagged + 1
                prev_ring_seq = prev_slot_seq
                continue

            # do stuff with the frame
            if (not frame_saved):
                with open("frame.bin", "wb") as file:
                    file.write(pixel_data)
                frame_Saved = True

            # update state
            prev_ring_seq = prev_slot_seq


    except KeyboardInterrupt: pass
    finally: shared.close(); ring.close()
    
if __name__ == "__main__":
    main()