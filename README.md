# COE758 cache controller

This project implements a 256-byte cache in VHDL for a Spartan-3E FPGA using
Xilinx ISE 13. It has eight 32-byte lines, direct mapping, write-back and
write-allocate.

Start with simulation. For the board demo, generate the three ChipScope cores
and supply the board's clock constraints. The FPGA top is `cache_board_top`.
Its only physical input is the clock; reset and trigger come from ChipScope VIO.

## 1. Run the simulation

Install [GHDL](https://github.com/ghdl/ghdl/releases), Python 3 and Tcl. Open a
terminal in this project folder:

```sh
make test
make demo
```

`make test` checks the cache, both memory timing models, both demo modes,
ChipScope wrapper wiring and the ISE build script. It should finish with all
PASS messages and the Python tests reporting `OK`. The core regression runs
1,310 transactions per memory model.

`make demo` also saves waveforms. Open either file in GTKWave:

| File | Contents |
|---|---|
| `build/ghdl/demo/tb_demo_course.ghw` | The eight course transactions |
| `build/ghdl/demo/tb_demo.ghw` | Sixteen transactions, including eviction recovery |

If GHDL is installed somewhere else, run `make test GHDL=/path/to/ghdl`.
The runner also checks the local `build/tools/ghdl/` download. Logs are under
`build/ghdl/`. The optional original course CPU test is skipped if its local
source is absent; the public demo works without that file.

## 2. Set up ISE and ChipScope

Use the FPGA part, package, speed grade and oscillator details printed on the
board or listed in its manual. The example part below is not a board selection.

1. Create a VHDL project in ISE 13 for the exact board device.
2. Generate `cache_icon`, `cache_ila` and `cache_vio` using the names and
   settings in [ChipScope setup](docs/chipscope.md). Put their `.ngc` files in
   `ip/generated/chipscope/`. The RTL already connects these cores.
3. Copy [the clock-constraint example](constraints/board.ucf.example) to a
   local `board.ucf`. Replace the pin, I/O standard and period from the board
   manual. There are no physical reset or trigger pins to assign.
4. In the ISE Tcl shell, run from the project folder:

   ```sh
   xtclsh scripts/build_ise.tcl xc3s500e-4-fg320 board.ucf ip/generated/chipscope course
   ```

   Replace `xc3s500e-4-fg320` with your actual device-speed-package. Use
   `extended` instead of `course` for the sixteen-transaction build.
5. Check the synthesis, MAP and timing reports. The cache RAM must use
   BlockRAM, the complete design must fit, and the clock must meet timing.
   The script checks the final process status and requires a fresh bitstream.
6. Program `build/ise_demo/cache_board_top.bit` with iMPACT. Open ChipScope
   Analyzer and label the buses using [the probe tables](docs/chipscope.md).

For a manual GUI build, the source list and simulation steps are in the
[lab walkthrough](docs/ta-demo-guide.md). Keep all `sim/` files out of FPGA
synthesis. They include test-only replacements for the ChipScope cores.

## 3. Run the board demo

1. In VIO set `trig=0` and `rst=1`.
2. Set `rst=0`, then wait for `init_done=1`. Memory initialization starts
   after reset is released.
3. Arm the ILA. For the dirty write miss, trigger on `dbg_lookup=1` and
   `dbg_case=5`. With 512 samples, put the trigger near sample 32.
4. Change `trig` from 0 to 1. One edge starts the whole sequence.
5. Wait for `demo_pass=1`. Check `demo_fault=0` and the totals below.
6. Reset and repeat to capture another case. A second trigger after completion
   does not restart the demo.

## 4. Show the TA

| Step | CPU request | Expected result |
|---:|---|---|
| 0 | Write `1100=AA` | Clean miss; fetch 32 bytes, then write AA |
| 1 | Write `1102=BB` | Write hit; no main-memory transfer |
| 2 | Read `1100` | Read hit returns **AA** |
| 3 | Read `1102` | Read hit returns **BB** |
| 4 | Read `3346` | Clean miss returns **FF** |
| 5 | Read `4444` | Clean replacement returns **FF** |
| 6 | Write `5504=CC` | Write back `1100..111F`, refill `5500..551F`, write CC |
| 7 | Read `6606` | Write back `5500..551F`, refill `6600..661F`, return **FF** |

Show a hit, a clean miss and a dirty miss in ChipScope. Hits have no memory
strobes. A clean miss has 32 read strobes. A dirty miss has 32 write strobes
followed by 32 reads. Include offset 31 in each block transfer.

Then run the extended build. It reads back **AA, BB, CC and D7 after eviction**
and checks high address bits and the last byte of a line.

| Final value | Course mode | Extended mode |
|---|---:|---:|
| `completed_count` | 8 | 16 |
| `memory_read_count` | 160 | 352 |
| `memory_write_count` | 64 | 96 |
| `demo_pass` / `demo_fault` | 1 / 0 | 1 / 0 |

Bring the controller symbol/block diagram, utilization and timing reports,
saved ChipScope captures, and the six timing measurements. The
[lab walkthrough](docs/ta-demo-guide.md) lists each measurement and capture.
Convert clock counts using `time_ns = cycles * 1000 / clock_MHz`.

## What has been checked

GHDL simulation and portable synthesis have been run locally. The board wrapper
is simulated with test stand-ins for the vendor cores. The build script is
tested with stubbed ISE commands. Actual ISE compilation, FPGA timing and board
captures still need to be checked on the lab workstation.

The demo's backing memory stores eight named blocks, totaling 256 bytes. It is
not a physical SDRAM controller. Check that the TA accepts this backend for
hardware emulation. The independent cache regression uses the full 16-bit
address space.

## Files and references

- [ChipScope configuration and probe labels](docs/chipscope.md)
- [Detailed lab walkthrough and expected timings](docs/ta-demo-guide.md)
- [Cache architecture](docs/architecture.md)
- [Assignment requirements](docs/requirements.md)
- [Verification results](docs/results.md)
- [Original code audit](docs/code-audit-2026-10-15.md)

The assignment and eight compatibility vectors come from COE758. The locally
retained course CPU credits Victor Dumitriu, Ryerson University. See
[reuse and attribution](docs/reuse.md) for the source history. Course reference
files and generated Xilinx IP are kept out of Git.
