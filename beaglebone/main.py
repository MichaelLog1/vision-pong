from algorithm import process_frame
from config import AlgoState, AlgoConfig, PlayerTrack, Bounds, PlayerConfig, FRAME_HEIGHT, FRAME_WIDTH, U_MIN, U_MAX, V_MIN, V_MAX, Y_MIN, MIN_BLOB, ERODE_ENABLE
from capture import FileFrameSource, PruFrameSource

import numpy as np
import glob

#debug
file_source = False

def main():
    # defaults
    p1_track = PlayerTrack(np.uint32(0), np.uint32(0))
    p2_track = PlayerTrack(np.uint32(0), np.uint32(0))
    state = AlgoState(p1_track, p2_track)

    p1_bounds = Bounds(U_MIN, U_MAX, V_MIN, V_MAX, Y_MIN)
    p2_bounds = Bounds(U_MIN, U_MAX, V_MIN, V_MAX, Y_MIN)
    p1_config = PlayerConfig(p1_bounds, MIN_BLOB)
    p2_config = PlayerConfig(p2_bounds, MIN_BLOB)
    cfg = AlgoConfig(FRAME_WIDTH, FRAME_HEIGHT, ERODE_ENABLE, p1_config, p2_config)
    
    if (file_source):
        test_files = sorted(glob.glob("beaglebone/test_frames/*.bin"))
        if (len(test_files) == 0):
            raise ValueError("Test files not found.")

        frame_source = FileFrameSource(test_files, loop=False)
    else:
        frame_source = PruFrameSource()

    
    while (True):
        cf = frame_source.next_frame()
        if (cf is None):
            break
        result = process_frame(cf.frame, cfg, state)
        print(f"p1 x: {result.p1.x}, y: {result.p1.y}")
        print(f"p2 x: {result.p2.x}, y: {result.p2.y}")

    frame_source.close()

    return 

if __name__ == "__main__":
    main()