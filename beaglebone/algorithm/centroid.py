from config import PlayerTrack, PlayerResult

import numpy as np

def centroid(mask, state: PlayerTrack, min_blob):
    rows, cols = mask.shape
    x_coord = np.zeros((1, cols), dtype=np.uint16)
    y_coord = np.zeros((rows, 1), dtype=np.uint16)
        
    for i in range(0, cols):
        x_coord[0][i] = i * 2

    for i in range(0, rows):
        y_coord[i][0] = i

    pixel_count = np.sum(mask).astype(np.uint32)
    valid = pixel_count >= min_blob and pixel_count != 0

    if (valid):
        state.last_x = np.sum(x_coord * mask).astype(np.uint32) // pixel_count
        state.last_y = np.sum(y_coord * mask).astype(np.uint32) // pixel_count

    return PlayerResult(state.last_x, state.last_y, pixel_count, bool(valid))