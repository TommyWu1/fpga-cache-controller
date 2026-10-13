# Cache architecture

The cache contains eight direct-mapped lines of 32 one-byte words. `cpu_addr(15:8)` is the tag, `(7:5)` the index, and `(4:0)` the byte offset. Each line has an 8-bit tag, valid bit and dirty bit.

## Modules

- `cache_controller`: request capture, metadata and memory transfer sequencing.
- `cache_ram`: 256 x 8 synchronous, single-port, write-first RAM; intended for BlockRAM inference.
- `cache_system`: controller/RAM wiring with CPU, memory and observation ports.
- `demo_cpu`: public stimulus using the eight course vectors, with optional recovery checks.
- `demo_memory`: 256-byte bounded backing store for the eight full-address blocks listed in the hardware guide.
- `demo_monitor`: response/protocol checks, transfer counts and timing measurements.
- `demo_top`: reset synchronization, trigger gating and demo integration. Observation outputs must connect internally to board instrumentation rather than arbitrary physical pins.

## CPU contract

All transactions share the rising-edge clock. Capture address, direction and write data together on a new CS rising edge while idle. A four-clock CS assertion accepts one request. Requests asserted while busy are not queued. RDY is high while idle, low after acceptance, and returns high only after the requested byte is returned or written.

Reset invalidates all lines, clears dirty/control state and samples CS so releasing reset with CS held high cannot replay an old request. It discards dirty contents; it is a benchmark reset, not a flush operation.

## Memory sequencing

A hit requires a valid indexed line with a matching tag. A read uses a setup state, then captures synchronous RAM output on a later edge. A write commits the byte on the RAM edge before RDY returns high.

A clean miss reads offsets 0 through 31 from the requested block and writes each byte into cache RAM. A dirty miss first writes all 32 victim bytes to `stored_tag & index & offset`; refill uses `requested_tag & index & offset`. Metadata becomes valid/clean only after the final refill byte has committed. The saved CPU operation is then replayed; a replayed write marks the line dirty.

Each main-memory address/direction/write-data setup precedes a one-clock MEMSTRB. Read data must be valid at the ending strobe edge. There is no variable-latency memory-ready handshake in the course interface.

The explicit states separate RAM setup/capture, memory setup/strobe, byte completion and final request completion. Write-back takes five clocks per byte and refill four. No byte-counter completion check precedes the offset-31 transfer.

## Observation

The core exports acceptance, lookup, completion and replacement events, state/case, byte offset, valid/dirty bits, and RAM setup/capture observations. The RAM observations are one-state pulses; setup-to-capture is one clock. The demo measures intervals from those observations and maintains sticky protocol/response/overflow faults.

The default demo executes eight compatibility vectors. Extended mode executes sixteen vectors, including rereads of evicted values, high-address independence, offset 31 and index 7. Reset the demo before another run.

## Verification boundary

Portable VHDL-93 is checked with GHDL. Actual Spartan-3E BlockRAM mapping, resource fit, timing closure, pin assignments and ChipScope captures require ISE and the physical board. The synthesis recipe accepts a real part and UCF; a board wrapper must connect the observation signals to instrumentation before a usable bitstream is built.
