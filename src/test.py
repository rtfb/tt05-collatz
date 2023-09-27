import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test_collatz(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    tests = [
        (8, 4, 8),
        (5, 6, 16),
        (57, 33, 196),
        (578745, 129, 1953268),
        (87234789, 113, 261704368),
    ]

    for t in tests:
        input, want_orbit, want_record = t

        # reset
        dut._log.info("reset")
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await ClockCycles(dut.clk, 2)

        # set input
        await set_input(dut, input)
        await done_computing(dut)

        # read output and assert
        orbit_len, path_record = await read_output(dut)
        assert orbit_len == want_orbit
        assert path_record == want_record


async def set_input(dut, input):
    for i in range(4):
        dut.uio_in.value = i
        by = (input >> (i*8)) & 0xff;
        # dut._log.info(hex(by))
        dut.ui_in.value = by
        await ClockCycles(dut.clk, 2)


async def done_computing(dut):
    dut.uio_in.value = 0x40
    await ClockCycles(dut.clk, 2)
    dut.uio_in.value = 0x00
    while int(dut.uio_out.value) == 0x80:
        # dut._log.info("waiting...")
        await ClockCycles(dut.clk, 1)
    await ClockCycles(dut.clk, 1)


async def read_output(dut):
    orbit_len = 0

    for i in range(4):
        dut.uio_in.value = 0x80 + i
        await ClockCycles(dut.clk, 2)
        b = int(dut.uo_out.value)
        # dut._log.info(hex(b))
        orbit_len |= b << (i*8)

    path_rec = 0

    for i in range(4):
        dut.uio_in.value = 0x90 + i
        await ClockCycles(dut.clk, 2)
        b = int(dut.uo_out.value)
        # dut._log.info(hex(b))
        path_rec |= b << (i*8)

    return orbit_len, path_rec
