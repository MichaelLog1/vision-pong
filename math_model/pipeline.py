from chroma_extraction import chroma_extraction
from threshold import threshold, Bounds
from erode import erode
from accumulate import accumulate
from divide import divide
from constants import WIDTH, HEIGHT, RED_CUP_IMAGE
import numpy as np
from dataclasses import dataclass
from image_generation import Rectangle, build_scene, UYVY_packer, rgb_to_yuv
from image_preparation import image_preparation
import matplotlib.pyplot as plt

@dataclass
class Outputs:
    cx: int
    cy: int
    pixel_count: int
    valid: bool


def pipeline(UYVY_buffer, p1_bounds: Bounds, p2_bounds: Bounds, erode_enable: bool):
    # chroma extraction on image
    U0, Y0, V0, Y1 = chroma_extraction(UYVY_buffer, WIDTH, HEIGHT)

    # create masks based on player bounds
    p1_mask = threshold(U0, V0, p1_bounds)
    p2_mask = threshold(U0, V0, p2_bounds)

    # clean up the masks
    p1_eroded = erode(p1_mask, erode_enable)
    p2_eroded = erode(p2_mask, erode_enable)

    # accumulate indices
    p1_pixel_count, p1_sx, p1_sy = accumulate(p1_eroded)
    p2_pixel_count, p2_sx, p2_sy = accumulate(p2_eroded)

    p1_valid, p1_cx, p1_cy = divide(p1_pixel_count, p1_sx, p1_sy)
    p2_valid, p2_cx, p2_cy = divide(p2_pixel_count, p2_sx, p2_sy)

    p1_outputs = Outputs(p1_cx, p1_cy, p1_pixel_count, p1_valid)
    p2_outputs = Outputs(p2_cx, p2_cy, p2_pixel_count, p2_valid)

    return p1_outputs, p2_outputs

if __name__ == "__main__":
    # player 1
    p1_U_min = 95
    p1_U_max = 120
    p1_V_min = 180
    p1_V_max = 210
    p1_bounds = Bounds(p1_U_min, p1_U_max, p1_V_min, p1_V_max)

    # player 2
    p2_U_min = 150
    p2_U_max = 190
    p2_V_min = 80
    p2_V_max = 120
    p2_bounds = Bounds(p2_U_min, p2_U_max, p2_V_min, p2_V_max)

    # generate a test image
    # shape 1: red rectangle
    # s1 = Rectangle(10, 10, 20, 40, (255, 0, 0))

    # # shape 2: blue rectangle
    # s2 = Rectangle(100, 100, 30, 10, (0, 0, 255))

    # # white for now
    # background_color = (255, 255, 255)

    # Y, U, V = build_scene(WIDTH, HEIGHT, background_color, [s1, s2])

    image = image_preparation(RED_CUP_IMAGE)

    Y, U, V = rgb_to_yuv(image)

    flat_buffer = UYVY_packer(WIDTH, HEIGHT, Y, U, V)
    p1_out, p2_out = pipeline(flat_buffer, p1_bounds, p2_bounds, erode_enable=True)

    plt.imshow(Y, cmap='gray', vmin=0, vmax=255)
    plt.scatter(p1_out.cx, p1_out.cy)
    plt.scatter(p2_out.cx, p2_out.cy)
    plt.savefig("test.png")
