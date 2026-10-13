# Hardware demonstration and evidence plan

Status: simulation verified; hardware procedure awaits the physical board/toolchain.

## Before building a bitstream

Record board model, Spartan-3E part/package/speed grade, oscillator frequency, reset polarity/pin, clock pin, programming cable and ISE/ChipScope version. Verify each against the physical board/manual. Use that exact part for the project and regenerated SRAM, ICON, ILA and VIO. Do not copy the ZIP's Spartan-3A DSP target or unrelated MIG example pin constraints.

Use the board oscillator as the common cache/CPU/memory/debug clock. Constrain it with the measured/documented period, not an assumed 50 MHz. If a DCM changes frequency, constrain its clocks too and record the actual cache clock used for results. Read synthesis, map, place-and-route and timing reports from this revision; require inferred/generated cache BlockRAM, no unintended latches, no black boxes, no timing violations, and resource fit including ChipScope. Review rather than blanket-ignore warnings.

Choose either the lab's compatible main-memory controller or the explicitly bounded emulator in the design. Obtain lab acceptance of the bounded backend if required; a simulation-only memory array is not hardware evidence.

## Compatibility demo

1. Program the fresh bitstream. Record Git commit SHA, part, clock, build tool version and bitstream hash locally.
2. Assert reset through the approved board/VIO path; allow memory initialization to finish. Release reset; verify RDY=1, valid=0, dirty=0, MEMSTRB=0.
3. Use VIO trig low, then high to generate one transaction. Return trig low. Wait for completion and the CPU CS pulse to end before advancing. Observe each of the eight vectors in `reuse.md`.
4. Show write misses allocate, writes mark dirty, read hits return 0xAA/0xBB, clean replacement issues 32 reads, and dirty replacement issues 32 victim writes followed by 32 requested-block reads.
5. For dirty replacement of 0x1100 by 0x5504, show write-back addresses 0x1100..0x111F and refill addresses 0x5500..0x551F. The monitor must count offset 31.
6. Run an authored extended demo mode which revisits 0x1100/0x1102 and 0x5504, tests offset 31, distinguishes 0x1100 and 0x9100, and exercises index 7. Extended mode uses fresh baseline initialization and explicit stimulus; it must not silently modify the supplied CPU component.
7. Export ILA captures and timing-counter snapshots. Assert sticky fault=0, expected transaction count, exact block-strobe counts, and expected read responses. Demonstrate at least one dirty-eviction recovery, not only dirty-bit toggling.

## Required timing results

| Assignment metric | Measurement definition |
|---|---|
| Hit/miss determination | Acceptance edge to registered lookup classification |
| Data access | RAM address setup to controller capture, with the RAM's one-edge read latency disclosed separately |
| Block replacement | Miss decision to final refill metadata commit; distinguish clean and dirty replacements |
| Hit time, cases 1 and 2 | Acceptance to write commit/read response and RDY return; report both write and read |
| Clean miss penalty | Clean miss total latency and additional cycles over the matching read/write hit |
| Dirty miss penalty | Dirty miss total latency and additional cycles over the matching read/write hit |

Report both cycles and nanoseconds: `time_ns = cycles * 1e9 / cache_clock_hz`. Establish each event definition in the report. Label design predictions, simulation measurements, static timing analysis and on-board measurements separately. Do not substitute maximum-frequency or clock-to-pad reports for the required transaction measurements.

## Completion evidence

- Component symbol and original system/FSM diagrams match implemented ports/states.
- Self-checking simulation regression passes and produces actual logs/waveforms.
- ISE builds the current commit for the physical Spartan-3E part with valid constraints.
- On-board ILA captures cover read hit, write hit, clean miss and dirty miss, including 32/64 transfer strobes and byte 31.
- Six measurements are populated from on-board evidence; clock and event definitions accompany them.
- Final report includes design, attribution, methodology, test results, hardware observations, utilization/timing, measurements and backend limitations.
- Public README links the original implementation, verified results, representative exported captures and an optional demonstration video. Readiness claims match evidence; sensitive or vendor-generated artifacts remain local.

Both simulation demo modes pass. A fresh ISE implementation and successful board execution with these captures are still required for hardware demonstration readiness.
