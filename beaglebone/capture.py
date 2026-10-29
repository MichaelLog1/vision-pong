from config import FRAME_HEIGHT, FRAME_WIDTH, RING_SIZE, RING_PHYS, RING_MAGIC, RING_VERSION, HDR_VERSION, HDR_WIDTH, HDR_HEIGHT, HDR_BPP, HDR_FRAME_BYTES, HDR_N_SLOTS, HDR_STRIDE, SLOT_HEADER_BYTES, SLOT_SEQ, SLOT0_OFFSET

from dataclasses import dataclass
import numpy as np
import mmap
import os

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
    def __init__(self, dev_path = "/dev/mem", map_size=RING_SIZE, map_offset=RING_PHYS, timeout=0.2):
        if (map_offset % mmap.ALLOCATIONGRANULARITY != 0):
            raise ValueError(f"offset needs to be a multiple of {mmap.ALLOCATIONGRANULARITY}")
        self.fd = os.open(dev_path, os.O_RDONLY | os.O_SYNC)
        self.mm = mmap.mmap(self.fd, map_size, offset=map_offset, access=mmap.ACCESS_READ)
        
        self.hdr = np.frombuffer(self.mm, dtype=np.uint32, count=16, offset=0)

        if (bytes(self.mm[0:4]) != RING_MAGIC):
            raise ValueError("Magic incorrect.")

        if (int(self.hdr[HDR_VERSION]) != RING_VERSION):
            raise ValueError("Version incorrect.")

        if (int(self.hdr[HDR_WIDTH]) != FRAME_WIDTH):
            raise ValueError("Width incorrect.")

        if (int(self.hdr[HDR_HEIGHT]) != FRAME_HEIGHT):
            raise ValueError("Height incorrect.")

        bpp = int(self.hdr[HDR_BPP])
        if (bpp != 2):
            raise ValueError("BPP incorrect.")

        self.frame_bytes = int(self.hdr[HDR_FRAME_BYTES])
        if (self.frame_bytes != FRAME_WIDTH*FRAME_HEIGHT*bpp):
            raise ValueError("Frame bytes incorrect.")

        self.n_slots = int(self.hdr[HDR_N_SLOTS])
        if (self.n_slots < 2):
            raise ValueError("N slots incorrect")

        self.stride = int(self.hdr[HDR_STRIDE])
        if (self.stride < self.frame_bytes + SLOT_HEADER_BYTES):
            raise ValueError("Stride incorrect")

        self.slot_meta = [None]*self.n_slots
        self.slot_px = [None]*self.n_slots
        self.last_seq = None
        self.torn = 0
        self.bad_frames = 0
        self.skipped = 0
        for i in range(self.n_slots):
            base = SLOT0_OFFSET + i * self.stride
            self.slot_meta[i] = np.frombuffer(self.mm, dtype=np.uint32, count=4, offset=base)
            self.slot_px[i] = np.frombuffer(self.mm, dtype=np.uint8, count=self.frame_bytes, offset=base + SLOT_HEADER_BYTES)
        
    def next_frame(self):
        deadline = time.monotonic() + self.timeout

        while (True):
            if (time.monotonic() > deadline):
                return None

            # get header seq
            if (self.last_seq is not None and seq == self.last_seq):
                time.sleep(0.001)

def save_frame(path, frame):
    frame.tofile(path)