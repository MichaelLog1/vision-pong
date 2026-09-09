from dataclasses import dataclass
from constants import G_U_MIN, G_U_MAX, G_V_MIN, G_V_MAX, RTL_MEM_DIR, G_WIDTH, G_HEIGHT, G_N
from typing import Optional
from chroma_extraction import chroma_extraction
import numpy as np
import sys

@dataclass
class Bounds:
    U_min: int
    U_max: int
    V_min: int
    V_max: int
    Y_min: Optional[int] = None

def threshold(U0, Y0, V0, Y1, bounds: Bounds, luma_gate_en=0):
    if (luma_gate_en and bounds.Y_min is None):
        raise ValueError("bounds must include Y_min if luma gate is enabled.")

    u_in_range = (bounds.U_min <= U0) & (U0 <= bounds.U_max)
    v_in_range = (bounds.V_min <= V0) & (V0 <= bounds.V_max)

    if (luma_gate_en):
        y_in_range = (bounds.Y_min <= Y0) & (bounds.Y_min <= Y1)
        return u_in_range & v_in_range & y_in_range
    else:
        return u_in_range & v_in_range

def main():
    WIDTH = 0
    HEIGHT = 0
    N = 0
    U_min = 0
    U_max = 0
    V_min = 0
    V_max = 0
    Y_min = 0
    luma_gate_en = 0

    if(len(sys.argv) == 8):
        WIDTH = int(sys.argv[1])
        HEIGHT = int(sys.argv[2])
        N = int(sys.argv[3])
        U_min = int(sys.argv[4])
        U_max = int(sys.argv[5])
        V_min = int(sys.argv[6])
        V_max = int(sys.argv[7])
    elif(len(sys.argv) == 9):
        WIDTH = int(sys.argv[1])
        HEIGHT = int(sys.argv[2])
        N = int(sys.argv[3])
        U_min = int(sys.argv[4])
        U_max = int(sys.argv[5])
        V_min = int(sys.argv[6])
        V_max = int(sys.argv[7])
        Y_min = int(sys.argv[8])
        luma_gate_en = 1
    else:
        WIDTH = G_WIDTH
        HEIGHT = G_HEIGHT
        N = G_N
        U_min = G_U_MIN
        U_max = G_U_MAX
        V_min = G_V_MIN
        V_max = G_V_MAX

    bounds = Bounds(U_min, U_max, V_min, V_max, Y_min)
        
    # reuse chroma extraction randomization
    rng = np.random.default_rng()
    flat_buffer = rng.integers(low=0, high=256, size=(WIDTH*2*HEIGHT*N), dtype=np.uint8)
    U0, Y0, V0, Y1 = chroma_extraction(flat_buffer, WIDTH, HEIGHT, N)
    U0_flat = U0.reshape(-1)
    Y0_flat = Y0.reshape(-1)
    V0_flat = V0.reshape(-1)
    Y1_flat = Y1.reshape(-1)

    # write stimulus to a file
    with open(RTL_MEM_DIR + "threshold_stimulus.mem", "w") as fh:
        for i in range(len(U0_flat)):
            word = ((int(U0_flat[i]) & 0xFF) << 24) | ((int(Y0_flat[i]) & 0xFF) << 16) | ((int(V0_flat[i]) & 0xFF) << 8) | (int(Y1_flat[i]) & 0xFF)
            fh.write(f"{word:08x}\n")

    # write config
    with open(RTL_MEM_DIR + "threshold_config.mem", "w") as fh:
            fh.write(f"{U_min:02x}\n")
            fh.write(f"{U_max:02x}\n")
            fh.write(f"{V_min:02x}\n")
            fh.write(f"{V_max:02x}\n")
            fh.write(f"{Y_min:02x}\n")
            fh.write(f"{luma_gate_en:01x}\n")

    mask = threshold(U0, Y0, V0, Y1, bounds, luma_gate_en)
    mask_flat = mask.reshape(-1)
    with open(RTL_MEM_DIR + "threshold_expected.mem", "w") as fh:
        for i in range(len(mask_flat)):
            fh.write(f"{int(mask_flat[i]):01x}\n")

if __name__ == "__main__":
    main()