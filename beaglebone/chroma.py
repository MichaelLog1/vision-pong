from config import FRAME_HEIGHT, FRAME_WIDTH

import numpy as np

def chroma_extraction(frame, width, height):
    U0 = frame[0::4].reshape(height, width//2)
    Y0 = frame[1::4].reshape(height, width//2)
    V0 = frame[2::4].reshape(height, width//2)
    Y1 = frame[3::4].reshape(height, width//2)
    return U0, Y0, V0, Y1
