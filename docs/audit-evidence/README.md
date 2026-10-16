# Evidence from the October 15, 2026 audit

Baseline source revision: `a26797a`. GHDL 6.0.0, VHDL-93, local macOS run.

- `tb_*.txt`: fresh simulator output from `make test` and `make demo`, copied without alteration. The optional local course CPU was present and tested.
- `transaction-ledger.json`: acceptance/completion times, returned data, case, metadata and memory strobe totals extracted from fresh default and extended VCD runs. Simulated clock period is 10 ns. Steps are zero-based.
- `course-waveforms.png`: plot of the actual default-mode VCD values around a read hit and dirty write miss. Simulation only.
- `build-status-check.json`: plain Tcl experiment with the unmodified script's final status logic and stubbed `process run` returns. No ISE process was executed.

The corresponding fresh GHW files are local generated outputs at `build/ghdl/demo/tb_demo_course.ghw` and `build/ghdl/demo/tb_demo.ghw`. Recreate them with `make demo`. Full core regression outputs are under `build/ghdl/all/`.

GHDL synthesis was also run for `cache_system` and `demo_top`; both completed successfully and reported a 256 x 8 cache RAM. This is not evidence of XST BlockRAM placement. No ISE/ISim/FPGA execution or hardware measurements were performed during this audit.
