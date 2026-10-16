# ChipScope setup in ISE 13

`cache_board_top` already connects the demo to ICON, ILA and VIO. Its only
physical port is `clk`. Reset, trigger, results and waveforms use JTAG through
ChipScope. Generate the vendor cores below for the same device/package/speed
as the board. Generated cores stay local under `ip/generated/`.

## Generate the three cores

In ISE, select **Project > New Source > IP (CORE Generator & Architecture
Wizard)**. Find the ChipScope Pro cores under the debug/verification category.
Generate each core with exactly these names and interfaces:

| Core | Component name | Settings |
|---|---|---|
| ICON | `cache_icon` | 2 control ports, no optional external clock/reset ports |
| ILA | `cache_ila` | 1 trigger port, `TRIG0` width 128, data same as trigger, depth 512, rising-edge clock, no trigger output |
| VIO | `cache_vio` | Synchronous input width 192, synchronous output width 2, rising-edge clock; disable asynchronous ports |

For ILA, use a basic match unit so individual bits can be matched as 0, 1 or
don't-care. Disable optional input pipeline stages if the generator exposes
that setting. The wrapper expects ILA ports `CONTROL`, `CLK`, `TRIG0` only.
The VIO ports must be `CONTROL`, `CLK`, `SYNC_IN`, `SYNC_OUT` only. ICON must
have `CONTROL0` and `CONTROL1`, both 36 bits. Compare these with the generated
instantiation templates before building.

Collect `cache_icon.ngc`, `cache_ila.ngc`, and `cache_vio.ngc` in one directory,
for example `ip/generated/chipscope/`. Keep the `.xco` settings and any generated
constraints alongside them. Apply any extra constraints required by your core
version. Do not add `sim/chipscope_models.vhd` to the hardware project: those
stand-ins exist only to test the wrapper wiring in simulation.

The interfaces follow the ISE-era vendor documentation:
[ICON DS646](https://docs.amd.com/api/khub/documents/t049bOP5e3Pp0ZwXfkJsng/content),
[ILA DS299](https://docs.amd.com/api/khub/documents/TFpUi0sYWIhAgmJvDiBGpg/content),
[VIO DS284](https://docs.amd.com/api/khub/documents/n8VGhLNDSpeVqy_b0~xTTg/content).

## VIO controls and results

Split the buses into the following fields in Analyzer. Addresses/data should
use hex; counters should use unsigned decimal. The names below are labels to
assign in Analyzer, not automatically named ports in a generated probe file.

| `SYNC_OUT` bits | Name | Use |
|---|---|---|
| 0 | `rst` | Active-high reset; start at 1, then release to 0 |
| 1 | `trig` | Start at 0; change to 1 once initialization finishes |

| `SYNC_IN` bits | Name |
|---|---|
| 7:0 | `completed_count` |
| 23:8 | `memory_read_count` |
| 39:24 | `memory_write_count` |
| 55:40 | `last_latency` |
| 71:56 | `max_latency` |
| 87:72 | `lookup_cycles` |
| 103:88 | `ram_access_cycles` |
| 119:104 | `replacement_cycles` |
| 135:120 | `read_hit_cycles` |
| 151:136 | `write_hit_cycles` |
| 167:152 | `clean_miss_penalty` |
| 183:168 | `dirty_miss_penalty` |
| 184 | `init_done` |
| 185 | `demo_pass` |
| 186 | `demo_fault` |
| 187 | `cpu_finished` |
| 188 | `cpu_rdy` |
| 189 | `saw_offset_31` |
| 190 | `cpu_active` |
| 191 | Reserved, zero |

## ILA waveform and trigger fields

All these fields share the 128-bit `TRIG0` bus. Set unrelated trigger bits to
don't-care. A 512-sample capture should place the trigger near sample 32 so
there is room for a complete 291-clock dirty read miss. Sample every cache
clock without storage filtering when measuring time.

| `TRIG0` bits | Name |
|---|---|
| 15:0 | `cpu_addr` |
| 23:16 | `cpu_wdata` |
| 31:24 | `cpu_rdata` |
| 47:32 | `mem_addr` |
| 55:48 | `mem_wdata` |
| 56 | `cpu_cs` |
| 57 | `cpu_wr` |
| 58 | `cpu_rdy` |
| 59 | `mem_wr` |
| 60 | `mem_strb` |
| 61 | `dbg_accept` |
| 62 | `dbg_lookup` |
| 63 | `dbg_done` |
| 64 | `dbg_replacement_done` |
| 65 | `dbg_ram_setup` |
| 66 | `dbg_ram_capture` |
| 69:67 | `dbg_case` |
| 73:70 | `dbg_state` |
| 78:74 | `dbg_byte` |
| 86:79 | `dbg_valid` |
| 94:87 | `dbg_dirty` |
| 95 | `cpu_active` |
| 96 | `cpu_finished` |
| 97 | `init_done` |
| 98 | `demo_pass` |
| 99 | `demo_fault` |
| 100 | `saw_offset_31` |
| 127:101 | Reserved, zero |

For a dirty write miss, match `dbg_lookup=1` and `dbg_case=5`. For a dirty
read miss use case 4. For a specific read hit, match `dbg_done=1`, case 0, and
the desired `cpu_addr`. Reset and start another run for each new capture.
Save your Analyzer bus labels and trigger settings for the TA session.
