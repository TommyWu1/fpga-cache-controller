# Verification results

Rechecked on 2026-10-15 using GHDL 6.0.0, VHDL-93. These are simulation and portable synthesis results, not on-board measurements.

| Check | Result |
|---|---|
| Synchronous RAM read/write behavior | Pass |
| Cache with asynchronous-read main memory | 1,310 transactions; 33,216 memory reads; 16,352 writes |
| Cache with one-clock registered main memory | Same transaction and transfer counts; pass |
| Unchanged local course CPU | All eight vectors pass |
| Public eight-vector demo | 8 completions, 160 reads, 64 writes, no fault |
| Extended demo | 16 completions, 352 reads, 96 writes, no fault |
| FPGA wrapper, course and extended modes | Pass with test-only ChipScope stand-ins; probe data/counts/timings checked |
| ISE build-script regression | 9 tests pass using stubbed vendor commands, including failure status, fresh output and repeated builds |
| Portable synthesis | Cache and demo synthesize; cache RAM recognized as 256 x 8 |

The regression checks all eight indices and 32 offsets, old-tag write-back addresses and bytes, terminal offset 31, saved write-data replay, high-address independence, reset during refill, and held/busy CS. It also executes 1,000 deterministic randomized transactions against an independent architectural memory model.

| Transaction | Measured clocks from acceptance to completion |
|---|---:|
| Read hit | 3 |
| Write hit | 2 |
| Clean read miss | 131 |
| Clean write miss | 130 |
| Dirty read miss | 291 |
| Dirty write miss | 290 |

The demo counters measure lookup=1 clock, RAM setup-to-capture=1 clock, clean replacement=128 clocks, dirty replacement=288 clocks, additional clean miss penalty=128 clocks, and additional dirty miss penalty=288 clocks. Replacement excludes lookup and final byte operation. Nanosecond hardware results require the actual cache clock and FPGA capture evidence.

Run `make test` to reproduce the regression, and `make demo` for both demo modes with waveforms. Logs remain under `build/ghdl/`. GitHub Actions runs the public suite on Ubuntu; the unchanged local third-party CPU test is skipped there when its source is absent.

The board wrapper has one physical input (`clk`) and internal ICON/ILA/VIO connections. Matching vendor cores must be generated locally. GHDL synthesis ignores the Xilinx `ram_style` and `ASYNC_REG` attributes with warnings; XST is the tool that applies them. These warnings do not establish Xilinx mapping or timing.
