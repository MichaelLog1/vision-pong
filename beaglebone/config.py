from dataclasses import dataclass
import numpy as np

FRAME_WIDTH = 320
FRAME_HEIGHT = 240
CHROMA_WIDTH = FRAME_WIDTH // 2
FRAME_BYTES = FRAME_WIDTH * FRAME_HEIGHT * 2

# PRU firmware constants
RING_PHYS = 0x9FE00000

# UPDATED firmware constants
RING_PHYS = 0x9FE00000
PRU_SHARED_PHYS = 0x4A310000
RING_MAGIC = 0
RING_MAGIC_VALUE = 0x31435056
RING_SLOT0_OFFSET = 0x1000
RING_SLOT0_PHYS = RING_PHYS + RING_SLOT0_OFFSET
RING_SLOT_HEADER_BYTES = 0x40
RING_SLOT_STRIDE = FRAME_BYTES + RING_SLOT_HEADER_BYTES
RING_SLOT_HEADER_FLAGS = 3

# temp constants
U_MIN = 95
U_MAX = 120
V_MIN = 180
V_MAX = 210
Y_MIN = 32
ERODE_ENABLE = True
MIN_BLOB = 64

# common classes
@dataclass
class PlayerResult:
    x: np.uint16
    y: np.uint16
    count: np.uint32
    valid: bool

@dataclass
class FrameResult:
    p1: PlayerResult
    p2: PlayerResult

@dataclass(frozen=True)
class Bounds:
    U_min: np.uint8
    U_max: np.uint8
    V_min: np.uint8
    V_max: np.uint8
    Y_min: np.uint8

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
class PlayerTrack:
    last_x: np.uint16
    last_y: np.uint16

@dataclass
class AlgoState:
    p1: PlayerTrack
    p2: PlayerTrack
