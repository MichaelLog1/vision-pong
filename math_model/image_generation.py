from dataclasses import dataclass
from constants import WIDTH, HEIGHT
import numpy as np
from typing import Optional
import matplotlib.pyplot as plt

@dataclass
class Rectangle:
    x: int
    y: int
    w: int
    h: int
    rgb: tuple
    yuv: Optional[tuple] = None

def rgb_to_yuv(rgb: tuple):
    # stole this
    Y = 0.299*rgb[0] + 0.587*rgb[1] + 0.114*rgb[2]
    U = -0.168736*rgb[0] - 0.331264*rgb[1] + 0.5*rgb[2] + 128
    V = 0.5*rgb[0] - 0.418688*rgb[1] - 0.081312*rgb[2] + 128

    # clip
    Y = np.clip(Y, 0, 255)
    U = np.clip(U, 0, 255)
    V = np.clip(V, 0, 255)

    # round
    Y = np.round(Y)
    U = np.round(U)
    V = np.round(V)

    # cast
    return (np.uint8(Y), np.uint8(U), np.uint8(V))

def build_scene(width, height, background_color: tuple, shapes):
    # validate shapes
    for shape in shapes:
        if (shape.x + shape.w > width or shape.y + shape.h > height or shape.x < 0 or shape.y < 0):
            raise ValueError("Shape out of bounds.")

    yuv_bg = rgb_to_yuv(background_color)

    # convert shape colors to YUV
    for shape in shapes:
        shape.yuv = rgb_to_yuv(shape.rgb)

    # fill in background
    Y_full = np.full((height, width), yuv_bg[0], dtype=np.uint8)
    U_full = np.full((height, width), yuv_bg[1], dtype=np.uint8)
    V_full = np.full((height, width), yuv_bg[2], dtype=np.uint8)

    # draw shapes
    for shape in shapes:
        Y_full[shape.y:shape.y+shape.h, shape.x:shape.x+shape.w] = shape.yuv[0]
        U_full[shape.y:shape.y+shape.h, shape.x:shape.x+shape.w] = shape.yuv[1]
        V_full[shape.y:shape.y+shape.h, shape.x:shape.x+shape.w] = shape.yuv[2]


    return Y_full, U_full, V_full

def UYVY_packer(width, height, Y, U, V):
    U0 = np.zeros(width*height*2 // 4, dtype=np.uint8)
    V0 = np.zeros(width*height*2 // 4, dtype=np.uint8)
    Y0 = np.zeros(width*height*2 // 4, dtype=np.uint8)
    Y1 = np.zeros(width*height*2 // 4, dtype=np.uint8)

    # build U0 and V0
    for i in range(len(U0)):
        row = i // (width // 2)
        col = i % (width // 2)
        U0[i] = np.uint8((np.uint16(U[row, 2*col]) + np.uint16(U[row, 2*col+1])) // 2)
        V0[i] = np.uint8((np.uint16(V[row, 2*col]) + np.uint16(V[row, 2*col+1])) // 2)

    # build Y0 and Y1
    for i in range(len(Y0)):
        row = i // (width // 2)
        col = i % (width // 2)
        Y0[i] = Y[row, 2*col]
        Y1[i] = Y[row, 2*col+1]

    packed = np.zeros(width*height*2, dtype=np.uint8)
    for i in range(len(U0)):
        packed[4*i + 0] = U0[i]
        packed[4*i + 1] = Y0[i]
        packed[4*i + 2] = V0[i]
        packed[4*i + 3] = Y1[i]

    return packed

if __name__ == "__main__":

    # shape 1: red rectangle
    s1 = Rectangle(10, 10, 20, 40, (255, 0, 0))

    # shape 2: blue rectangle
    s2 = Rectangle(100, 100, 30, 10, (0, 0, 255))

    # white for now
    background_color = (255, 255, 255)

    Y, U, V = build_scene(WIDTH, HEIGHT, background_color, [s1, s2])

    plt.imsave("test.png", Y, cmap='gray', vmin=0, vmax=255)
