from accumulate import accumulate
import numpy as np

def divide(pixel_count, sum_x, sum_y):
    if pixel_count == 0:
        return False, 0, 0
    else:
        return (pixel_count != 0), sum_x // pixel_count, sum_y // pixel_count

if __name__ == "__main__":
    rng = np.random.default_rng()

    mask_assert_size = rng.integers(low=0, high=100)
    mask = np.zeros((240, 160), dtype=bool)
    
    # set a few indicies to true
    x = rng.integers(low=0, high=160, size=mask_assert_size)
    y = rng.integers(low=0, high=240, size=mask_assert_size)

    unique_coords = set() 
    # handle uniqueness
    for i in range(len(x)):
        unique_coords.add((x[i], y[i])) 

    x_expected = 0
    y_expected = 0
    for unique_coord in unique_coords: 
        mask[unique_coord[1]][unique_coord[0]] = 1
        x_expected += unique_coord[0] * 2
        y_expected += unique_coord[1]

    # verified already
    pixel_count, sum_x, sum_y = accumulate(mask)
    valid, x_centroid, y_centroid = divide(pixel_count, sum_x, sum_y)

    if (len(unique_coords) == 0):
        assert valid == False
        assert x_centroid == 0
        assert y_centroid == 0
    else:
        assert valid == True
        assert x_centroid == x_expected // len(unique_coords)
        assert y_centroid == y_expected // len(unique_coords)

    
