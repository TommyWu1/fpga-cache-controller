# Legacy ZIP reuse and attribution

The source ZIP is a 2020 ISE 13.4 project. Its cache controller is useful for understanding the intended components but contains functional errors. Archived compile reports do not establish cache correctness, and archived place-and-route/timing files predate the final source edits.

## Reuse decisions

| Item | Decision | Reason |
|---|---|---|
| `cpu.vhd`, entity CPU_gen | Reuse unchanged locally as course stimulus; original header retained | Matches the secondary specification's rst/trig interface and four-clock CS |
| Eight CPU transaction vectors | Preserve as a compatibility regression and demo sequence with attribution | Covers hits, initial refill, clean replacement, and dirty eviction |
| SRAM geometry | Reuse 256 x 8 single-port, one-clock synchronous configuration | Matches R02/R13 |
| `SRAM.xco` / generated SRAM source | Configuration reference only; regenerate for actual Spartan-3E device | Existing IP targets Spartan-3A DSP |
| `overall.sch` | Reference for CPU/cache/memory wiring | New top-level must expose reset, manual VIO trigger, ILA observations and demo checking |
| Tags/valid/dirty organization | Retain conceptual 8-entry metadata structure | Matches assignment geometry |
| `FSM.vhd` | Replace controller implementation | Broken state sequencing, live request inputs, wrong victim address, premature byte-count termination, timing errors |
| `SDRAM_controller.vhd` | Replace with specified simulation model/demo backend | Aliases bit 15 and fills everything with 0xFF; large asynchronous RAM implementation |
| `cache.vhd`, `cacheSRAM.vhd` | Do not import | Incomplete files excluded from active ISE project |
| Old executables, netlists, wave configuration, timing reports | Local review evidence only | Not portable source or fresh validation |
| Generated DDR/MIG example directories | Do not integrate | Not part of active cache system; do not introduce an unrelated physical DDR interface |

## Preserved course sequence

The original generator's header credits Victor Dumitriu, Ryerson University. The following vectors are derived from its pattern table; data is relevant only for writes.

| Step | Operation | Address | Write data | Expected behavior from a fresh cache and 0xFF main memory |
|---|---|---|---|---|
| 0 | Write | 0x1100 | 0xAA | Clean miss, refill index 0, then dirty write |
| 1 | Write | 0x1102 | 0xBB | Write hit |
| 2 | Read | 0x1100 | - | Read hit, 0xAA |
| 3 | Read | 0x1102 | - | Read hit, 0xBB |
| 4 | Read | 0x3346 | - | Clean miss at index 2, 0xFF |
| 5 | Read | 0x4444 | - | Clean replacement at index 2, 0xFF |
| 6 | Write | 0x5504 | 0xCC | Dirty replacement at index 0: write back 0x1100 block, refill 0x5500, write 0xCC |
| 7 | Read | 0x6606 | - | Dirty replacement at index 0: write back 0x5500 block, refill 0x6600, return 0xFF |

Extended tests must revisit 0x1100/0x1102 and 0x5504 after eviction to prove writes reached the correct main-memory blocks. They must also inspect offsets 0 and 31 and distinguish 0x1100 from 0x9100.

## Local reference setup

An unchanged CPU source is retained at `reference/local/course_cpu.vhd`. The reviewed SRAM configuration is retained at `reference/local/legacy_SRAM.xco`. Both are ignored by Git. Their hashes are recorded in `source-manifest.json`; this records provenance without publishing the supplied source or vendor-generated code.

The public repository will contain the original corrected controller, tests, build recipes, and documentation. Original author attribution remains in any local or course submission that reuses the CPU generator. At this planning stage no corrected RTL has been implemented, and no legacy code is being claimed as original work.
