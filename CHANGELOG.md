# Changelog

All notable changes to this project will be documented in this file.

## [2.0] - 2026-09-18

### Added
- Typed audio callbacks: real `openArray` parameters
  (`openArray[AudioBuffer]` / `var openArray[AudioBuffer]`, interleaved
  `var openArray[cfloat]`) with dev-build bounds checking (assert-based,
  compiled out at `release`/`danger`).
- `AudioBuffer` channel view type (two-word value type, no allocation on the
  audio path) with `[]` / `[]=` / `len` / `items` / `mitems` accessors;
  `MAX_AUDIO_CHANNELS = 4` matching libDaisy's `GetChannels()` contract.
- `audioChannels[T]` generic channel-count accessor with registration-time
  capture in the shared audio bridge (`src/nimphea/nimphea_audio.nim`, one
  start/change/stop mechanism for all boards).
- `openArray[uint8]` overloads (length-derived, empty no-ops, raw forms kept)
  for QSPI `write` / `writePage` and FatFS `read` / `write`.
- CMSIS-DSP complex interop (`cmsis/complex_interop.nim`): layout-asserted
  `Complex[float32]` views plus typed `arm_cmplx_*` bulk ops
  (`mag`, `magSquared`, `mult`, `multReal`).
- `Cfft[N]` with compile-time-validated sizes (unsupported sizes are compile
  errors).
- Static peripheral handles with compile-time bus safety: `I2cHandle[P]`,
  `SpiHandle[P]`, `UartHandle[P]`, `SaiHandle[P]`, typed PWM/USB/MIDI
  families (a config for the wrong bus is a compile error, not a device hang).
- `StaticPin[Port, N]` with `staticPin` / `staticPinConst` constructors and a
  `rawPin` converter, plus typed Seed D0–D32/A0–A13 and Patch SM pin tables.
- Unit types with explicit constructors: `Hz`, `Milliseconds`, `Seconds`,
  `Baud`, `DutyCycle`, `Db`; `delay` / `delayMs` unified on `Milliseconds`
  across the library, boards, and `per/tim`.
- Vendored `StackString` (`nim-stack-strings`, MIT, pristine) plus
  allocation-free numeric `add` / `set` utils, replacing `FixedStr`.
- `syscalls.nim`: newlib retargets routing defects, asserts and `echo` to the
  debug UART (compiled only with `UsartStdio` declared, on by default in the
  basic template).
- Project scaffolds `templates/basic` and `templates/audio` with task-based
  `config.nims` (`nim make` / `nim bin` / `nim flash` / `nim stlink` /
  `nim clear`); boot mode via `const bootMode`, features via
  `switch("define", ...)` (`useCMSIS`, `useFatFsLFN`, `bootQspi`, `bootSram`).
- Standalone `scripts/*.nims` for every operation (`init_libdaisy`, `test`,
  `check_examples`, `check_duplicate_types`, `docs`, `clear`); duplicate-type
  CI guard (`tools/check_duplicate_types.nim`).
- `MIGRATION.md` with per-proc old→new mappings.
- Restored CMSIS-DSP `arm_float_to_q7` / `arm_q7_to_float` bindings with
  `toQ7` / `toFloat(q7)` overloads.
- libDaisy v8.1.0 (submodule branch pinned in `.gitmodules`).

### Changed
- **Breaking:** single-tier bindings — every C++ method is bound exactly once
  under its snake_case Nim name; ~81 pure-rename wrappers deleted.
- **Breaking:** one canonical C++-backed type per entity in
  `nimphea_core_types.nim`; modules re-export instead of re-declaring.
- **Breaking:** audio callback signature changed; the standalone `size`
  parameter is removed (`blockSize = output[0].len`,
  `numChannels = output.len`; interleaved `len` is the full interleaved
  length, 2x block size for stereo).
- **Breaking:** `FixedStr` replaced by `StackString`; tests moved from
  `unittest2` to `std/unittest` (drops the `typestates` chain).
- **Breaking:** package-manager-free builds — projects resolve nimphea via
  `NIMPHEA` env, sibling checkout, or optional `nimble path` fallback;
  `nimphea.nimble` is metadata-only.
- **Breaking:** generic `WavPlayer[N]` / `WavWriter[N]` /
  `ShiftRegister4021[ND, NP]` replace the copy-pasted size families; shared
  OLED draw primitives in `hid/disp/draw2d.nim`.
- `nimphea_macros.nim` (`useNimpheaNamespace` / `useNimpheaModules` /
  `useCmsisModules`) deleted — every binding carries its own qualified C++
  name and `header:` pragma; all `{.push importcpp.}` regions lifted.
- Docs refreshed to the task workflow (`nim make` / `nim flash`,
  `bootMode`); `init_libdaisy.nims` is re-runnable with an ARM toolchain
  precheck.
- PWM `Hz` / `DutyCycle`, UART `Baud` + `setBaudrate` typed surfaces.

### Fixed
- Wrong enum ordinals corrected to match libDaisy (`SwitchType`,
  `GpioPull`, `GPIOPort.PORTX = 11`).
- `init_libdaisy.nims` crashed on re-run when `build/` already existed.
- Dropped q7 conversion bindings restored (v1.1.0 parity).
- Corrected the `exp2f` performance note (no single-instruction claim).

## [1.1.0] - 2026-03-03

### Added
- CMSIS-DSP support: Comprehensive wrapper for ARM optimized math functions.
- Integrated CMSIS-DSP modules: `cmsis`, `cmsis_types`, `dsp_basic`, `dsp_filtering`, `dsp_transforms`, `dsp_statistics`, `dsp_fastmath`, `dsp_matrix`, `dsp_complex`, `dsp_support`, `dsp_controller`, `dsp_fixed`, `dsp_interpolation`.
- Automated build system support for CMSIS-DSP source bundles.
- Project templates for Basic and Audio applications.
- Handwritten documentation guides for installation and getting started.

### Changed
- Migrated all `unsafeAddr` usage to the modern `addr` operator.
- Restructured repository for better Nimble package compatibility.
- Moved all core modules under the `nimphea/` namespace prefix.
- Updated `nimphea.nimble` with post-install hooks to automatically build `libDaisy`.
- Relocated examples to a separate directory structure in preparation for external hosting.

### Fixed
- Improved exception safety by enforcing `{.raises: [].}` patterns in documentation.
- Fixed panic handler to be more idiomatic and reliable on bare metal.
- Fixed memory safety in CMSIS DSP wrappers: implemented custom `=copy`/`=sink` operators for `Matrix`, `FirFilter`, and `BiquadFilter` to rebind internal CMSIS pointers after object copies/moves, preventing dangling pointer bugs.
- Fixed incorrect `importcpp` this-pointer bindings in `per/uart.nim` (`init`, `getConfig`, `checkError`).
- Added `{.raises: [].}` to all real-time audio callback wrappers across core and 7 board modules for embedded safety.

## [1.0.0] - 2026-02-15
- Initial release of Nimphea.
- Core libDaisy wrappers for Daisy Seed, Pod, Patch, Field, Petal, Versio, and Legio.
- Peripheral support for ADC, DAC, GPIO, I2C, SPI, UART, and PWM.
- HID support for switches, encoders, and LEDs.
- Basic audio processing infrastructure.
