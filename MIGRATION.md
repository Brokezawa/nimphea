# Nimphea v2.0.0 Migration Guide

Nimphea 2.0.0 is a **breaking** release. It flattens the old two-layer wrapper
design (raw `importcpp` + redundant Nim re-wrappers) into a single-tier
binding convention: every C++ method is bound **once** under its snake_case
Nim name. Deprecation shims are **not** published — update call sites using the
mapping below (the companion `nimphea-examples` repo is updated in lockstep).

General rules for migrating code:

1. **`cpp*`-prefixed calls** — the `cpp` prefix is gone everywhere. Either the
   method is now a direct binding at the same name (`sw.cppDebounce()` →
   `sw.debounce()`), or the wrapper was kept at its friendly name
   (`initSwitch(...)`, `initEncoder(...)`, `initAnalogControl(...)`) which now
   calls the direct binding internally.
2. **PascalCase calls** (`Init`, `Start`, `GetConfig`, `BlockingTransmit`, ...)
   — renamed to snake_case: `start`, `getConfig`, `blockingTransmit`, ...
3. **`float` getters became `cfloat`** — e.g. `timeHeld`, `getRawFloat`,
   `process`, `value`, `sampleRate`, `now`. Nim auto-widens `cfloat` to
   `float` in arithmetic/comparison, so `x > 10.0` still compiles unchanged.
4. **Raw bindings now exported** — low-level pointer/csize_t overloads (e.g.
   `blockingTransmit(spi, addr buf[0], csize_t(n))`) coexist with the existing
   openArray overloads; overload resolution picks the openArray form for
   arrays.
5. **Types moved to `nimphea/nimphea_core_types`** — importing any module that
   uses a type still brings it in (re-exported); only *re-declaring* a type is
   now a compile error.

## Per-module mappings (representative)

### `nimphea` (entry module)
- `cppInit(hw)` → `hw.init()` (bind directly)
- `cppSetLed(...)` → `setLed(...)`; `cppDelayMs(...)` → `delay(...)`
- `cppGetNow()` → `now()` (returns `cfloat`)
- `cppWrite/cppRead/cppToggle/cppDeInit` (GPIO) → `write/read/toggle/deinit`
- `cppCheckBoardVersion()` → `boardVersion()`
- `startAudio/changeAudioCallback/stopAudio` — unchanged call sites; now
  provided by the shared `nimphea/nimphea_audio` bridge (still reached via
  `import nimphea`).

### `per/adc`
- `InitSingle/InitMux/Start/Stop/Get/GetPtr/GetFloat/GetMux*/...` →
  `initSingle/initMux/start/stop/get/getPtr/getFloat/getMux*...`
- `newAdcChannelConfig`, `newAdcHandle`, `initAdcHandle(configs, ...)` unchanged.

### `per/pwm`
- `cppInit(pwm, TIM_3, freq)` → `initPwm(TIM_3, freq)` (returns the handle)
- `channel1..4`, `setPrescaler`, `setPeriod`, `setRaw`, `deinit` — same names,
  now direct bindings (call identical).
- `channel.init(D13())` / `channel.init()` unchanged; `set(x: float)` unchanged.

### `per/rng`
- `rngGetValue/rngGetFloat/rngIsReady` — **removed**; use
  `randomGetValue()/randomGetFloat()/randomIsReady()`.

### `per/spi`, `per/i2c`, `per/uart`
- `BlockingTransmit/BlockingReceive/BlockingTransmitAndReceive` →
  `blockingTransmit/blockingReceive/blockingTransmitAndReceive`
- `DmaTransmit/DmaReceive/DmaTransmitAndReceive` (raw) →
  `dmaTransmit/dmaReceive/dmaTransmitAndReceive`; openArray wrappers keep the
  same names.
- I2C: `Init/GetConfig` → `init/getConfig`; `TransmitDma/ReceiveDma` wrappers
  renamed to `dmaTransmit/dmaReceive` (openArray overloads).
- UART: nothing changed beyond unification of call names.
- `SPI_MODE_*` consts removed (use `mode: int` in `initSPI`); `I2C_ADDR_*`
  consts removed (pass addresses literally).

### `per/sdmmc`, `sys/fatfs`
- `sdmmc.Init(...)` → `sdmmc.init(...)`
- `fatfs.Init → init`, `DeInit → deinit`, `Initialized → isInitialized`,
  `GetConfig → getConfig`, `GetSDPath → getSDPath`, `GetUSBPath → getUSBPath`,
  `GetSDFileSystem → getSDFileSystem`, `GetUSBFileSystem → getUSBFileSystem`
- `deleteFile/renameFile/createDirectory` — removed; use
  `f_unlink/f_rename/f_mkdir` (exported by `sys/fatfs`).
- `getSdramAddress()/getSdramSize()` — removed; use consts
  `SDRAM_BASE_ADDRESS`/`SDRAM_SIZE`.

### `sys/dma`, `sys/system`, `per/tim`, `per/qspi`
- `dmaInit/dmaDeInit` — removed; use `dsy_dma_init/dsy_dma_deinit`.
- `qspi.deInit` → `qspi.deinit`; `tim.deInit` → `deinit` (all board/system
  `deInit` → `deinit`).
- qspi alignment helpers/consts unchanged; `QSPI_BLOCK_32K/64K_SIZE` and
  `QSPI_MEMORY_MAPPED_BASE` removed.

### `hid/ctrl`, `hid/switch`
- Switch methods are now owned by `hid/switch` (also re-exported by
  `hid/ctrl`): `sw.init(...)`, `sw.debounce()`, `sw.pressed()`,
  `sw.risingEdge()`, `sw.fallingEdge()`, `sw.released()`, `sw.rawState()`,
  `sw.timeHeldMs()`.
- `button.update()` (ctrl) → `button.debounce()`.
- `timeHeld(ms)` on switches/encoders — replaced by `timeHeldMs` (switch) /
  `timeHeld` (encoder, in ctrl). Encoder `increment` returns `int32`.
- `initSwitch/initEncoder/initAnalogControl/initBipolarCv/initAdc` unchanged.

### `hid/midi`
- `midi.Init(...)` → `init(...)`; `listen/hasEvents/popEvent/sendMessage`
  unchanged; `initMidi` alias removed (use `initMidiUsb`); event parsers take
  `MidiEvent` by value.

### `dev/*`
- `max11300`: fake `MAX11300[N]` generic → concrete `MAX11300`; methods
  unchanged in name; `init` takes `(config, dmaBuffer)` or `(config)`.
- `sr595`: `cppInit/cppSet/cppWrite` → `init/set/write`.
- `sr4021`: `cppInit/cppUpdate/cppState/cppGetConfig` →
  `init/update/state/getConfig` (generic `[ND, NP]` preserved).
- `neotrellis`: `initNeoTrellis*Config` → `newNeoTrellis*Config`; pixel methods
  come from `dev/neopixel`.
- `dps310`/`icm20948`: constructors `initX` → `newX`; methods unchanged,
  now transport-generic (same names for I2C and SPI variants).
- `neopixel`: `defaultConfig` removed (C++ constructor defaults apply);
  `getPixelColor/numPixels` take the device by value.
- OLED drivers: constructors `initX` → `newX`; `width/height/update` remain
  direct bindings.

### Flat modules
- `WavPlayer`/`WavWriter`: now generic `[N: static int]`. Use aliases
  `WavPlayer4K/8K/16K` (= `WavPlayer[4096/8192/16384]`) and
  `WavWriter16K/32K/64K` (= `WavWriter[16384/32768/65536]`) or explicit sizes.
  `createConfig[32768](...)` requires the explicit size.
- `nimphea_shift_register`: same 12 friendly aliases; `pressed(sr, index)`
  unchanged.
- `sai`: `startDma(n: int)` still works; `StartDma`/PascalCase names removed.
- `sys/sdram`: see sdmmc/fatfs above.

## Removed placeholders (had no working behavior)

`neopixel.defaultConfig`, `leddriver.txCpltCallback`,
`leddriver.fieldLedDriverDmaCallback`, `ui.display.drawCenteredText /
drawProgressBar / measureTime`, `WavWriterResult`, `WavWriterBufferState`,
q7 DSP bindings (`arm_float_to_q7`, `arm_q7_to_float`), `CmsisBuffer*`
typedefs, `GRAYSCALE_*` consts.

## Behavior fixes included

- `SwitchType.TYPE_LATCHING` removed; `SwitchType` ordinals now match libDaisy
  (`TYPE_TOGGLE=0, TYPE_MOMENTARY=1`).
- `GpioPull` ordinals fixed (`PULL_NOPULL=0, PULL_UP=1, PULL_DOWN=2`).
- `GPIOPort.PORTX = 11` everywhere (was 255 in some modules).
- `WavWriter.init` no longer crosses `reinterpret_cast` between config sizes.
- Shift register configs use `array` (was `UncheckedArray`) for pins.

## Strings: `FixedStr` → `StackString`

`nimphea_fixedstr` is gone. The zero-heap string is now the vendored
[nim-stack-strings](https://github.com/termermc/nim-stack-strings) `StackString`
(re-exported by `import nimphea`, MIT licensed, `src/nimphea/stack_strings.nim`),
plus numeric formatting utils in `src/nimphea/nimphea_stack_strings_utils.nim`.

`StackString[Size]` holds `Size` usable characters plus a hidden NUL
(buffer is `array[Size + 1, char]`), so capacities match `FixedStr[Size]`.
Unlike FixedStr, overflow **raises by default** — use the non-raising
`try*`/`addTruncate`/`unsafe*` variants or the truncating utils below for
silent-truncation semantics.

| FixedStr (removed) | StackString replacement |
|---|---|
| `var s: FixedStr[N]` | `var s: StackString[N]` — import `nimphea` |
| `s.init()` | omit (default-constructed is empty); or use `ss"..."` literal / `stackStringOfCap(N)` |
| `s.clear()` | `s.unsafeSetLen(0)` (non-raising) or `s.setLen(0)` |
| `s.len()` | `s.len` (same name) |
| `s.capacity()` | `s.capacity` (same name) |
| `s.isEmpty()` | `s.len == 0` |
| `s.isFull()` | `s.len == s.capacity` |
| `s.add(c: char): bool` | `s.tryAdd(c): bool` (non-raising; `add(c)` raises on overflow) |
| `s.add(str: string): int` | `s.addTruncate(str)` (non-raising, appends up to capacity); plain `s.add(str)` returns `void` and raises on overflow |
| `s.add(value: int): int` | `s.add(value)` — utils overload, truncating, returns count appended |
| `s.add(value: float): int` | `s.add(value)` — utils overload, truncating, returns count appended |
| `s.set(str: string): int` | `s.set(str)` — utils overload, replaces content, returns count |
| `s.toCString()` | `s.toCstring` (NUL-safe template; also `s.toOpenArray`) |
| `s[i]` / `s[i] = c` | same operators; keep `i < s.len` (raises `IndexDefect` on out-of-range) |

Migration notes:

- **`add(string)`/`add(char)` now return `void`** — call them as bare
  statements (`s.add("Cutoff: ")`); `discard s.add(...)` is a compile error.
- **Numeric `add` overloads** (`int`/`float`/`float32`) come from
  `nimphea_stack_strings_utils` and are byte-identical to `$` — keep the
  `discard` when the count is unused (`discard s.add(440)`).
- **`$s` allocates a heap string** — on device, print or copy via
  `toCstring` instead (`printLine(s.toCstring())`). The compile-time guards
  `-d:warnOnStackStringDollar` / `-d:fatalOnStackStringDollar` exist.
- New capabilities: `ss"..."` literals, `s == "str"`, iterators
  (`items`/`mitems`/`pairs`), `find`/`contains`, slices → `openArray[char]`,
  `toStackString`/`unsafeToStackString`/`toStackStringTruncate`,
  `toHeapCstring`.

## Build commands: `nimble` → `nim e`

The package no longer depends on nimble. All library commands are standalone
NimScripts under `scripts/` (run `nim e scripts/<name>.nims` from the repo
root); installation performs no libDaisy clone/build (run
`nim e scripts/init_libdaisy.nims` explicitly once). Projects locate nimphea
via the `NIMPHEA` environment variable, a sibling `../nimphea` checkout, or
`nimble path nimphea` — in that order (see `templates/basic/config.nims`).

| Old command | New command |
|---|---|
| `nimble develop` | not needed — resolution via `NIMPHEA` env / sibling checkout; no installation required |
| `nimble init_libdaisy` | `nim e scripts/init_libdaisy.nims` |
| `nimble test` / `nimble test_unit` | `nim e scripts/test.nims` |
| `nimble clear` | `nim e scripts/clear.nims` |
| `nimble docs` | `nim e scripts/docs.nims` |
| `nimble check_examples` | `nim e scripts/check_examples.nims` |
| `nimble check_duplicate_types` | `nim e scripts/check_duplicate_types.nims` |
| `nimble make <example>` (examples repo) | `nim e make.nims` inside the example directory |
| `nimble flash <example>` | `nim e flash.nims` (DFU) / `nim e stlink.nims` (ST-Link) |
| `nimble clear` (examples repo) | `nim e clear.nims` |
| (examples repo, all builds) | `nim e build_all.nims` at the examples root |

## Verification status

Host verification (this repo, no ARM toolchain): `nim check` passes for all
102 modules in `src/`; 133 unit tests pass; the duplicate-C++-type checker
(`tools/check_duplicate_types.nim`) passes. An ARM build of at least one
example (`nimble make examples/audio_demo`) is deferred until a machine with
the ARM toolchain is available. Update `nimphea-examples` (43 examples) per the
rules above before tagging dependent projects.