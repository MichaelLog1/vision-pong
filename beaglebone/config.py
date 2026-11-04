from algorithm.config import Bounds, PlayerTrack

from dataclasses import dataclass
import numpy as np

FRAME_WIDTH = 320
FRAME_HEIGHT = 240
CHROMA_WIDTH = FRAME_WIDTH // 2
FRAME_BYTES = FRAME_WIDTH * FRAME_HEIGHT * 2


# PRU firmware constants
RING_PHYS = 0x9FE00000
PRU_SHARED_PHYS = 0x4A310000
RING_SLOT0_OFFSET = 0x1000
RING_SLOT0_PHYS = RING_PHYS + RING_SLOT0_OFFSET
RING_SLOT_HEADER_BYTES = 0x40

RING_MAGIC_INDEX = 0
RING_WIDTH_INDEX = 2
RING_HEIGHT_INDEX = 3
RING_BPP_INDEX = 4
RING_BPF_INDEX = 5
RING_NUM_SLOTS_INDEX = 6
RING_STRIDE_INDEX = 7
RING_HEAD_INDEX = 8
RING_SEQ_INDEX = 9
RING_T_VSYNC_OFFSET = 1
RING_T_DONE_OFFSET = 2
RING_FLAGS_OFFSET = 3

RING_MAGIC_VALUE = 0x31435056
RING_BPP_VALUE = 2
RING_NUM_SLOTS_VALUE = 4
RING_SLOT_STRIDE_VALUE = FRAME_BYTES + RING_SLOT_HEADER_BYTES

# temp constants
U_MIN = 30
U_MAX = 100
V_MIN = 135
V_MAX = 170
Y_MIN = 32
ERODE_ENABLE = True
MIN_BLOB = 64

@dataclass(frozen=True)
class PlayerConfig:
    bounds: Bounds
    min_blob: np.uint16

@dataclass(frozen=True)
class AlgoConfig:
    width: np.uint16
    height: np.uint16
    erode_enable: bool
    p1: PlayerConfig
    p2: PlayerConfig

@dataclass
class AlgoState:
    p1: PlayerTrack
    p2: PlayerTrack
