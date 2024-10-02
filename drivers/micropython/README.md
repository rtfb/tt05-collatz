ASIC Drivers
============

This directory contains MicroPython scripts that will exercise the design using
the RP2040 microcontroller present on the Tiny Tapeout DemoBoard. The scripts
were tested with the DemoBoard [firmware][2] [v1.2.0][3].

The easiest way to run the scripts is directly through REPL.
Plug in the board to your laptop and connect to the RP microcontroller via
[Commander App](https://commander.tinytapeout.com/) (or any serial terminal
emulator, like picocom: `picocom /dev/ttyACM10`).

## NOTE!
The scripts are known to not work correctly immediately after the board is
connected. To get them to work, you have to "soft reboot" the demoboard, i.e.
after you connect the board and get to REPL, hit Ctrl-D once to trigger the
"soft reboot", then you can run the scripts.

After the soft reboot, copy script text to clipboard, then in REPL hit Ctrl-E,
Ctrl-Shift-V, Ctrl-D to get the script evaluated and executed.

# `run-manual-clock.py`

This script exercises the ASIC mostly using the SDK function
`clock_project_once()`. This gives a fine-grained control over the ASIC, but
manual clocking is very slow and thus, IO time can dominate the compute time.
The computations themselves are allowed to run at the highest frequency
(~42MHz).

The entry point functions are `run_one(n)` and `run_n(from, n)`.

`run_one` calculates the Collatz orbit for a single provided number. It prints
the calculated orbit length and the upper 16 bits of the path record. It is
necessary to call `soft_reset()` in between the calls to `run_one()`.

`run_n` calculates provided n orbits starting with a provided number, e.g.
`run_n(1000, 3)` will calculate orbits for the numbers 1000, 1001 and 1002. In
addition to the result output, `run_n` prints the duration of each execution.

# `run-continuous-clock.py`

This script exercises the ASIC letting the clock run continuously. Even though
the chip is only allowed to run at 500kHz, this yields better results because it
can avoid using the slow `clock_project_once()` function during IO.

---

The scripts are based on the original test [script][1] written by @MichaelBell.

[1]: https://github.com/MichaelBell/tt-micropython-scripts/blob/main/collatz.py
[2]: https://github.com/TinyTapeout/tt-micropython-firmware
[3]: https://github.com/TinyTapeout/tt-micropython-firmware/releases/tag/v1.2.0
