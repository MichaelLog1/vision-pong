from algorithm.config import FrameResult, Bounds

import numpy as np
import serial

class UartLink:
    def __init__(self):
        self.port = serial.Serial("/dev/ttyS4", 115200, timeout=1)
        self.port.reset_input_buffer()
        self.rx_buffer = []

    def send(self, seq: np.uint8, result: FrameResult, latency: np.uint16):
        data = np.zeros(14, dtype=np.uint8)
        data[0] = 0xA5
        data[1] = seq & 0xFF
        data[2] = ((result.p2.valid & 0x1) << 1) | (result.p1.valid & 0x1)
        data[3] = result.p1.x & 0xFF
        data[4] = (result.p1.x >> 8) & 0xFF
        data[5] = result.p1.y & 0xFF
        data[6] = (result.p1.y >> 8) & 0xFF
        data[7] = result.p2.x & 0xFF
        data[8] = (result.p2.x >> 8) & 0xFF
        data[9] = result.p2.y & 0xFF
        data[10] = (result.p2.y >> 8) & 0xFF
        data[11] = latency & 0xFF
        data[12] = (latency >> 8) & 0xFF
        data[13] = data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7] ^ data[8] ^ data[9] ^ data[10] ^ data[11] ^ data[12]

        written = self.port.write(data.tobytes())
        if (written != 14):
            raise ValueError("Fewer that 14 bytes written")

    def poll(self):
        if (self.port.in_waiting > 0):
            self.rx_buffer.extend(self.port.read(self.port.in_waiting))

        latest_p1_bounds = None
        latest_p2_bounds = None
        while (len(self.rx_buffer) >= 14):
            if self.rx_buffer[0] != 0x5A:
                del self.rx_buffer[0]
                continue

            if (self.rx_buffer[13] != (self.rx_buffer[1] ^ self.rx_buffer[2] ^ self.rx_buffer[3] ^ self.rx_buffer[4] ^ self.rx_buffer[5] ^ self.rx_buffer[6] ^ self.rx_buffer[7] ^ self.rx_buffer[8] ^ self.rx_buffer[9] ^ self.rx_buffer[10] ^ self.rx_buffer[11] ^ self.rx_buffer[12])):
                del self.rx_buffer[0]
                continue

            latest_p1_bounds = Bounds(self.rx_buffer[3], self.rx_buffer[4], self.rx_buffer[5], self.rx_buffer[6], self.rx_buffer[7])
            latest_p2_bounds = Bounds(self.rx_buffer[8], self.rx_buffer[9], self.rx_buffer[10], self.rx_buffer[11], self.rx_buffer[12])
            del self.rx_buffer[0:14]
        
        if latest_p1_bounds is None and latest_p2_bounds is None:
            return None, None
        else:
            return latest_p1_bounds, latest_p2_bounds

    def close(self):
        self.port.close()