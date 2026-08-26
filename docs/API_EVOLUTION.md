# API Evolution Proposals

Ideas for the post-v2.0 roadmap, collected while replacing the macro system
with self-contained `importcpp`/`header:` bindings (change
`remove-emit-interop`). Each proposal is deliberately independent: it can be
adopted, split, or dropped on its own. Implementations would land as their
own openspec changes.

Reference projects that inspired these: **ratel** (kotlincraft/ratel —
static peripheral handles, Hz units), **narduino** (d3dave/narduino —
facade module + host/toolchain split), **avr_io** (modwiz/avr_io —
symbol-gated includes, submodule re-exports).

---

## S1. Static `Peripheral`-typed handles

**Motivation.** Today a `SpiConfig`/`I2CConfig`/`UartConfig` carries a
runtime `periph` field; wrong combinations surface only on the device.
Making the peripheral part of the *type* moves those checks to compile time.

**Sketch.**

```nim
type
  SpiHandle[P: static SpiPeripheral] {.importcpp: "daisy::SpiHandle", byref.} = object
  SpiConfig[P: static SpiPeripheral] {.importcpp: "daisy::SpiHandle::Config", bycopy.} = object

proc newSpiHandle*[P: static SpiPeripheral](): SpiHandle[P]
proc newSpiConfig*[P: static SpiPeripheral](): SpiConfig[P]   # periph preset
proc init*[P](spi: var SpiHandle[P], config: SpiConfig[P]): SpiResult
```

`SpiHandle[SPI_1]` and `SpiHandle[SPI_2]` become distinct types; a config
built for SPI_2 cannot be passed to a SPI_1 handle.

**Trade-offs.**
- Breaks every existing example (mechanical `SpiHandle[SPI_1]` churn).
- Importcpp generic plumbing is the project-proven `'0` static pattern
  (WavPlayer/FileTable) — the C++ names stay the same (`daisy::SpiHandle`),
  so no codegen change.
- Configuration helpers that read the peripheral (`configureStandard48k24bit`
  etc.) become per-static-instantiation templates.

**Effort.** Medium (~1 change, example sweep, matrix re-run).

---

## S2. Unit types for frequencies and timings

**Motivation.** Raw `float` parameters invite unit confusion (Hz vs kHz,
seconds vs milliseconds; `delay(1)` next to `pwm.setFreq(1)`). Ratel ships a
proven `Hz`-type rounding.

**Sketch.**

```nim
type Hz* = distinct cfloat
proc hz*(value: cfloat): Hz   # explicit constructor
proc initPwm*(pwm: var PwmHandle, peripheral, frequency: Hz): PwmResult
```

**Trade-offs.**
- `distinct` + explicit constructors keeps numeric ergonomics (comparisons,
  `float(Hz)` conversion) while killing silent unit mixing.
- Ambiguity risk with existing `cfloat` overloads — needs a careful overload
  pass per module.
- Useful mainly at module boundaries (init/config); could be adopted
  incrementally per subsystem.

**Effort.** Small per subsystem, many subsystems.

---

## S3. Facade module + host/toolchain split

**Motivation.** All users currently `import nimphea` and reach everything
through it; board code spreads across `boards/`, `hid/`, `per/`. A facade
improves discoverability, and separating host-visible API from
target-specific bindings enables host-side unit tests of application logic
(no ARM cross-compiler needed for logic tests).

**Sketch.**

```nim
# src/nimphea/api.nim     — facade: re-exports the public surface
# src/nimphea/host/*.nim  — host-friendly modules (pure Nim logic, no importcpp)
# src/nimphea/dev/*.nim   — target bindings (importcpp), chosen via when defined(arm)

import nimphea/api   # one import; api selects dev or host impl per target
```

**Trade-offs.**
- Largest structural change; must not regress the single-source-of-truth
  type rule in `nimphea_core_types.nim`.
- Host stubs must keep exact API parity or logic tests drift from reality.
- Narduino proves the pattern; nimphea's boards layer is a good first
  candidate for the split.

**Effort.** High; staged by subsystem.

---

## S4. Symbol-gated includes with `nimdoc` stubs

**Motivation.** Host-side `nim doc`/`nim check` against the full binding
surface currently needs the C++ headers present (and `--cpu:arm` off).
avr_io's pattern makes docs/analysis work header-free.

**Sketch.**

```nim
when defined(nimdoc) or not defined(arm):
  type DaisySeed* = object   # stub: same public fields, no importcpp
else:
  type DaisySeed* {.importcpp: "daisy::DaisySeed", header: "daisy_seed.h".} = object
```

**Trade-offs.**
- Duplicates type declarations (stub + real) — risk of drift; mitigated by a
  generator or by keeping stubs thin (fields only, no methods).
- Value is mostly developer-ergonomics (docs, IDE, refactors); no runtime
  effect.
- The include-template idea from the initial exploration is subsumed by
  `header:` pragmas (already shipped) — this proposal only adds the
  header-free doc path.

**Effort.** Low to medium (mechanical, but wide surface).

---

## Ordering and dependencies

Suggested sequence: S4 (cheap, immediate DX win) → S1 (compile-time safety
per subsystem) → S2 (unit hygiene while S1 churns signatures) → S3 (facade
+ host split, strongest but most invasive; builds on the others).

None of these are required by the v2.0 release.