from chroma_extraction import chroma_extraction
from threshold import threshold
import numpy as np
from constants import G_WIDTH, G_HEIGHT, G_N, RTL_MEM_DIR
import sys


def accumulate(mask):
    n, rows, cols = mask.shape

    output_pixel_count = np.zeros((n), dtype=np.uint32)
    output_sum_x = np.zeros((n), dtype=np.uint32)
    output_sum_y = np.zeros((n), dtype=np.uint32)

    for i, frame in enumerate(mask):
        x_coord = np.zeros((1, cols), dtype=np.uint16)
        y_coord = np.zeros((rows, 1), dtype=np.uint16)
        
        
        for j in range(0, cols):
            x_coord[0][j] = j * 2

        for k in range(0, rows):
            y_coord[k][0] = k


        output_sum_x[i] = np.sum(x_coord * mask[i])
        output_sum_y[i] = np.sum(y_coord * mask[i])
        output_pixel_count[i] = np.sum(mask[i])

    return output_pixel_count, output_sum_x, output_sum_y

def accumulate_test():
    rng = np.random.default_rng()
    mask_assert_size = rng.integers(low=1, high=100)

    rows = 240
    cols = 160
    n = 3

    mask = np.zeros((n, rows, cols), dtype=bool)

    # indices to assert
    x = np.zeros((n, mask_assert_size), dtype=np.uint64)
    y = np.zeros((n, mask_assert_size), dtype=np.uint64)

    # set a few indicies to true
    for i in range(n):
        x[i] = rng.integers(low=0, high=cols, size=mask_assert_size)
        y[i] = rng.integers(low=0, high=rows, size=mask_assert_size)
    
    expected_count = np.zeros((n), dtype=np.uint64)
    unique_coords = [set() for _ in range(n)]
    # handle uniqueness
    for i in range(n):
        for j in range(x.shape[1]):
            unique_coords[i].add((x[i][j], y[i][j])) 
        expected_count[i] = len(unique_coords[i])

    x_expected = np.zeros((n))
    y_expected = np.zeros((n))
    for i in range(n):
        for unique_coord in unique_coords[i]: 
            mask[i, unique_coord[1], unique_coord[0]] = 1
            x_expected[i] += unique_coord[0]
            y_expected[i] += unique_coord[1]


    pixel_count, sum_x, sum_y = accumulate(mask)

    assert np.array_equal(pixel_count, expected_count), "pixel count is wrong"
    assert np.array_equal(sum_x, 2*x_expected), "sum x is wrong"
    assert np.array_equal(sum_y, y_expected), "sum y is wrong"
    return

def main():
    WIDTH = 0
    HEIGHT = 0
    N = 0
    TEST_ALL_ONES = False
    TEST_ALL_ZEROS = False

    if (len(sys.argv) == 6):
        WIDTH = int(sys.argv[1])
        HEIGHT = int(sys.argv[2])
        N = int(sys.argv[3])
        TEST_ALL_ONES = int(sys.argv[4])
        TEST_ALL_ZEROS = int(sys.argv[5])
    else:
        # defaults
        WIDTH = G_WIDTH
        HEIGHT = G_HEIGHT
        N = G_N
        TEST_ALL_ONES = False
        TEST_ALL_ZEROS = False

    assert (not (TEST_ALL_ONES == 1 and TEST_ALL_ZEROS == 1))

    pixel_count_bits = ((WIDTH//2)*HEIGHT).bit_length()
    sum_x_bits = (HEIGHT*(WIDTH//2)*((WIDTH//2)-1)).bit_length()
    sum_y_bits = ((WIDTH//2)*HEIGHT*(HEIGHT-1)//2).bit_length()

    if (TEST_ALL_ONES):
        mask = np.ones((N, HEIGHT, WIDTH//2), dtype=bool)
    elif(TEST_ALL_ZEROS):
        mask = np.zeros((N, HEIGHT, WIDTH//2), dtype=bool)
    else:
        rng = np.random.default_rng()
        mask = rng.integers(low=0, high=2, size=(N, HEIGHT, WIDTH//2), dtype=bool)

    with open(RTL_MEM_DIR + "accumulate_stimulus.mem", "w") as fh:
        for word in mask.reshape(-1):
            fh.write(f"{word:01x}\n")

    pixel_count, sum_x, sum_y = accumulate(mask)

    with open(RTL_MEM_DIR + "accumulate_expected.mem", "w") as fh:
        for c, x, y in zip(pixel_count, sum_x, sum_y):
            assert (c < 2**pixel_count_bits), "pixel count write overflow"
            assert (x < 2**sum_x_bits), "sum x write overflow"
            assert (y < 2**sum_y_bits), "sum y write overflow"
            word = ((int(c) & (2**pixel_count_bits - 1)) << (sum_x_bits + sum_y_bits)) | ((int(x) & (2**sum_x_bits - 1)) << sum_y_bits) | (int(y) & (2**sum_y_bits - 1))
            fh.write(f"{word:0{(pixel_count_bits + sum_x_bits + sum_y_bits + 3) // 4}x}\n")
            

    return

if __name__ == "__main__":
    accumulate_test()
    main()
