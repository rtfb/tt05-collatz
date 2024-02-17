![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# Collatz conjecture brute-forcer


A hardware implementation of a brute-force checker for [Collatz conjecture][1].
It takes an integer number as an input and computes the Collatz sequence until
it reaches 1. When it does, it allows reading back two numbers:
1) The orbit length (i.e. the number of steps it took to reach 1)
2) The highest recorded value of the upper 16 bits of the 144-bit internal iterator

The latter number is an indicator for good candidates for computing [path
records][2]. The non-zero upper bits indicate that the highest iterator value
`Mx(N)` is in the range of the previous path records and should be recomputed in
the full offline. (Holding on to the entire 144 bits of `Mx(N)` number would be
more obvious, but this almost doubles the footprint of the design, hence, this
optimisation).

## Using the chip

The module can be in 2 states: IO and COMPUTE. After reset, the chip will be in
IO mode. Since the input is intended to be much larger than the available pins,
the input number is uploaded one byte at a time, increasing the address of where
in the internal 144-bit-wide register that byte should be stored.

Same for reading the output, except that the output numbers are limited to
16-bits each, so it takes much fewer operations to read them.

### I/O pins should be used as follows:

`ui_in`: an input byte when uploading an input number.

`uo_out`: an output byte when downloading one of the results.

Bidirectional pins are mode-dependant.

When in COMPUTE mode, `uio_out[7]` indicates whether the compute module is busy.
When it becomes 0, the module will switch to the I/O mode, allowing to read
output and set a new input. All other bits are meaningless in this mode.

When in IO mode, the pins act as follows:
| PIN           | Description                                                |
| ------------- | ---------------------------------------------------------- |
| `uio_in[7]`   | pulse a 1 to write `ui_in` to the address in `uio_in[4:0]` |
| `uio_in[6]`   | pulse a 1 to switch to COMPUTE mode                        |
| `uio_in[5]`   | set to 0 to read orbit length, set to 1 to read the `Mx(N)` upper bits |
| `uio_in[4:0]` | set to the address to write to or read from                |

See [`set_input()`][3], [`done_computing()`][4] and [`read_n_byte_num()`][5]
test functions for an example of using this I/O protocol.

## What is Tiny Tapeout?

TinyTapeout is an educational project that aims to make it easier and cheaper
than ever to get your digital designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

### Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://discord.gg/rPK2nSjxy8)

### What next?

- Submit your design to the next shuttle [on the website](https://tinytapeout.com/#submit-your-design). The closing date is **November 4th**.
- Edit this [README](README.md) and explain your design, how it works, and how to test it.
- Share your GDS on your social network of choice, tagging it #tinytapeout and linking Matt's profile:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [matt-venn](https://www.linkedin.com/in/matt-venn/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - Twitter [#tinytapeout](https://twitter.com/hashtag/tinytapeout?src=hashtag_click) [@matthewvenn](https://twitter.com/matthewvenn)

[1]: https://en.wikipedia.org/wiki/Collatz_conjecture
[2]: http://www.ericr.nl/wondrous/pathrecs.html
[3]: https://github.com/rtfb/tt05-collatz/blob/main/src/test.py#L191
[4]: https://github.com/rtfb/tt05-collatz/blob/main/src/test.py#L206
[5]: https://github.com/rtfb/tt05-collatz/blob/main/src/test.py#L212
