import numpy as np

def erode(mask, enable):
    if (not enable):
        return mask

    rows, cols = mask.shape
    output = np.zeros((rows, cols), dtype=bool)
    for row in range(rows):
        for col in range(cols):
            if (row == 0 or row == rows-1 or col == 0 or col == cols-1):
                output[row][col] = False
            elif (mask[row+1][col-1] and mask[row+1][col] and mask[row+1][col+1] and mask[row][col+1] and mask[row][col-1] and mask[row-1][col-1] and mask[row-1][col] and mask[row-1][col+1] and mask[row][col]):
                output[row][col] = True
    return output