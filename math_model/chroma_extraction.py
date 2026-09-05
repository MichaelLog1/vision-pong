import numpy as np
import sys
from constants import G_WIDTH, G_HEIGHT, G_N, RTL_MEM_DIR

def UYVY_packer(width, height, U0, Y0, V0, Y1, N=1):
    U0_flat = U0.reshape(-1)
    V0_flat = V0.reshape(-1)
    Y0_flat = Y0.reshape(-1)
    Y1_flat = Y1.reshape(-1)   

    packed = np.zeros(width*height*2*N, dtype=np.uint8)
    packed[0::4] = U0_flat
    packed[1::4] = Y0_flat
    packed[2::4] = V0_flat
    packed[3::4] = Y1_flat
    return packed

def chroma_extraction(buffer, WIDTH, HEIGHT, N=1):
    assert len(buffer) == WIDTH*2*HEIGHT*N

    U0 = buffer[0::4].reshape(N, HEIGHT, WIDTH//2)
    Y0 = buffer[1::4].reshape(N, HEIGHT, WIDTH//2)
    V0 = buffer[2::4].reshape(N, HEIGHT, WIDTH//2)
    Y1 = buffer[3::4].reshape(N, HEIGHT, WIDTH//2)
    return U0, Y0, V0, Y1

# golden model
def main():
    WIDTH = 0
    HEIGHT = 0
    N = 0

    if (len(sys.argv) == 4):
        WIDTH = int(sys.argv[1])
        HEIGHT = int(sys.argv[2])
        N = int(sys.argv[3])
    else:
        # defaults
        WIDTH = G_WIDTH
        HEIGHT = G_HEIGHT
        N = G_N

    rng = np.random.default_rng()
    flat_buffer = rng.integers(low=0, high=256, size=(WIDTH*2*HEIGHT*N), dtype=np.uint8)
    
    # write stimulus to a file
    with open(RTL_MEM_DIR + "chroma_extraction_stimulus.mem", "w") as fh:
        for byte in flat_buffer:
            fh.write(f"{byte:02x}\n")


    U0, Y0, V0, Y1 = chroma_extraction(flat_buffer, WIDTH, HEIGHT, N)

    # assert for correctness
    assert np.array_equal(UYVY_packer(WIDTH, HEIGHT, U0, Y0, V0, Y1, N), flat_buffer)


if __name__ == "__main__":
    main()
