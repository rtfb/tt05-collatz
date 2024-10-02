import time

from machine import Pin
from ttboard import logging


BITS = 144
BYTES = BITS >> 3
READ_PATH_RECORD_BIT = 1 << 5
DESIGN_FREQ = 5e5
ONE_ASIC_CLOCK_DUR_MICROS = 4 * int(1e6 / DESIGN_FREQ)
VERBOSE = True


def vprint(s):
    if VERBOSE:
        print(s)


def extract_upper_bits(number, nbits):
    return number >> (BITS - nbits)


def extract_ith_byte(number, i):
    return (number >> (i*8)) & 0xff


def sleep_rp_for_n_asic_clocks(n):
    time.sleep_us(n * ONE_ASIC_CLOCK_DUR_MICROS)


def pulse_write_enable():
    tt.uio7(1)
    sleep_rp_for_n_asic_clocks(1)
    tt.uio7(0)
    sleep_rp_for_n_asic_clocks(1)


def pulse_start_computing():
    tt.uio6(1)
    sleep_rp_for_n_asic_clocks(1)
    tt.uio6(0)
    sleep_rp_for_n_asic_clocks(1)


def set_input(val):
    for i in range(BYTES):
        data_byte = extract_ith_byte(val, i)
        tt.bidir_byte = i          # set address of i'th byte
        tt.input_byte = data_byte  # set the data byte
        sleep_rp_for_n_asic_clocks(1)
        pulse_write_enable()


def start_computing():
    assert tt.uio7.value() == False
    tt.uio7.mode = Pin.IN
    tt.uio7.pull = Pin.PULL_DOWN
    tt.bidir_byte = 0
    pulse_start_computing()


def done_computing():
    count = 0
    while tt.uio7.value():
        count += 1
    vprint(f'count = {count}')
    tt.uio7.mode = Pin.OUT
    sleep_rp_for_n_asic_clocks(1)


def read_n_byte_num(nbytes, extra_bits=0):
    number = 0
    for i in range(nbytes):
        tt.bidir_byte = i | extra_bits
        sleep_rp_for_n_asic_clocks(2)
        b = tt.output_byte
        number |= b << (i*8)
    return number


def read_output():
    orbit_len = read_n_byte_num(2)
    path_rec = read_n_byte_num(2, READ_PATH_RECORD_BIT)
    return orbit_len, path_rec


def reset_project():
    tt.clock_project_PWM(DESIGN_FREQ)
    tt.reset_project(True)
    time.sleep_ms(500)
    tt.bidir_mode = [Pin.OUT] * 8
    tt.bidir_byte = 0
    tt.input_byte = 0
    tt.reset_project(False)
    time.sleep_ms(500)


def soft_reset():
    tt.reset_project(True)
    sleep_rp_for_n_asic_clocks(10)
    tt.bidir_mode = [Pin.OUT] * 8
    tt.bidir_byte = 0
    tt.reset_project(False)
    sleep_rp_for_n_asic_clocks(10)


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


# enable the design
tt.shuttle.tt_um_rtfb_collatz.enable()
reset_project()
logging.basicConfig(level=logging.WARN)

# run_one(12)
# run_one(55247846101001863167)
# run_n(1e6, 10)
