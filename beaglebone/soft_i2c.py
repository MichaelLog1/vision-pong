import mmap
import os
import subprocess
import sys
import time

GPIO1 = 0x4804C000
OE = 0x134 // 4
DATAIN = 0x138 // 4
CLEARDATAOUT = 0x190 // 4

SCL = 1 << 16 # P9.15 = GPIO1_16
SDA = 1 << 19 # P9.16 = GPIO1_19
CAM = 0x3C

for pin in ["P9_15", "P9_16"]:
    subprocess.run(["config-pin", pin, "gpio_pu"], check=True)

fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
mem = mmap.mmap(fd, 4096, offset=GPIO1)
regs = memoryview(mem).cast("I") # 32 bit register accesses

regs[CLEARDATAOUT] = SCL | SDA


def set_line(pin, level):
    if level:
        regs[OE] = regs[OE] | pin
    else:
        regs[OE] = regs[OE] & ~pin
    time.sleep(10e-6)


def read_sda():
    return 1 if regs[DATAIN] & SDA else 0


def start():
    set_line(SDA, 1)
    set_line(SCL, 1)
    set_line(SDA, 0)
    set_line(SCL, 0)


def stop():
    set_line(SDA, 0)
    set_line(SCL, 1)
    set_line(SDA, 1)


def write_byte(byte):
    for i in range(7, -1, -1):
        set_line(SDA, (byte >> i) & 1)
        set_line(SCL, 1)
        set_line(SCL, 0)
    set_line(SDA, 1) # let the camera answer
    set_line(SCL, 1)
    ack = read_sda() == 0
    set_line(SCL, 0)
    if not ack:
        stop()
        raise RuntimeError("no ACK from camera (check reset, CAMERA_DE, config-pin)")


def read_byte():
    set_line(SDA, 1)
    value = 0
    for i in range(8):
        set_line(SCL, 1)
        value = (value << 1) | read_sda()
        set_line(SCL, 0)
    set_line(SCL, 1)
    set_line(SCL, 0)
    return value


def write_reg(reg, value):
    start()
    write_byte(CAM << 1)
    write_byte(reg >> 8)
    write_byte(reg & 0xFF)
    write_byte(value)
    stop()


def read_reg(reg):
    start()
    write_byte(CAM << 1)
    write_byte(reg >> 8)
    write_byte(reg & 0xFF)
    stop()
    start()
    write_byte((CAM << 1) | 1)
    value = read_byte()
    stop()
    return value


if __name__ == "__main__":
    if len(sys.argv) > 1:
        reg = int(sys.argv[1], 16)
        print(f"reg 0x{reg:04X} = 0x{read_reg(reg):02X}")
    else:
        chip_id = (read_reg(0x300A) << 8) | read_reg(0x300B)
        print(f"chip ID 0x{chip_id:04X}")

