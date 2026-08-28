import numpy as np

def erode(mask, enable):
    if (not enable):
        return mask

    rows, cols = mask.shape
    output_mask = np.zeros((rows, cols), dtype=bool)

    for row in range(rows):
        for col in range(cols):
            if (row == 0 or row == rows-1 or col == 0 or col == cols-1):
                output_mask[row][col] = False
            else:
                if (mask[row+1][col-1] and mask[row+1][col] and mask[row+1][col+1] and mask[row][col+1] and mask[row][col-1] and mask[row-1][col-1] and mask[row-1][col] and mask[row-1][col+1]):
                    output_mask[row][col] = True
    return output_mask

if __name__ == "__main__":
    test_rows = 5
    test_cols = 5

    enable = True
    # isolated pixel test
    mask = np.zeros((test_rows, test_cols), dtype=bool)
    mask[2][2] = True
    output_mask = erode(mask, enable)
    assert np.sum(output_mask) == 0

    # solid interior block test
    mask = np.zeros((test_rows, test_cols), dtype=bool)
    mask[1][1] = True
    mask[1][2] = True
    mask[1][3] = True
    mask[2][1] = True
    mask[2][2] = True
    mask[2][3] = True
    mask[3][1] = True
    mask[3][2] = True
    mask[3][3] = True
    output_mask = erode(mask, enable)
    assert np.sum(output_mask) == 1
    assert output_mask[2][2] == 1

    # boarder pixels test
    mask = np.zeros((test_rows, test_cols), dtype=bool)
    mask[0][0] = True
    mask[0][1] = True
    mask[1][0] = True
    mask[1][1] = True
    output_mask = erode(mask, enable)
    assert np.sum(output_mask) == 0

    # test disable
    enable = False
    output_mask = erode(mask, enable)
    assert np.array_equal(output_mask, mask)