import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test_collatz(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    tests = [
        (8, 3, 8),
        (5, 5, 16),
        (57, 32, 196),
        (578745, 128, 1953268),
        (87234789, 112, 261704368),
        (87233489, 236, 261700468),
        (517791692, 91, 622051648),
        (2201842808, 344, 2786707312),
        (803982451, 141, 3617921032),
        (3609942504, 112, 3659193952),
        (3083255988, 161, 3083255988),
        (463021824, 179, 463021824),
        (3267781108, 280, 3267781108),
        (2421305922, 96, 3631958884),
        (1971691608, 269, 1971691608),
        (3499967984, 112, 3499967984),
        (978115257, 224, 3301138996),
        (771835010, 252, 1157752516),
        (1226612421, 245, 3679837264),
        (1183962468, 188, 1183962468),
        (2105577732, 251, 2105577732),
        (175642554, 268, 263463832),
        (3965035960, 363, 3965035960),
        (1685248072, 354, 1685248072),
        (463810068, 153, 463810068),
        (350641295, 207, 3550243120),
        (425895361, 202, 1277686084),
        (553388553, 156, 2801529556),
        (1199953526, 188, 3037382368),
        (299936535, 212, 2024571616),
        (616267482, 244, 924401224),
        (1934622276, 256, 1934622276),
        (1619815328, 160, 1619815328),
        (446335366, 210, 1004254576),
        (3040231372, 205, 3702227776),
        (1732127988, 116, 1732127988),
        (847903897, 185, 2861675656),
        (3528879920, 187, 3528879920),
        (2480469920, 308, 2480469920),
        (1518424872, 204, 1518424872),
        (1278187560, 183, 1278187560),
        (219017438, 183, 2104941544),
        (778189056, 234, 778189056),
        (647255766, 288, 1456325476),
        (471175373, 166, 1413526120),
        (87013076, 117, 87013076),
        (216927658, 139, 325391488),
        (1983222946, 238, 3176739700),
        (371886186, 220, 557829280),
        (2401413698, 163, 3602120548),
        (3765123600, 226, 3765123600),
        (3207120428, 187, 3852890116),
        (122734474, 221, 184101712),
        (562919287, 187, 3799705192),
        (2222673568, 127, 2222673568),
        (276616221, 235, 829848664),
        (2105028314, 199, 3157542472),
        (1394410682, 240, 2091616024),
        (60456907, 176, 272056084),
        (126710349, 128, 380131048),
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
        byte = (input >> (i*8)) & 0xff;
        dut.uio_in.value = i
        dut.ui_in.value = byte
        await ClockCycles(dut.clk, 1)
        dut.uio_in.value |= 0x80
        await ClockCycles(dut.clk, 1)
        dut.uio_in.value &= ~0x80


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
        dut.uio_in.value = i
        await ClockCycles(dut.clk, 2)
        b = int(dut.uo_out.value)
        # dut._log.info(hex(b))
        orbit_len |= b << (i*8)

    path_rec = 0

    for i in range(4):
        dut.uio_in.value = 0x10 + i
        await ClockCycles(dut.clk, 2)
        b = int(dut.uo_out.value)
        # dut._log.info(hex(b))
        path_rec |= b << (i*8)

    return orbit_len, path_rec
