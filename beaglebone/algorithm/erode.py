import numpy as np

def erode(mask, enable):
    if (not enable):
        return mask

    rows, cols = mask.shape
    output = np.zeros((rows, cols), dtype=bool)

    # output's interior is the and of the mask shifted to each of the nine neighbor positions
    output[1:-1, 1:-1] = mask[:-2, :-2] & mask[:-2, 1:-1] & mask[:-2, 2:] & mask[1:-1, :-2] & mask[1:-1, 1:-1] & mask[1:-1, 2:] & mask[2:, :-2] & mask[2:, 1:-1] & mask[2:, 2:]

    return output