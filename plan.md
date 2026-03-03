# Static Scan Findings
## Raw `{.emit.}` usage
- `src/nimphea.nim`: StartAudio wrappers emit reinterpret_cast calls.
- `src/nimphea/boards/daisy_pod.nim`, `daisy_patch_sm.nim`, `daisy_petal.nim`,
  `daisy_versio.nim`, `daisy_field.nim`, `daisy_legio.nim`: Start/Change audio
  emits.
- `src/nimphea/nimphea_ui_core.nim`: UI_Init_Helper include-section emit plus
  clear/flush function-pointer emits.
- Comment-only emit examples in `src/nimphea/nimphea_persistent_storage.nim` and
  `src/nimphea/boards/daisy_versio.nim`.

## Unsafe casts / pointer arithmetic
- `src/nimphea.nim` and board callback wrappers: cast raw pointers to
  `AudioBuffer`/`InterleavedAudioBuffer`.
- `src/nimphea/sys/sdram.nim`: pointer arithmetic over SDRAM BSS via
  `cast[uint](start) + sizeof(uint32)`.
- Widespread `cast[ptr ...]` usage in peripherals/dev/cmsis wrappers (by design).

## Allocations in callbacks
- None found in code; only a `newSeq` example in a comment in
  `src/nimphea/nimphea_wavetable_loader.nim`.

## Missing `raises:[]` in real-time callbacks
- `src/nimphea.nim`: `audioCallbackWrapper`/`interleavingCallbackWrapper` are
  `{.cdecl.}` without `raises:[]`.
- Board wrappers in `src/nimphea/boards/` (`daisy_pod`, `daisy_patch_sm`,
  `daisy_petal`, `daisy_versio`, `daisy_field`, `daisy_legio`) use `{.cdecl.}`
  without `raises:[]`.

## `importcpp` patterns missing `#` for `this`
- `src/nimphea/per/uart.nim`: `init`, `getConfig`, `checkError` use
  `importcpp: "Init"/"GetConfig"/"CheckError"` with `this:` params (missing
  `"#."`).
- Other non-`#` importcpp entries appear to be constructors/static/free funcs.

## Direct C++ headers without macros
- `header:` appears across many wrapper files (81 files, e.g.
  `src/nimphea.nim`, `src/nimphea/boards/daisy_*.nim`, `src/nimphea/dev/*.nim`,
  `src/nimphea/cmsis/*.nim`) indicating direct header references; review if
  macros should own header inclusion.
