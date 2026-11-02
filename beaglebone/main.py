from algorithm.algorithm import process_frame
from config import AlgoState, AlgoConfig, PlayerTrack, Bounds, PlayerConfig, FRAME_HEIGHT, FRAME_WIDTH, U_MIN, U_MAX, V_MIN, V_MAX, Y_MIN, MIN_BLOB, ERODE_ENABLE
from capture import PruFrameSource

import numpy as np
import time

#debug
file_source = False

def main():
    last_print_time = time.monotonic()

    # defaults
    p1_track = PlayerTrack(np.uint32(0), np.uint32(0))
    p2_track = PlayerTrack(np.uint32(0), np.uint32(0))
    state = AlgoState(p1_track, p2_track)

    p1_bounds = Bounds(U_MIN, U_MAX, V_MIN, V_MAX, Y_MIN)
    p2_bounds = Bounds(U_MIN, U_MAX, V_MIN, V_MAX, Y_MIN)
    p1_config = PlayerConfig(p1_bounds, MIN_BLOB)
    p2_config = PlayerConfig(p2_bounds, MIN_BLOB)
    cfg = AlgoConfig(FRAME_WIDTH, FRAME_HEIGHT, ERODE_ENABLE, p1_config, p2_config)
    
    frame_source = PruFrameSource()

    result = None
    time_sum = 0
    frames_processed = 0
    prev_frames_processed = None
    average_frame_time = None
    
    try:
        while (True):
            if (time.monotonic() - last_print_time > 1):
                last_print_time = time.monotonic()
                stage, frame_count, frames_flagged_firmware, frames_dropped, frames_torn, frames_flagged = frame_source.status()
                print(f"Stage: {stage}")
                print(f"Frame count: {frame_count}")
                print(f"Frames dropped: {frames_dropped}")
                print(f"Frames flagged by reader: {frames_flagged}")
                print(f"Frames flagged by firmware: {frames_flagged_firmware}")
                print(f"Frames torn: {frames_torn}")

                if (average_frame_time is not None):
                    print(f"Average frame time: {average_frame_time * 1000} ms")

                if (prev_frames_processed is not None):
                    print(f"Frames per second: {frames_processed - prev_frames_processed}")

                if (result is not None):
                    print(f"p1 x: {result.p1.x}, y: {result.p1.y}, count: {result.p1.count}, valid: {result.p1.valid}")
                    print(f"p2 x: {result.p2.x}, y: {result.p2.y}, count: {result.p2.count}, valid: {result.p2.valid}")

                prev_frames_processed = frames_processed

            cf = frame_source.next_frame()
            if (cf is None):
                print("No frame")
                continue
            start = time.perf_counter()
            result = process_frame(cf.frame, cfg, state)
            end = time.perf_counter()

            time_sum = time_sum + (end - start)
            frames_processed = frames_processed + 1
            average_frame_time = time_sum / frames_processed




    except KeyboardInterrupt: pass
    finally: frame_source.close()
    return 

if __name__ == "__main__":
    main()