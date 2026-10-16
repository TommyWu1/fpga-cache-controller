# Board demo

Build and program `cache_board_top` using [the hardware instructions](hardware.md).
Use [the ChipScope tables](chipscope.md) to name the VIO and ILA fields.

1. Set VIO `trig=0`, `rst=1`.
2. Release reset (`rst=0`), then wait for `init_done=1`. Initialization takes
   256 clocks after the internal reset releases. It cannot finish under reset.
3. Check ready=1, fault=0, valid/dirty masks zero and completion count zero.
4. Arm ILA before starting. For a dirty write miss, match `dbg_lookup=1` and
   `dbg_case=5`; use case 4 for a dirty read miss. Put the trigger near sample
   32 in a 512-sample buffer and sample every clock.
5. Change `trig` from 0 to 1. That starts the entire eight- or sixteen-request
   sequence automatically. Leave it high or return it low.
6. Wait for `demo_pass=1`, `demo_fault=0`, and the totals below. Reset before
   each repeat capture; another trigger after completion does not restart it.

| Mode | CPU completions | Memory reads | Memory writes |
|---|---:|---:|---:|
| Course | 8 | 160 | 64 |
| Extended | 16 | 352 | 96 |

Show correct AA/BB hit data with no memory strobes, a 32-read clean miss, and a
dirty miss with 32 old-block writes followed by 32 new-block reads. Include
offset 31. Use the extended build to show AA, BB, CC and D7 recovered after
eviction. Save the captures and stable final counters.

The six assignment measurements are lookup time, data access time, replacement
time, hit time, clean miss penalty and dirty miss penalty. Record both clock
counts and nanoseconds using the actual cache clock. The
[TA walkthrough](ta-demo-guide.md) gives the transaction tables, counter values,
event definitions and report checklist.
