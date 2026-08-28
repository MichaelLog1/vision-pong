from chroma_extraction import chroma_extraction
from threshold import threshold
import numpy as np


def accumulate(mask):
    rows, cols = mask.shape
    x_coord = np.zeros((1, cols))
    y_coord = np.zeros((rows, 1))
    
    
    for i in range(0, cols):
        x_coord[0][i] = i * 2

    for i in range(0, rows):
        y_coord[i][0] = i


    sum_x = np.sum(x_coord * mask)
    sum_y = np.sum(y_coord * mask)
    pixel_count = np.sum(mask)
    return pixel_count, sum_x, sum_y

if __name__ == "__main__":
    rng = np.random.default_rng()
    mask_assert_size = rng.integers(low=0, high=100)

    rows = 240
    cols = 160

    mask = np.zeros((240, 160), dtype=bool)

    # set a few indicies to true
    x = rng.integers(low=0, high=cols, size=mask_assert_size)
    y = rng.integers(low=0, high=rows, size=mask_assert_size)

    unique_coords = set() 
    # handle uniqueness
    for i in range(len(x)):
        unique_coords.add((x[i], y[i])) 

    x_expected = 0
    y_expected = 0
    for unique_coord in unique_coords: 
        mask[unique_coord[1]][unique_coord[0]] = 1
        x_expected += unique_coord[0]
        y_expected += unique_coord[1]


    pixel_count, sum_x, sum_y = accumulate(mask)

    assert pixel_count == len(unique_coords), "pixel count is wrong"
    assert sum_x == 2*x_expected, "sum x is wrong"
    assert sum_y == y_expected, "sum y is wrong"
