import numpy

FRAME_WIDTH = 320
FRAME_HEIGHT = 240

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

@dataclass
class PlayerTrack:
    last_x: np.uint16
    last_y: np.uint16

@dataclass(frozen=True)
class Bounds:
    U_min: np.uint8
    U_max: np.uint8
    V_min: np.uint8
    V_max: np.uint8
    Y_min: np.uint8
