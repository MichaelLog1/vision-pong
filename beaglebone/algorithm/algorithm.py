from chroma import chroma_extraction
from segment import segment
from erode import erode
from centroid import centroid
from config import FrameResult

def process_frame(frame, cfg, state):
    U0, Y0, V0, Y1 = chroma_extraction(frame, cfg.width, cfg.height)
    
    p1_mask = segment(U0, Y0, V0, Y1, cfg.p1.bounds)
    p2_mask = segment(U0, Y0, V0, Y1, cfg.p2.bounds)

    p1_erode = erode(p1_mask, cfg.erode_enable)
    p2_erode = erode(p2_mask, cfg.erode_enable)

    p1_result = centroid(p1_erode, state.p1, cfg.p1.min_blob)
    p2_result = centroid(p2_erode, state.p2, cfg.p2.min_blob)
    return FrameResult(p1_result, p2_result)

