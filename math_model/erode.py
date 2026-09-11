import numpy as np
from constants import G_WIDTH, G_HEIGHT, G_N, RTL_MEM_DIR
import sys

def erode(mask, enable):
    if (not enable):
        return mask

    N, rows, cols = mask.shape
    output = np.zeros((N, rows, cols), dtype=bool)
    for i, frame in enumerate(mask):
        output_mask = np.zeros((rows, cols), dtype=bool)

        for row in range(rows):
            for col in range(cols):
                if (row == 0 or row == rows-1 or col == 0 or col == cols-1):
                    output_mask[row][col] = False
                else:
                    if (frame[row+1][col-1] and frame[row+1][col] and frame[row+1][col+1] and frame[row][col+1] and frame[row][col-1] and frame[row-1][col-1] and frame[row-1][col] and frame[row-1][col+1] and frame[row][col]):
                        output_mask[row][col] = True
        output[i] = output_mask
    return output

def test_erode():
    test_rows = 5
    test_cols = 5
    test_n = 3

    enable = True
    # isolated pixel test
    mask = np.zeros((test_n, test_rows, test_cols), dtype=bool)
    mask[:, 2, 2] = True
    output_mask = erode(mask, enable)
    assert np.sum(output_mask) == 0

    # solid interior block test
    mask = np.zeros((test_n, test_rows, test_cols), dtype=bool)
    mask[:, 1, 1] = True
    mask[:, 1, 2] = True
    mask[:, 1, 3] = True
    mask[:, 2, 1] = True
    mask[:, 2, 2] = True
    mask[:, 2, 3] = True
    mask[:, 3, 1] = True
    mask[:, 3, 2] = True
    mask[:, 3, 3] = True
    output_mask = erode(mask, enable)
    assert np.sum(output_mask) == 3
    assert output_mask[:, 2, 2].all() == 1

    # boarder pixels test
    mask = np.zeros((test_n, test_rows, test_cols), dtype=bool)
    mask[:, 0, 0] = True
    mask[:, 0, 1] = True
    mask[:, 1, 0] = True
    mask[:, 1, 1] = True
    output_mask = erode(mask, enable)
    assert np.sum(output_mask) == 0

    # test disable
    enable = False
    output_mask = erode(mask, enable)
    assert np.array_equal(output_mask, mask)
    return

def main():
    WIDTH = 0
    HEIGHT = 0
    N = 0
    ERODE_ENABLE = True

    if (len(sys.argv) == 5):
        WIDTH = int(sys.argv[1])
        HEIGHT = int(sys.argv[2])
        N = int(sys.argv[3])
        ERODE_ENABLE = int(sys.argv[4])
    else:
        # defaults
        WIDTH = G_WIDTH
        HEIGHT = G_HEIGHT
        N = G_N
        ERODE_ENABLE = True

    with open(RTL_MEM_DIR + "erode_config.mem", "w") as fh:
        fh.write(f"{ERODE_ENABLE:01x}\n")

    rng = np.random.default_rng()
    mask = rng.integers(low=0, high=2, size=(N, HEIGHT, WIDTH//2), dtype=bool)

    with open(RTL_MEM_DIR + "erode_stimulus.mem", "w") as fh:
        for word in mask.reshape(-1):
            fh.write(f"{word:01x}\n")
    
    mask = erode(mask, ERODE_ENABLE)

    with open(RTL_MEM_DIR + "erode_expected.mem", "w") as fh:
        for word in mask.reshape(-1):
            fh.write(f"{word:01x}\n")

    return
    
if __name__ == "__main__":
    test_erode()
    main()
    