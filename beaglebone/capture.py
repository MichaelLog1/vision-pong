from config import FRAME_HEIGHT, FRAME_WIDTH, FRAME_BYTES, RING_PHYS, PRU_SHARED_PHYS, RING_SLOT0_OFFSET, RING_SLOT_HEADER_BYTES, RING_MAGIC_INDEX, RING_WIDTH_INDEX, RING_HEIGHT_INDEX, RING_BPP_INDEX, RING_BPF_INDEX, RING_NUM_SLOTS_INDEX, RING_STRIDE_INDEX, RING_HEAD_INDEX, RING_SEQ_INDEX, RING_MAGIC_VALUE, RING_BPP_VALUE, RING_NUM_SLOTS_VALUE, RING_SLOT_STRIDE_VALUE, RING_T_VSYNC_OFFSET, RING_T_DONE_OFFSET, RING_FLAGS_OFFSET

from dataclasses import dataclass
import numpy as np
import mmap
import os
import time

@dataclass
class CapturedFrame:
    seq: np.uint32 # frame number from PRU
    t_vsync: np.uint32 # PRU cycle count at vsync
    t_done: np.uint32 # PRU cycle count at last pixel
    flags: np.uint8
    frame: np.ndarray

class FileFrameSource:
    def __init__(self, files, frame_size = FRAME_HEIGHT*FRAME_WIDTH*2, loop=True):
        if (len(files) == 0):
            raise ValueError("Must pass at least one file")

        self.file_content = []
        for file in files:
            c = np.fromfile(file, dtype=np.uint8)
            if (len(c) != frame_size):
                raise ValueError(f"frame size inconsistent with size parameter. filename: {file}")
            self.file_content.append(c)
            
        self.frame_size = frame_size
        self.loop = loop
        self.index = 0
        self.seq_counter = 0
        
    def next_frame(self):
        if ((self.index == len(self.file_content)) and not self.loop):
            return None

        self.seq_counter = self.seq_counter + 1

        cap = CapturedFrame(self.seq_counter, 0, 0, 0, self.file_content[self.index])
        self.index = self.index + 1
        if ((self.index == len(self.file_content)) and self.loop):
            self.index = 0
        return cap

    def close(self):
        return


class PruFrameSource:
    def __init__(self, dev_path = "/dev/mem", timeout=0.2):
        self.timeout = timeout
        self.fd = os.open(dev_path, os.O_RDONLY | os.O_SYNC)
        self.ring = mmap.mmap(self.fd, 0x98000, offset=RING_PHYS, access=mmap.ACCESS_READ)
        self.shared = mmap.mmap(self.fd, 4096, offset=PRU_SHARED_PHYS, access=mmap.ACCESS_READ)
        self.ring_words = memoryview(self.ring).cast("I")
        self.shared_words = memoryview(self.shared).cast("I")

        self.slot_offset = [
            (RING_SLOT0_OFFSET),
            (RING_SLOT0_OFFSET + RING_SLOT_STRIDE_VALUE),
            (RING_SLOT0_OFFSET + 2 * RING_SLOT_STRIDE_VALUE),
            (RING_SLOT0_OFFSET + 3 * RING_SLOT_STRIDE_VALUE)
        ]

        self.prev_ring_seq = 0
        self.frames_dropped = 0
        self.frames_flagged = 0
        self.frames_torn = 0

        # start up checks
        # magic
        ring_magic = self.ring_words[RING_MAGIC_INDEX]
        if (ring_magic != RING_MAGIC_VALUE):
            raise RuntimeError(f"INCORRECT RING MAGIC: 0x{ring_magic:08x}")

        # width
        ring_width = self.ring_words[RING_WIDTH_INDEX]
        if (ring_width != FRAME_WIDTH):
            raise RuntimeError(f"INCORRECT RING WIDTH: 0x{ring_width:08x}")

        # height
        ring_height = self.ring_words[RING_HEIGHT_INDEX]
        if (ring_height != FRAME_HEIGHT):
            raise RuntimeError(f"INCORRECT RING HEIGHT: 0x{ring_height:08x}")

        # bytes per pixel
        ring_bpp = self.ring_words[RING_BPP_INDEX]
        if (ring_bpp != RING_BPP_VALUE):
            raise RuntimeError(f"INCORRECT RING BPP: 0x{ring_bpp:08x}")

        # bytes per frame
        ring_frame_size = self.ring_words[RING_BPF_INDEX]
        if (ring_frame_size != FRAME_BYTES):
            raise RuntimeError(f"INCORRECT RING FRAME SIZE: 0x{ring_frame_size:08x}")

        # num slots
        ring_num_slots = self.ring_words[RING_NUM_SLOTS_INDEX]
        if (ring_num_slots != RING_NUM_SLOTS_VALUE):
            raise RuntimeError(f"INCORRECT RING NUM SLOTS: 0x{ring_num_slots:08x}")

        # stride
        ring_stride = self.ring_words[RING_STRIDE_INDEX]
        if (ring_stride != RING_SLOT_STRIDE_VALUE):
            raise RuntimeError(f"INCORRECT RING SLOT STRIDE: 0x{ring_stride:08x}")


    def next_frame(self):
        deadline = time.monotonic() + self.timeout

        while (True):
            # check timeout
            if (time.monotonic() >= deadline):
                return None

            ring_seq = self.ring_words[RING_SEQ_INDEX]
            if (ring_seq == self.prev_ring_seq):
                time.sleep(0.003)
                continue
            
            ring_head = self.ring_words[RING_HEAD_INDEX]
            if (ring_head > 3):
                raise RuntimeError(f"ring_head incorrect")
    
            slot_offset = self.slot_offset[ring_head]
            slot_word_index = slot_offset // 4
            prev_slot_seq = self.ring_words[slot_word_index]

            # read the frame
            frame = np.frombuffer(self.ring[slot_offset + RING_SLOT_HEADER_BYTES:slot_offset + RING_SLOT_HEADER_BYTES + FRAME_BYTES], dtype=np.uint8)
            
            # get timing data
            t_vsync = self.ring_words[slot_word_index + RING_T_VSYNC_OFFSET]
            t_done = self.ring_words[slot_word_index + RING_T_DONE_OFFSET]
            flags = self.ring_words[slot_word_index + RING_FLAGS_OFFSET]

            # curr_slot_seq == 0 means the frame is currently being written
            curr_slot_seq = self.ring_words[slot_word_index]

            # frame is torn if the slot head has changed
            if (curr_slot_seq != prev_slot_seq or curr_slot_seq == 0):
                # PRU started rewriting the slot during the copy
                self.frames_torn = self.frames_torn + 1
                continue

            # frames have been dropped if the frame counter increments more than once
            if (self.prev_ring_seq != 0):
                self.frames_dropped = self.frames_dropped + curr_slot_seq - self.prev_ring_seq - 1

            # check firmware flags
            if (flags != 0):
                self.frames_flagged = self.frames_flagged + 1
                self.prev_ring_seq = prev_slot_seq
                continue

            # update state
            self.prev_ring_seq = prev_slot_seq
            return CapturedFrame(prev_slot_seq, t_vsync, t_done, flags, frame)

    def close(self):
        self.ring_words.release()
        self.shared_words.release()
        self.ring.close()
        self.shared.close()
        os.close(self.fd)

    def status(self):
        stage = self.shared_words[1]
        frame_count = self.shared_words[2]
        frames_flagged_firmware = self.shared_words[3]
        return stage, frame_count, frames_flagged_firmware, self.frames_dropped, self.frames_torn, self.frames_flagged

def save_frame(path, frame):
    frame.tofile(path)