# AGENTS.md - Guide for AI Coding Agents

**Nimphea** v2.0.0 - Nim wrapper for libDaisy embedded audio platform (ARM Cortex-M7 / STM32H750).

## Build & Test Commands

The package is nimble-independent: all commands are standalone NimScripts
under `scripts/` (run with `nim e`). Projects locate nimphea via the `NIMPHEA`
environment variable, a sibling `../nimphea` checkout, or `nimble path nimphea`
(optional fallback) — see `templates/basic/config.nims` for the reference
resolution logic.

```bash
# One-time setup (clone submodules, build libDaisy + fatfs/CMSIS-DSP libs)
nim e scripts/init_libdaisy.nims

# Build/flash an example (from inside its directory in nimphea-examples/)
NIMPHEA=/path/to/nimphea
nim e make.nims              # Build for ARM (outputs: build/*.elf, build/*.bin)
nim e flash.nims             # Via DFU bootloader (USB)
nim e stlink.nims            # Via ST-Link/OpenOCD (faster)

# Testing (host, no ARM link)
nim e scripts/test.nims      # Unit tests for pure-Nim modules (host)
nim e scripts/check_examples.nims  # Syntax-check the examples in nimphea-examples/
nim check src/nimphea.nim    # Fast host syntax check of the library entry module

# Other
nim e scripts/clear.nims     # Remove build/ directory and artifacts
nim e scripts/docs.nims      # Generate API docs → docs/api/*.html
```

**Requirements**: Nim ≥2.0.0, arm-none-eabi-gcc, libDaisy (submodule). CI runs `nim check src/nimphea.nim`, the duplicate-type checker (`tools/check_duplicate_types.nim`), and `nim e scripts/test.nims`.

## Code Style

### Naming Conventions

```nim
type DaisySeed* = object          # Types: PascalCase*
proc setLed*(x: var T)            # Procs: camelCase*
const SAMPLE_RATE* = 48000        # Constants: UPPER_SNAKE_CASE (or PascalCase consts)
type Mode* = enum INPUT, OUTPUT   # Enums: PascalCase type, values match C++
var ledState = false              # Vars: camelCase (not exported)
```

### Module Structure

```nim
## Module Title - Short description
##
## Detailed description with usage examples.

import std/algorithm                    # Standard imports first
import nimphea                          # Library entry (re-exports macros + core types)
import nimphea/nimphea_core_types       # Canonical C++-backed types (wrapper modules)

useNimpheaNamespace()           # For examples (REQUIRED)
useNimpheaModules(adc)          # For wrappers (after imports!)

type MyType* = object
  field*: cint

proc myProc*() = discard
```

`import nimphea` already re-exports `useNimpheaNamespace`/`useNimpheaModules`, so wrapper modules may simply `import nimphea` and call `useNimpheaModules(...)` directly.

## Single-Tier Binding Convention (MANDATORY)

Every C++ method or free function is bound **exactly once**, under its snake_case Nim name, directly on the `importcpp`/`importc` proc. There is **no separate wrapper layer that re-declares the same call** — those were eliminated in v2.0.0.

```nim
# Bind-once: the importcpp proc IS the public API.
proc start*(adc: var AdcHandle) {.importcpp: "#.Start()", header: "daisy_seed.h".}
proc getFloat*(adc: AdcHandle, channel: uint8): cfloat {.importcpp: "#.GetFloat(@)", header: "daisy_seed.h".}
```

A wrapper/overload is retained ONLY when it adds real value (see *Retained Wrapper Categories* below). If you find yourself writing a proc whose body is just `x.cppMethod(...)` with unchanged arguments, **rename the C++ binding instead** and delete the wrapper.

### Retained Wrapper Categories

Only these wrapper shapes are acceptable (each gets a one-line rationale comment):

- **openArray/len-guard**: wraps a `ptr T + csize_t` binding, passes `addr x[0]`/`len`, returns `SPI_OK`/`I2C_OK` on empty.
- **Prototype conversion**: ergonomic overloads convert Nim `float`/`int` → `cfloat`/`uint8`/`csize_t`, e.g. `set*(ch, dutyCycle: float) {.inline.} = ch.set(dutyCycle.cfloat)` alongside the cfloat raw binding (or `get*(adc, channel: int)` alongside `uint8`).
- **Constructor + config assembly**: builds a config struct, then the constructor/binding (e.g. `initSPI`, `initPwm`, `initSwitch`, `initAnalogControl`, `initAdcHandle`).
- **Register/file convenience**: single calls composed into a common device pattern (`readRegister`, `writeFile`, `mount`).
- **Real logic**: anything that computes something (mode mapping, filtering, file composition, `pressed` active-low inversion).

### C++ Interop Patterns

```nim
# Import C++ type
type
  Pin* {.importcpp: "daisy::Pin", bycopy.} = object

# C++ methods (# = this pointer, @ = all args)
proc init*(this: var DaisySeed) {.importcpp: "#.Init()".}
proc setLed*(this: var DaisySeed, state: bool) {.importcpp: "#.SetLed(#)".}
proc getFloat*(this: AdcHandle, chn: uint8): cfloat {.importcpp: "#.GetFloat(@)".}

# C++ constructors are `newX`
proc newPin*(port: GPIOPort, pin: uint8): Pin
  {.importcpp: "daisy::Pin(@)", constructor, header: "daisy_seed.h".}

# C function (no this-pointer)
proc arm_fir_f32*(S: ptr FirInstanceF32, ...) {.importc, header: "arm_math.h".}

# Type mappings: int→cint, float→cfloat, uint16→uint16, size_t→csize_t
# T*→ptr T, T&→var T, const T&→T; const C++ methods bind `this: T` BY VALUE
```

### Generic C++ Templates

Use `static int` type params for C++ class templates (the project-proven pattern):

```nim
type
  WavPlayer*[N: static int] {.importcpp: "daisy::WavPlayer<'0>", byref.} = object
  ShiftRegister4021*[ND, NP: static int] {.importcpp: "daisy::ShiftRegister4021<'0, '1>", bycopy.} = object

proc init*[N: static int](player: var WavPlayer[N], ...) {.importcpp: "#.Init(@)".}
```

Convenience aliases (`WavPlayer4K* = WavPlayer[4096]`) may be provided for the sizes examples use.

### Documentation Style

```nim
proc process*(input, output: AudioBuffer, size: int) =
  ## Process audio in real-time callback
  ##
  ## **Parameters:**
  ## - `input` - Input [channel][sample]
  ## - `output` - Output [channel][sample]
  ##
  ## **Example:**
  ## ```nim
  ## for i in 0..<size:
  ##   output[0][i] = input[0][i] * 0.5
  ## ```
```

Bodyless importcpp procs attach their doc comment after the pragma:

```nim
proc start*(adc: var AdcHandle) {.importcpp: "#.Start()", header: "daisy_seed.h".}
  ## Start ADC conversions (must be called before reading values)
```

## Directory Structure

```
src/
├── nimphea.nim               # Public API entry point (re-exports core types,
│                             #   DaisySeed + GPIO + AudioHandle bindings, logging)
└── nimphea/
    ├── nimphea_macros.nim    # Compile-time C++ interop macro system
    ├── nimphea_core_types.nim# SINGLE source of truth for all C++-backed types + audio callback types
    ├── nimphea_audio.nim     # Shared audio-callback bridge (startAudio/changeAudioCallback/stopAudio)
    ├── panicoverride.nim     # Bare-metal panic handler
    ├── boards/               # Per-board wrappers (7 boards: pod, patch, patch_sm,
    │                         #   field, petal, versio, legio) — reuse hid/ + nimphea_audio
    ├── per/                  # Peripheral wrappers (11 modules: adc, dac, i2c, spi,
    │                         #   spi_multislave, uart, pwm, qspi, rng, sdmmc, tim)
    ├── hid/                  # Human interface (switch, switch3, ctrl, led,
    │                         #   rgb_led, midi, usb, logger, parameter, gatein)
    │   └── disp/             # Display (oled_display, graphics_common, draw2d)
    ├── dev/                  # Device drivers (20 drivers: codecs, OLED, IMU,
    │                         #   LED drivers, sensors, shift registers, etc.)
    ├── sys/                  # System modules (dma, sdram, fatfs, system)
    ├── cmsis/                # CMSIS-DSP wrappers (13 modules: dsp_filtering,
    │                         #   dsp_transforms, dsp_matrix, dsp_statistics,
    │                         #   dsp_basic, dsp_fastmath, dsp_complex, etc.)
    ├── ui/                   # UI framework (display, events, menu_builder)
    ├── util/                 # Utilities (oled_fonts)
    ├── stack_strings.nim     # Vendored zero-heap string (nim-stack-strings, MIT —
    │                         #   keep pristine, do not edit)
    ├── nimphea_stack_strings_utils.nim  # Numeric/string add + set for StackString
    └── nimphea_*.nim         # Flat modules: fifo, stack, ringbuffer, color,
                              #   wavplayer, wavwriter, menu, sai, etc.
libDaisy/                     # C++ library (submodule — never modify)
tests/                        # Host-side unit tests (pure-Nim modules only)
tools/check_duplicate_types.nim  # Duplicate-type guard wired into CI
```

**Published companion repos:**
- [nimphea-examples](https://github.com/Brokezawa/nimphea-examples) — 44 example programs
- [nimphea-template-basic](https://github.com/Brokezawa/nimphea-template-basic) — GitHub template for basic projects
- [nimphea-template-audio](https://github.com/Brokezawa/nimphea-template-audio) — GitHub template for audio projects

## Types: Single Source of Truth

All C++-backed types (Pin, GPIOPort, AdcHandle, Switch, SaiHandle, I2C/Spi/Uart families, FatFS family, OLED/NeoPixel transport configs, audio callback types, ...) are defined **exactly once** in `nimphea/nimphea_core_types.nim`. Modules re-export them via `import nimphea` + `export nimphea_core_types` (or `import nimphea/nimphea_core_types` + `export`).

**Rules:**
- Never re-declare a type that already exists in `nimphea_core_types.nim` — import + re-export it.
- Importing any combination of public modules must not produce duplicate/ambiguous identifiers.
- Enum ordinals must match libDaisy exactly (e.g. `GpioPull = {PULL_NOPULL=0, PULL_UP=1, PULL_DOWN=2}`, `SwitchType = {TYPE_TOGGLE=0, TYPE_MOMENTARY=1}`, `GPIOPort.PORTX = 11`). Verify against `libDaisy/src/`.

## Audio Callback Bridge

Do NOT copy per-board audio machinery. The `exportc` wrappers, the global callback pair, and the single documented `reinterpret_cast` emit live in `nimphea/nimphea_audio.nim`, exposed as type-generic `startAudio[T]`/`changeAudioCallback[T]`/`stopAudio[T]`. Boards and `nimphea.nim` import + export `nimphea_audio`; `board.startAudio(cb)` just works. Note: libDaisy's `DaisyPatch` has no interleaving `StartAudio` overload.

## Macro System (CRITICAL)

**Always use macros for C++ headers. NO raw emit!**

```nim
# For examples — includes all typedefs + `using namespace daisy`
import nimphea
useNimpheaNamespace()

# For wrapper modules under src/nimphea/ — selective includes
import nimphea
useNimpheaModules(spi, i2c)

# For CMSIS-DSP modules
useCmsisModules(dsp_filtering)

# WRONG — never do this
{.emit: """#include "per/spi.h"
using namespace daisy;""".}
```

**Raw emit allowed ONLY for:**
1. C++ operators (can't define in Nim)
2. Custom C++ helpers relocated to compiled `.cpp` files via `{.compile.}` (e.g. `ui_init_helper.cpp` for the `std::initializer_list` bridge — never inline emits)
3. Doc examples (code blocks demonstrating interop)

The library core contains no raw `.emit` (the audio bridge and UI helper were converted to opaque `importcpp` bindings and a compiled C++ helper respectively). Generic `importcpp` bindings plus per-binding `header:` pragmas are the preferred idiom; qualify every C++ name with `daisy::`. Do not reintroduce `{#.emit.}` or `reinterpret_cast` — use opaque importcpp types + `cast`.

### Adding New Module

1. Find C++ header in `libDaisy/src/`
2. Add types to `nimphea/nimphea_core_types.nim` (if new C++ types are exposed)
3. Edit `src/nimphea/nimphea_macros.nim`:
   ```nim
   const myTypedefs* = ["MyClass::Result MyResult"]
   # Add to getModuleHeaders() and useNimpheaModules()
   ```
4. Create the wrapper in the right category dir (`per/`, `hid/`, `dev/`, `sys/`, or flat `nimphea_*.nim`) with bind-once snake_case procs
5. Run `nim check src/nimphea/<module>.nim`, then `nim e scripts/test.nims`, then `nim c -r --hints:off --path:src tools/check_duplicate_types.nim`

## Common Pitfalls

```nim
# WRONG: Missing # for this pointer
proc init*(x: var T) {.importcpp: "Init()".}
# CORRECT:
proc init*(x: var T) {.importcpp: "#.Init()".}

# WRONG: Wrapper that just re-names a binding (adds nothing)
proc channel1*(pwm: var PwmHandle): var PwmChannel =
  pwm.Channel1()
# CORRECT: bind the C++ method directly under the public name
proc channel1*(pwm: var PwmHandle): var PwmChannel {.importcpp: "#.Channel1()".}

# WRONG: Not exported, wrong type
proc getValue(): int
# CORRECT:
proc getValue*(): cint

# WRONG: Macro before imports
useNimpheaModules(adc)
import nimphea/per/adc
# CORRECT:
import nimphea/per/adc
useNimpheaModules(adc)

# WRONG: two overloads both defaulted → ambiguous zero-arg call
# CORRECT: leave exactly one defaulted overload per arity (see hid/switch `init`)
```

## Embedded Constraints

- **CPU**: ARM Cortex-M7 @ 400-480MHz
- **RAM**: 512KB SRAM (+ optional 64MB SDRAM)
- **Bare metal**: No OS, no dynamic allocation by default
- **Real-time audio**: ~1ms callbacks (48 samples @ 48kHz)
- **Stack over heap**: Prefer `array` over `seq` in audio callbacks
- **All RT callbacks must have `{.cdecl, raises: [].}`** — prevents Nim exception machinery from crossing C call boundaries on bare metal. Every library `exportc` C→Nim shim is annotated.
- **Any exported `proc` that can be reached from a C callback must be `{.raises: [].}`**
- **Use `assert` for invariants** — no exceptions in embedded paths

### Memory Management

```nim
# GOOD — static allocation
var buffer: array[1024, float32]

# AVOID in callbacks — dynamic allocation
var buffer = newSeq[float32](1024)

# GOOD — pre-allocate outside callback, use inside
var phase = 0.0
proc audioCallback(input, output: AudioBuffer, size: int) {.cdecl, raises: [].} =
  phase += phaseIncrement
```

Hot paths must not allocate: `StackString` numeric appends use stack buffers (`std/formatfloat` round-trip into a 65-char buffer via `nimphea_stack_strings_utils`), the UI event dispatcher uses fixed slots, unique-id hex is formatted into a static buffer. Power-of-2 ring/queues use mask indexing with a compile-time guard (`isPowerOfTwo`).

### CMSIS-DSP Self-Referential Pointer Pattern

`Matrix[R,C]`, `FirFilter[NT,MB]`, and `BiquadFilter` embed a CMSIS instance struct with a `ptr` pointing into the object's own `array` buffer. **Always implement `=copy` and `=sink`** to rebind the pointer to the destination's buffer — default bitwise copy creates dangling pointers.

```nim
proc `=copy`*[NT, MB: static int](dest: var FirFilter[NT, MB], src: FirFilter[NT, MB]) =
  dest.state = src.state
  dest.instance = src.instance
  dest.instance.pState = addr dest.state[0]  # rebind to dest's buffer
```

## Testing Strategy

| Layer | Command | What it covers |
|---|---|---|
| Single module | `nim check --path:src --path:src/nimphea src/nimphea/<module>.nim` | Syntax + import resolution |
| Entry point | `nim check --path:src src/nimphea.nim` | Whole public surface compiles |
| Type uniqueness | `nim e scripts/check_duplicate_types.nims` | No C++-backed type declared twice |
| Pure-Nim units | `nim e scripts/test.nims` | FIFO, Stack, RingBuffer, StackString utils, MappedValue |
| Examples | `nim e scripts/check_examples.nims` | Syntax-checks the 44 examples in nimphea-examples/ |

C++-dependent modules cannot be unit-tested on the host — validate via `nim check`, the duplicate-type checker, and ARM builds (`nim e make.nims` in an example/template project) / hardware flashing.

## Formatting

- **Indentation**: 2 spaces (NO tabs)
- **Line length**: 80-100 chars max
- **Blank lines**: 1 between procs
- **No automated formatter**: Manual (maintain consistency)

## References

- **scripts/*.nims** - Standalone build/test/documentation scripts (run with `nim e`); `nimphea.nimble` holds metadata + thin aliases only
- **templates/basic/** - Self-contained project scaffold (copy it; resolution + ARM flags + build tasks)
- **docs/API_REFERENCE.md** - Complete API reference (updated for v2.0.0)
- **nimphea-examples/** - 44 example programs (in the companion repo)
- **libDaisy docs** - https://electro-smith.github.io/libDaisy
