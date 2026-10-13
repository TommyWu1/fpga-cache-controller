# Demo harness and ISE build

`demo_top` connects the cache to an authored course-vector sequencer, a bounded
main-memory emulator, and a transaction monitor. Its inputs are the shared
clock, active-high reset, and a manual trigger. The trigger is accepted only
after the memory initializer is done, the cache is ready, and the sequencer is
idle. Keep `trig` high if convenient: one rising edge starts one sequence, and
RDY returning high during that sequence cannot retrigger it.

The harness memory contains 256 bytes in these eight full-address blocks:
`1100`, `3340`, `4440`, `5500`, `6600`, `9100`, `22E0`, and `77E0`. It initializes
to `FF` before accepting memory operations. Other addresses set a sticky
unsupported-address fault. This is a small demonstration model, not a 64 KiB
main memory or a physical SDRAM controller. The cache RAM uses the same inferred
`rtl/cache_ram.vhd` source for simulation and ISE; inspect the ISE map report to
confirm it occupies the required BlockRAM resources.

The default top runs the eight course vectors. Set the ISE top-level generic
`EXTENDED_DEMO` to `true` to append recovery checks for `1100=AA`, `1102=BB`,
dirty-evicted `5504=CC`, distinct high-bit address `9100=FF`, write-back and
recovery of `911F=D7`, and the index-7/offset-31 address `22FF=FF`. The extended
monitor expects 16 CPU completions, 352 memory reads, and 96 memory writes. The
eight-vector run expects 8 completions, 160 reads, and 64 writes.

The top exports the CPU request and response, memory address/direction/strobe/
data, cache event pulses, case/state/byte/valid/dirty debug signals, pass/fault,
strobe totals, maximum and most recent CPU latency, and an offset-31 observation.
It also reports the most recent acceptance-to-lookup interval, synchronous RAM
setup-to-capture interval, replacement interval, read/write hit time, and clean/
dirty miss penalty in clock cycles. The design-contract values are 1, 1, 128,
3, 2, 128, and 288 cycles respectively. Miss penalty is total miss latency less
the corresponding hit latency. These are cycle counts, not board measurements.
These ports can be connected to generated ChipScope/ILA cores by a board
project, but this source tree includes no fabricated debug core. The monitor
reports cycle counts. Convert them to nanoseconds only with the clock period
measured or confirmed for the actual board.

Run the demo regression with `scripts/run_tests.sh demo`. It checks the extended
16-vector flow, trigger gating, returned data, memory strobes, offset 31, and
the cycle counters described above.

## ISE project

No exact Spartan-3E part, package, speed grade, clock pin, reset/trigger pins, or
board UCF has been supplied. Do not use a guessed UCF or treat the generated
project as a board-ready bitstream. Once those details are available, run from
the repository root in the Xilinx ISE Tcl shell:

```sh
xtclsh scripts/build_ise.tcl xc3s500e-4-fg320 path/to/actual-board.ucf
```

Replace the example part string with the board's exact device-speed-package
and pass its real UCF. The script rejects a missing UCF or missing RTL source,
adds only the cache and demo sources listed in `scripts/build_ise.tcl`, selects
`demo_top`, and runs ISE's Generate Programming File process. It does not add
the legacy ZIP, MIG/DDR example sources, third-party CPU code, or generated
ChipScope cores. Review synthesis/map/place-and-route reports for BlockRAM
inference, LUT use by the emulator, timing, and device fit before programming.

Reset the harness before each fresh run. Reset clears the cache metadata and
restarts the 256-cycle memory initialization; it discards dirty cache contents
and is not a write-back flush. After `init_done` rises, apply one manual trigger
edge and capture the full run. The dirty replacement sequence includes 64
write-back and 64 refill strobes for the default eight vectors. Use at least
512 ILA samples around a dirty miss to include its complete transfer and the
terminal byte 31. No physical pin mapping, clock frequency, board fit, or
hardware measurement is claimed by this harness alone.
