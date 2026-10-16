# Hardware build

Use `cache_board_top` as the FPGA top. It instantiates the cache demo and
ChipScope ICON/ILA/VIO. Only `clk` is a physical port. `demo_top` is the inner
subsystem used by the behavioral testbench; its observation ports must not
be mapped directly to board pins.

## Before building

Record the exact Spartan-3E part, package, speed grade, oscillator frequency,
clock pin and clock I/O standard. Generate the three vendor cores using
[these settings](chipscope.md), and supply a real board UCF based on
`constraints/board.ucf.example`.

From the repository root, use the ISE Tcl shell:

```sh
xtclsh scripts/build_ise.tcl xc3s500e-4-fg320 board.ucf ip/generated/chipscope course
```

Replace the example part with the board's device-speed-package. The last
argument can be `course` (eight transactions, the default) or `extended`
(sixteen). The script adds the nine RTL files and the three `.ngc` files,
recreates the generated project, sets `cache_board_top`, selects the mode and runs a full rebuild. It rejects
missing cores, failed/incomplete processes and a missing or empty new bitstream.
The output is `build/ise_demo/cache_board_top.bit`.

The script targets the ISE 13 lab workflow, but has only been tested locally
with stubbed vendor commands. Review the actual ISE reports before programming.
Require BlockRAM for the cache, resource fit including debug cores, no
unresolved black boxes after implementation, and timing that meets the clock
constraint. The cache RAM has an XST `ram_style="block"` attribute.

## Memory and clock

The cache, CPU sequencer, memory emulator and debug cores share `clk`. Do not
derive a separate logic clock from a button. VIO provides reset and trigger;
the demo also synchronizes both inputs.

The emulator holds 256 bytes in eight fully decoded blocks: `1100`, `3340`,
`4440`, `5500`, `6600`, `9100`, `22E0`, `77E0`. It initializes them to `FF` after
reset release. Requests outside those blocks raise a sticky fault. Confirm
that this backend is acceptable for the course, or connect the lab's required
main-memory controller and verify its fixed read timing.

Reset discards dirty cache contents and restarts memory initialization. It is
a fresh demo start, not a write-back flush. Follow [the demo procedure](demo.md)
and [the TA walkthrough](ta-demo-guide.md) for captures and measurements.
