from dataclasses import dataclass
import numpy as np

FRAME_WIDTH = 320
FRAME_HEIGHT = 240
CHROMA_WIDTH = FRAME_WIDTH // 2

# PRU firmware constants
RING_PHYS = 0x9FE00000
RING_SIZE = 0x200000
SLOT0_OFFSET = 0x1000
SLOT_HEADER_BYTES = 0x40
RING_MAGIC = b"VPC1"
RING_VERSION = 1
# header word indices
HDR_VERSION = 1
HDR_WIDTH = 2
HDR_HEIGHT = 3
HDR_BPP = 4
HDR_FRAME_BYTES = 5
HDR_N_SLOTS = 6
HDR_STRIDE = 7
HDR_HEAD = 8
HDR_SEQ = 9
HDR_DROPPED = 10
# slot word indices
SLOT_SEQ = 0
SLOT_T_VSYNC = 1
SLOT_T_DONE = 2
SLOT_FLAGS = 3
FLAG_SHORT_FRAME = 0x1
PRU_SHARED_PHYS = 0x4A310000 # 0x4A300000 + PRU offset
PRU1_CTRL_PHYS = 0x4A324000
PROBE_MAGIC = 0
PROBE_HEARTBEAT = 1
PROBE_R31 = 2
PRU_CTRL_CYCLE = 3
PROBE_FRAME_PERIOD = 4
PROBE_VSYNC_WIDTH = 5
PROBE_LINE_COUNT = 6
PROBE_HREF_HIGH_TOTAL = 7
PROBE_MAGIC_VALUE = 0x50524230

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
