import numpy as np

def chroma_extraction(buffer, WIDTH, HEIGHT):
    assert len(buffer) == WIDTH*HEIGHT*2, f"[CHROMA EXTRACTION] : input size must be 153600"

    U0 = buffer[0::4].reshape(HEIGHT, WIDTH//2)
    Y0 = buffer[1::4].reshape(HEIGHT, WIDTH//2)
    V0 = buffer[2::4].reshape(HEIGHT, WIDTH//2)
    Y1 = buffer[3::4].reshape(HEIGHT, WIDTH//2)
    return U0, Y0, V0, Y1

if __name__ == "__main__":
    WIDTH = 320
    HEIGHT = 240
    flat_buffer = np.zeros((153600), dtype=np.uint8)
    chroma_extraction(flat_buffer, WIDTH, HEIGHT)
