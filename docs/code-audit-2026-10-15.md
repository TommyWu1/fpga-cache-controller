# Code audit against the COE758 cache specifications

Reviewed October 15, 2026 (America/Toronto). Baseline: `a26797a`.
User-confirmed environment: Spartan-3E development board, Xilinx ISE 13.

**Baseline verdict: the cache behavior passes the available functional checks; the repository is not a complete, board-ready ISE project.** There are two high-priority build/integration defects, two incorrect demo instructions, and a conditional asynchronous-input issue. No cache datapath or replacement error was reproduced. This review was read-only. The follow-up changes below address the source and documentation findings.

## Follow-up corrections

The supplied `cache_board_top` now keeps all observation signals internal and connects ICON/ILA/VIO. The build script selects it, requires generated core netlists, checks the final ISE process status and rejects stale or absent output. The trigger passes through two synchronization stages. The README and current demo instructions use reset-release-before-initialization and one trigger per full sequence.

The findings below describe baseline `a26797a`, including its original file/line references. Actual ISE compilation and board measurements remain outstanding. See [the current hardware setup](hardware.md) and [ChipScope core settings](chipscope.md).

## Review scope and authority

Read all eight RTL files, seven simulation/support files, both scripts, the Makefile, CI configuration, and every project document. Compared the implementation directly with the local nine-page main specification and three-page secondary-component specification. Visually inspected the main memory/SRAM timing diagrams and results table. Checked the unchanged local course CPU and legacy memory interface for compatibility context. The archived ZIP implementation and its old reports are not the active implementation or fresh build evidence.

Primary local specifications:

- `docs/sources/coe758-cache-project-specification.pdf`: geometry, cache cases, interfaces, Spartan-3E target, six hardware measurements.
- `docs/sources/coe758-project1-secondary-components.pdf`: supplied CPU, per-transaction manual trigger, ICON/ILA/VIO integration, memory timing.

The specifications are locally retained and ignored by Git. `docs/requirements.md` is a useful interpretation, not a replacement for the original documents. The secondary diagram's 17-bit address label conflicts with the main specification and supplied CPU's 16-bit address; using 16 bits is consistent with the latter two.

## Findings, ordered by priority

### F1 / P1: the build selects an unsuitable physical top

Locations: `scripts/build_ise.tcl:51`; `rtl/demo_top.vhd:10-52`.

The script selects `demo_top` as the FPGA top. Its interface has 288 scalar bits: three inputs and 285 outputs. Observation buses and counters therefore become physical ports. Comments describing them as ChipScope probes do not connect them to a debug core. The documented example XC3S500E has at most 232 user I/Os across its packages; some are input-only. The present interface cannot fit that example device. See [AMD DS312](https://docs.amd.com/v/u/en-US/ds312).

There is no board wrapper, board UCF, or active ICON/ILA/VIO integration in the tracked source list. Merely supplying a UCF is insufficient. For another Spartan-3E part, fit remains device/package-dependent, and the instrumentation is still missing.

Resolution: instantiate `demo_top` inside a board wrapper, keep observation buses internal, connect them to ChipScope ICON/ILA/VIO, expose only real board pins, add the generated cores/netlists, and select that wrapper as the implementation top. Constrain actual pins, I/O standards, and the common clock. Re-run synthesis, MAP, place-and-route and timing with debug included.

### F2 / P1: the build script can report success for a failed implementation

Location: `scripts/build_ise.tcl:59-71`, especially `65-66`.

The script treats the return from `process run` like a conventional numeric exit status. Xilinx documents that this command reports whether it launched the process, regardless of the process outcome. The script never queries the final process status. It accepts textual `false` and numeric `0`, and rejects numeric `1`. A successful launch followed by a synthesis/MAP/bitgen error can therefore be reported as success.

Confirmed with a plain Tcl stub against the unmodified status-checking section; see [build-status-check.json](audit-evidence/build-status-check.json). This experiment did not execute ISE. The vendor reference consulted is [UG628 v14.7, printed pp. 369-370 and 401](https://docs.amd.com/api/khub/documents/OxIb6JgZldFkcqM0jPOm9A/content); validate the same command's help in the installed ISE 13 minor version.

Resolution: check launch failure as a Boolean, then query `process get "Generate Programming File" status`. Require an acceptable final status such as `up_to_date` or reviewed `warnings`, reject errors/aborts/incomplete states, and verify a newly generated bitstream exists. The script's exit code currently cannot serve as hardware-build evidence.

### F3 / P2: the documented reset order prevents initialization

Locations: `docs/demo.md:16`; `rtl/demo_memory.vhd:65-76`.

The procedure says to assert reset, allow initialization to finish, then release reset. While reset is asserted, every clock clears `initialized` and returns the initializer to byte zero. Waiting for `init_done` under reset never completes.

Correct order: assert reset for several clocks, release reset, wait for `init_done=1` after 256 initialization clocks plus reset synchronization, then trigger. This is corrected in the new TA guide.

### F4 / P2: the documented manual stepping does not match the current demo

Locations: `docs/demo.md:17`; `rtl/demo_cpu.vhd:82-91`; `rtl/demo_top.vhd:94-96`.

The original supplied CPU uses one trigger per transaction. The new `demo_cpu` automatically advances through all eight or sixteen transactions after one trigger. The top rejects further starts after `cpu_finished=1` until reset. Following the old instructions cannot pause between cases and can leave the ILA armed too late.

Correct procedure for current `demo_top`: arm capture first, give one trigger edge for the entire run, inspect the recorded sequence, and reset before rerunning. If the lab requires the original manual CPU behavior, integrate that CPU in a separate wrapper or add an explicit stepping mode; the simulation compatibility test alone does not provide that hardware top. The distinction is an integration/demonstration deviation, not a failure of the cache CPU interface.

### F5 / P2, conditional: a physical trigger input needs synchronization

Location: `rtl/demo_top.vhd:94-98`.

Raw `trig` enters the edge detector and start-condition logic. `trig_previous` records its prior value but does not isolate the control logic behind a two-register synchronizer. This matters if the input is connected to a physical button or asynchronous VIO output: hardware may miss or misinterpret an edge. A synchronous VIO output clocked by the cache clock satisfies the current input assumption.

Resolution: use synchronous VIO for this demo; for a physical trigger, add synchronization before edge detection and debounce if repeatable button behavior is required. Metastability is a hardware risk here, not an observed simulation failure.

## Specification compliance

| Requirement / original pages | Assessment | Evidence or outstanding work |
|---|---|---|
| VHDL controller and local BlockRAM, main pp. 1-3, 8 | VHDL passes; physical BlockRAM mapping unverified | Fresh GHDL compile/synthesis recognizes 256 x 8 RAM. Require XST/MAP evidence for cache RAM |
| 256 bytes, eight lines, 32 one-byte words, pp. 2-3 | Pass in simulation/source | `cache_pkg`, `cache_ram`, all-index/all-offset regression |
| 16-bit address, 8/3/5 tag/index/offset and AWR, p. 3 | Pass | Saved request address and metadata; high-bit independence tests |
| Write hit and read hit, p. 4 | Pass | Correct readback, valid/dirty state, no memory strobes on hits |
| Clean miss fetches all 32 bytes and replays request, p. 4 | Pass | Patterned full-address memory, exact transfer checks, changed live CPU inputs |
| Dirty miss writes old-tag victim, refills new-tag line, replays, pp. 4-5 | Pass | Exact old/new block addresses and bytes, offset 31, eviction recovery, both request directions |
| CPU direction, four-cycle CS, RDY, pp. 5-6 | Pass | Single acceptance, ready low while busy, held/busy CS tests, unchanged course CPU compatibility |
| Shared clock and memory setup/strobe, pp. 6-7 | Pass for tested fixed-latency contract | Asynchronous and continuously registered-read models pass; other memory latency needs integration validation |
| Synchronous local SRAM interface, pp. 8-9 | Source and simulation consistent | Rising-edge RAM operations; controller setup/capture states |
| Spartan-3E target, p. 9 | Incomplete | ISE 13 confirmed, exact part/package unknown; F1 prevents documented example build |
| Supplied CPU and ICON/ILA/VIO, secondary pp. 1-2 | Partial | Local CPU regression passes; active demo substitutes automatic sequencer and lacks debug cores |
| Main-memory system, main p. 2 and secondary p. 3 | Partial, backend acceptance unresolved | Demo has eight full-address blocks totaling 256 bytes, not general main memory or physical SDRAM |
| Symbol and block diagram, main p. 9 | Incomplete in tracked deliverables | Architecture prose exists; final implementation-matching symbol/system/FSM figures are absent |
| Six measurements in ns from hardware emulation, main p. 9 | Incomplete | Simulation counters exist; no fresh board captures, actual clock, or on-board results |
| FPGA demo and final report, main p. 9 | Incomplete | No board-ready implementation or completed final report in tracked files |

The bounded backend is an explicit project choice, not a newly discovered hidden defect. It supports blocks `1100`, `3340`, `4440`, `5500`, `6600`, `9100`, `22E0`, `77E0`; unsupported requests set a fault. It cannot be presented as a full main-memory controller. Confirm the lab accepts this emulation approach, or integrate the required lab backend. This audit does not invent a requirement to implement a physical SDRAM electrical interface where the lab may provide one.

## Fresh verification

Executed locally October 15 using GHDL 6.0.0, VHDL-93:

| Check | Observed result |
|---|---|
| `make test` | PASS, including unchanged local course CPU |
| Asynchronous backing-memory regression | 1,310 transactions; 33,216 reads; 16,352 writes |
| One-clock continuously registered backing-memory regression | Same totals; PASS |
| `make demo` | Both modes PASS and fresh GHW waveforms generated |
| Default eight-vector mode | 8 completions, 160 reads, 64 writes, fault=0 |
| Extended mode | 16 completions, 352 reads, 96 writes, fault=0 |
| GHDL synthesis of `cache_system` and `demo_top` | Both succeed; cache RAM recognized as 256 x 8 |
| Fresh VCD extraction | All 24 transactions across both modes agree with expected cases, data, transfers and latency |
| Build-script status experiment | Incorrect handling reproduced using Tcl stubs |

Logs and the transaction ledger are in `docs/audit-evidence/`. The [waveform image](audit-evidence/course-waveforms.png) is a plot of fresh simulation data. It is not ChipScope evidence. GHDL RAM recognition does not prove a RAMB16 was placed by XST/MAP.

The existing tests have useful breadth: deterministic random traffic, every cache index/offset, saved-request data, high-bit addressing, dirty recovery, reset during refill, held CS, and exact write-back/refill bytes. Remaining useful checks include reset during dirty write-back, release of reset with CS held high, a strict strobe-gated external memory model if that is the lab backend, and hardware trigger conditioning. The RAM unit test checks edge results but does not independently assert that output remains unchanged between edges. These are coverage limitations, not reproduced functional defects.

## Boundaries and next actions

No ISE 13, XST, ISim, ChipScope, or physical FPGA is accessible here. The exact first failure on the user's installation is unknown because no error log was supplied. I do not claim ISE compilation, BlockRAM placement, fit, timing closure, pin correctness, hardware operation, or TA approval. I also do not infer current deadlines or grading details from old project PDFs.

Resolve F1 and F2 first, follow the corrected reset/capture procedure, and generate fresh device-specific reports. Confirm the bounded backend and automatic versus original manual CPU choice with the lab requirements. Then collect the hardware observations and six measurements described in [the TA run and demo guide](ta-demo-guide.md).
