# Cache controller requirements and acceptance criteria

Reviewed on 2026-10-13. Labels distinguish stated assignment requirements, consequences of those requirements, and engineering decisions for a reproducible demo.

## Source hierarchy and unresolved details

1. The supplied nine-page cache project PDF defines geometry, behavior, interfaces, target, and six required measurements.
2. The three-page secondary-component specification explains the course CPU generator and ChipScope integration.
3. The local F2026 course-outline snapshot describes grading and schedules. Official outline pages retrieved during this review exposed F2025 content; both outline versions use week 7 for Project 1 demonstration/report. The old project PDF uses week 8. Plan against week 7, and use the current section's D2L/lab instructions for the actual calendar deadline. No calendar deadline has been verified.
4. The ZIP is an implementation reference, not an authority that can override the assignment.

Primary links:

- [Project specification](https://www.ee.torontomu.ca/~lkirisch/ele758/labs/Cache%20Project%5B12-09-10%5D.pdf)
- [Course outline](https://www.ee.torontomu.ca/undergraduate/outlines/COE758_course_outline.html)
- [Course design-process tutorial](https://www.ee.torontomu.ca/~lkirisch/ele758/handouts/COE758_Digital_Design_Tutorial.pdf)

The secondary diagram labels the DRAM address `Address[16..0]`, conflicting with the main specification's 16-bit address and the supplied CPU's `[15..0]`. Use 16 bits; retain this discrepancy in the report. The main PDF's reference to Figure 3 for address fields means Figure 4. Signal names DIN/DOUT are relative to each component: CPU DOUT is cache write-data input; CPU DIN receives cache read-data output.

The documents do not prescribe reset behavior, an exact hit latency, an operating clock, a physical board's pins, a detailed report template, a memory-ready handshake, or a cycle-accurate definition for every performance metric. Design decisions below make those explicit without claiming they were specified by the assignment.

## Traceability matrix

| ID | Requirement | Basis | Acceptance evidence |
|---|---|---|---|
| R01 | Implement the cache controller in VHDL, integrate a cache with local BlockRAM | Main pp. 1-3 | RTL compilation, hierarchy, synthesis RAM report |
| R02 | Cache data capacity 256 bytes = 8 lines x 32 one-byte words | Main pp. 2-3 | 256 x 8 RAM configuration and all-index/offset tests |
| R03 | CPU address 16 bits: tag 15:8, index 7:5, offset 4:0 | Main p. 3 | Decode tests and component symbol |
| R04 | Store CPU address in AWR; retain tags, valid and dirty bits per line | Main pp. 3-4 | Request register, metadata inspection, waveform |
| R05 | Write hit writes indexed/offset byte and sets valid and dirty | Main p. 4 case 1 | Read-back, metadata, zero main-memory strobes |
| R06 | Read hit returns indexed/offset byte | Main p. 4 case 2 | Correct byte at completion, zero memory strobes |
| R07 | Clean miss loads all 32 bytes, updates tag/valid, then performs original operation | Main p. 4 case 3 | 32 read strobes, offsets 0..31, replay check |
| R08 | Dirty miss writes all 32 victim bytes to old-tag address, loads requested line, replays operation | Main pp. 4-5 case 4 | 32 writes then 32 reads, correct addresses and later eviction recovery |
| R09 | CPU CS is asserted for four clocks after address/direction/data stabilize; write=1, read=0 | Main p. 5; secondary pp. 1-2 | Exactly one acceptance per CS assertion |
| R10 | RDY high idle, low after acceptance until operation complete | Main p. 6 | Protocol assertions and ILA trace |
| R11 | Memory address 16 bits, data 8 bits; write=1/read=0 | Main pp. 6-7 | Full-address memory model and port widths |
| R12 | Memory signals set first; MEMSTRB high one clock on following cycle; repeat for 32 bytes | Main p. 7; secondary p. 3 | Setup-cycle/pulse-width/address-stability assertions |
| R13 | SRAM address/data 8 bits, WEN; read output after next rising edge, writes on rising edge | Main pp. 8-9 | Synchronous RAM unit test and ISE IP configuration |
| R14 | Common synchronous clock; rising-edge memory operations | Main pp. 5-8 | One clock domain for cache, CPU, memory and debug |
| R15 | Target Xilinx Spartan-3E | Main p. 9; user confirmation | Exact part recorded; IP regenerated for same part; FPGA build |
| R16 | Symbol, system block diagram, compilable VHDL, hardware demonstration and final report | Main p. 9; outline; secondary | Original diagrams, fresh reports, board captures, final report |
| R17 | Measure hit/miss determination, data access, block replacement, hit time, clean miss penalty, dirty miss penalty in ns based on hardware emulation | Main p. 9 | Hardware captures/counters with clock period and measurement definitions |

The described organization implies direct mapping, write-back, and write-allocate. A hit is `valid(index) AND stored_tag(index) = request_tag`. Invalid entries miss regardless of their stored tag. Dirty eviction is required only when the victim is both valid and dirty.

## Engineering choices

- E01: Add synchronous reset to the new cache. Reset clears valid/dirty metadata and all control outputs; data RAM need not be cleared. Reset discards cached modifications and is a benchmark restart, not a flush operation.
- E02: Save address, write direction, and write data together on request acceptance. Maintain only one outstanding request.
- E03: Detect CS low-to-high transitions in the synchronous domain. Accept only in IDLE. Requests asserted while busy are unsupported and are not queued; their strobes must not become delayed requests when IDLE returns.
- E04: Refilled lines become clean after all 32 writes complete; replaying a CPU write sets dirty. CPU read data is registered and stable when RDY rises.
- E05: VHDL-93 synthesizable core with `numeric_std`; avoid `process(all)`, external names, and other VHDL-2008-only synthesis dependencies in ISE RTL.
- E06: Simulation main memory covers all 65,536 byte addresses without truncation. Hardware emulation may cover named demo blocks with full address decoding and an unsupported-address flag; its capacity is disclosed and must be acceptable to the lab demonstrator before being treated as the course memory backend.
- E07: Fixed memory interface timing follows the supplied figures; no unspecified memory-ready signal is added to the course interface. The memory read value must be valid at the ending edge of MEMSTRB. An actual controller with different latency requires an adapter and a documented timing change.
- E08: Separate deterministic course-compatible `0xFF` initialization from patterned regression initialization. Patterned data detects duplicated or shifted bytes.
- E09: Every claim of simulated, synthesized, implemented, or hardware-verified status requires evidence from the corresponding stage.

## Delivery schedule and grading

The local F2026 outline states: week 4 symbol/block diagram; weeks 5-6 VHDL, compilation, simulation/hardware-emulation verification; week 7 demonstration and report. Its project contribution is 14 course percentage points: 2 symbol/block diagram, 3 compiled VHDL demonstration, 4 FPGA demonstration, 5 report. Submit the report after successful demonstration within the demonstration week. These are course percentage points, not percentages within the project.

Required hardware details are the board model, FPGA part/package/speed, clock frequency, programming cable, and accessible ISE/ChipScope installation. The family is confirmed; the other details remain external inputs to the board-integration milestone, not guessed settings in the cache core.
