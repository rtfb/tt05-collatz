import time

from machine import Pin
from ttboard import logging


BITS = 144
BYTES = BITS >> 3
READ_PATH_RECORD_BIT = 1 << 5
VERBOSE = True


def vprint(s):
    if VERBOSE:
        print(s)


def extract_upper_bits(number, nbits):
    return number >> (BITS - nbits)


def extract_ith_byte(number, i):
    return (number >> (i*8)) & 0xff


def pulse_write_enable():
    tt.uio7(1)
    tt.clock_project_once()
    tt.uio7(0)


def set_input(val):
    for i in range(BYTES):
        data_byte = extract_ith_byte(val, i)
        tt.bidir_byte = i          # set address of i'th byte
        tt.input_byte = data_byte  # set the data byte
        tt.clock_project_once()
        pulse_write_enable()


def start_computing():
    assert tt.uio7.value() == False
    tt.uio7.mode = Pin.IN
    tt.uio7.pull = Pin.PULL_DOWN
    tt.uio6(1)
    tt.clock_project_once()
    tt.bidir_byte = 0


def done_computing():
    tt.clock_project_PWM(50e6)
    while tt.uio7.value():
        pass
    tt.clock_project_stop()
    tt.uio7.mode = Pin.OUT


def read_n_byte_num(nbytes, extra_bits=0):
    number = 0
    for i in range(nbytes):
        tt.bidir_byte = i | extra_bits
        tt.clock_project_once()
        tt.clock_project_once()
        b = tt.output_byte
        number |= b << (i*8)
    return number


def read_output():
    orbit_len = read_n_byte_num(2)
    path_rec = read_n_byte_num(2, READ_PATH_RECORD_BIT)
    return orbit_len, path_rec


def reset_project():
    tt.reset_project(True)
    for i in range(10):
        tt.clock_project_once()
    tt.bidir_mode = [Pin.OUT] * 8
    tt.bidir_byte = 0
    tt.input_byte = 0
    tt.reset_project(False)
    for i in range(10):
        tt.clock_project_once()


def soft_reset():
    tt.reset_project(True)
    tt.clock_project_once()
    tt.clock_project_once()
    tt.bidir_mode = [Pin.OUT] * 8
    tt.reset_project(False)
    tt.clock_project_once()
    tt.clock_project_once()


def run_one(val):
    vprint(f"Input: {val}")
    set_input(val)
    start_computing()
    done_computing()

    orbit_len, path_record_h16 = read_output()
    print(f"Output: orbit len = {orbit_len}, PRh16 = {path_record_h16}")


def run_one_with_measure(val):
    start = time.time_ns()
    run_one(val)
    end = time.time_ns()
    millis = (end - start) / 1e6
    print(f'Duration: {millis} ms')


def run_n(first, n):
    start = time.time_ns()
    for i in range(n):
        sr = time.time_ns()
        soft_reset()
        er = time.time_ns()
        run_one(int(first) + i)
        ec = time.time_ns()
        reset_dur = (er - sr) / 1e6
        comp_dur = (ec - er) / 1e6
        print(f'reset: {reset_dur} ms; compute: {comp_dur} ms')
    end = time.time_ns()
    millis = (end - start) / 1e6
    print(f'Duration: {millis} ms')


def measure_manual_clocking(n):
    start = time.time_ns()
    for i in range(n):
        tt.clock_project_once()
    end = time.time_ns()
    millis = (end - start) / 1e6
    print(f'{n} clock_project_once()s took {millis} ms')


# enable the design
tt.shuttle.tt_um_rtfb_collatz.enable()
reset_project()
logging.basicConfig(level=logging.WARN)

# run_one(12)
# run_one(55247846101001863167)
# run_n(1e6, 10)
