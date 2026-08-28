from dataclasses import dataclass

@dataclass
class Bounds:
    U_min: int
    U_max: int
    V_min: int
    V_max: int

def threshold(U, V, bounds: Bounds):
    mask = (bounds.U_min <= U) & (U <= bounds.U_max) & (bounds.V_min <= V) & (V <= bounds.V_max)
    return mask 

if __name__ == "__main__":
    threshold()