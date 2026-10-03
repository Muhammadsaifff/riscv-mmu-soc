# Memory synthesis optimization

This drop-in update targets the long Yosys synthesis time in the supplied run.

## Changes

### `dmem.v`
- Keeps the exact module ports and parameter name.
- Keeps the existing mode encodings:
  - `000`: LW/SW
  - `001`: LHU/SH
  - `101`: LH
  - `010`: LBU/SB
  - `110`: LB
- Keeps byte-addressed, little-endian behavior, including unaligned accesses.
- Keeps the existing `clear_active` reset/clear protocol and its `MEM_BYTES/4` clock duration.
- Replaces the 8192-entry 8-bit memory with a 2048-entry 32-bit word memory.
- Implements byte/halfword/word accesses with byte-lane updates and cross-word handling.
- This substantially reduces address-decode and write-selection duplication during synthesis.

### `config.yaml`
- `SYNTH_HIERARCHY_MODE: deferred_flatten`
  - Prevents the large memory logic from being flattened into the whole SoC during the expensive early optimization passes.
  - The hierarchy is flattened after synthesis, preserving the normal flat physical-design view.
- `SYNTH_SPLITNETS: false`
  - Avoids splitting every multi-bit bus into individual nets during synthesis.

## Intentionally unchanged

No CPU, MMU, TLB, page-table, APB, UART, GPIO, clock, memory size, or top-level interface changes were made.

The generated `runs/` and simulator `work/` directories are intentionally excluded from the clean project archive. Existing source/testbench files are retained.
