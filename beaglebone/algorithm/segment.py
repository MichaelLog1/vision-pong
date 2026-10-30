from config import Bounds

def segment(U0, Y0, V0, Y1, bounds: Bounds):
    u_in_range = (U0 >= bounds.U_min) & (U0 <= bounds.U_max)
    v_in_range = (V0 >= bounds.V_min) & (V0 <= bounds.V_max)
    y_in_range = (Y0 >= bounds.Y_min) & (Y1 >= bounds.Y_min)
    return u_in_range & v_in_range & y_in_range
