import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test_collatz(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # reset
    dut._log.info("reset")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    bytes = [0x34, 0x12, 0xcd, 0xab]  # 0xabcd1234

    for i in range(4):
        dut.uio_in.value = i
        dut.ui_in = bytes[i]
        await ClockCycles(dut.clk, 10)

    dut.uio_in.value = 0x80
    await ClockCycles(dut.clk, 10)
    assert int(dut.uo_out.value) == 13

    await ClockCycles(dut.clk, 10)
    path_rec = 0

    for i in range(4):
        dut.uio_in.value = 0x90 + i
        await ClockCycles(dut.clk, 10)
        b = int(dut.uo_out.value)
        dut._log.info(hex(b))
        path_rec |= b << (i*8)

    assert path_rec == 0xdeadbeef
