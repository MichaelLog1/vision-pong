import matplotlib.pyplot as plt
import numpy as np

# assuming src resolution of 1280x720 (16:9)

def image_preparation(path):
    image = plt.imread(path)

    cropped = image[:, 160:1120]
    decimated = cropped[::3, ::3]

    plt.imsave("decimated.png", decimated)

    return decimated[:, :, 0], decimated[:, :, 1], decimated[:, :, 2]

if __name__ == "__main__":
    image_preparation(IMAGE_PATH)
