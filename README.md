# FPGA Cache Controller

A 256-byte direct-mapped cache in VHDL, with write-back and write-allocate behavior, designed for Xilinx Spartan-3E.

**Simulation verified.** The cache regression passes 1,310 transactions with both asynchronous and one-clock registered main-memory models. The supplied course CPU's eight vectors and the public demo's eight- and sixteen-transaction modes also pass. GHDL synthesis recognizes the cache as a 256 x 8 RAM. Physical FPGA implementation and measurements are pending the board's exact part, constraints, and ISE setup.

## Run

Install [GHDL](https://github.com/ghdl/ghdl/releases), then run:

```sh
make test
make demo
```

`make demo` runs both demonstration modes and saves waveforms at `build/ghdl/demo/tb_demo.ghw` (extended) and `build/ghdl/demo/tb_demo_course.ghw` (eight vectors). Set `GHDL=/path/to/ghdl` if it is not on your PATH. The runner also finds the locally downloaded simulator under `build/tools/ghdl/`.

The optional unchanged course CPU source is kept at `reference/local/course_cpu.vhd`; its test is explicitly skipped if that local file is absent. The public demo and main regression run without it.

## Design

CPU addresses are 16 bits: 8-bit tag, 3-bit index and 5-bit byte offset. Eight cache lines each hold 32 bytes. The controller captures each CPU request once, handles hits locally, writes dirty victims to their stored-tag addresses, refills all 32 bytes, then completes the saved request.

- [Architecture and interfaces](docs/architecture.md)
- [Requirements](docs/requirements.md)
- [Verification results](docs/results.md)
- [Hardware setup](docs/hardware.md)
- [Demonstration procedure](docs/demo.md)
- [Reference reuse and attribution](docs/reuse.md)

The synthesizable demo uses a bounded backing memory with full-address decoding for eight documented blocks. It is an emulation environment, not a full 64 KiB memory or a physical SDRAM controller. The independent simulation model covers all 65,536 byte addresses.

## Attribution

The requirements and compatibility vectors originate from COE758. The locally retained course CPU generator credits Victor Dumitriu, Ryerson University. The corrected cache, public stimulus sequencer, tests and build files are developed here; third-party source and generated vendor IP are excluded from the public repository. Source fingerprints and reuse decisions are recorded in `docs/source-manifest.json` and `docs/reuse.md`.
