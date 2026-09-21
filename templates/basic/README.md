# nimphea basic template

Self-contained project scaffold for [nimphea](https://github.com/Brokezawa/nimphea)
(Daisy Seed / STM32H750 / ARM Cortex-M7).

## Requirements

- **Nim 2.0+**
- **Daisy Toolchain** (includes the ARM GCC toolchain)

No package manager required for building: the only thing nimphea needs is the
import path (see Setup), and it configures the compiler itself (libDaisy
include paths, defines, and link flags come from nimphea via compiler
pragmas).

## Layout

```
config.nims         # project configuration + build/flash tasks (the whole build system)
src/basic.nim       # minimal example: blink the built-in LED
```

## Setup

1. Copy this directory into your project root.
2. Provide the nimphea import path with your package manager of choice
   (the template ships no `nim.cfg`; your package manager creates one):
   - **atlas**: `atlas init`/`atlas install` writes a `nim.cfg` with the paths
   - **nimble**: install nimphea via `nimble install nimphea`
   - **manual**: create a `nim.cfg` next to this file with
     `--path:"/path/to/nimphea/src"` (and `--path:".../src/nimphea"`)
3. Build libDaisy once inside the nimphea checkout:
   ```bash
   nim e <nimphea>/scripts/init_libdaisy.nims
   ```
   (libDaisy must be checked out recursively first:
   `git submodule update --init --recursive` — package managers such as
   Atlas skip nested submodules. If an old nimphea fails here with
   `undeclared identifier: 'quoteShell'`, re-run with
   `nim e --skipParentCfg:on`.)

## Usage

```bash
nim make             # build ARM ELF -> build/<name>.elf (native Nim build)
nim bin              # generate the flashable build/<name>.bin + print size
nim flash            # flash via DFU bootloader (dfu-util; auto-runs nim bin)
nim stlink           # flash via ST-Link/OpenOCD
nim make -d:release  # release build (see Build profiles)
nim clear            # remove build/
nim help             # list all tasks
```

The binary/source name defaults to `projName` in `config.nims` (default
`basic`); put your source at `src/<projName>.nim`.

## Build profiles

The default profile is an unoptimized **debug** build ready for
arm-none-eabi-gdb via OpenOCD + ST-Link: `os:any`, `arc`,
`debugger:native` (DWARF + line directives; the host `dsymutil` step is
skipped — nimphea's `-ggdb` already provides the debug info, enabled with
the default `-d:debug`), stack/line traces **off** (the debugger replaces tracebacks), runtime
checks **on**, no optimization (`opt:size` applies to the release profile
only). Measured with the Daisy Toolchain (GCC 10.3.1, blink):

| Profile | Flags | binary size |
|---|---|---|
| default (debug) | `os:any`, `debugger:native`, checks on, no opt | 68.8 KB |
| release | + `-d:release` (`opt:size` is applied by `when defined(release)`) | 67.0 KB |
| release + LTO | + `-d:lto` | 70.5 KB (`-flto` **grows** code at `opt:size` — measured; a size win only for `opt:speed` builds) |

To build a release, pass the define on the command line (the only define
source the config tasks can also react to):

```bash
nim -d:release make   # release semantics + size-optimized build (opt:size)
```

(`-d:lto` and `-d:strip` are Nim compiler options; in Nim 2.2.10 they are
inert — LTO at opt:size also *grew* this binary in measurements.)

Runtime checks stay **on** unless you declare `danger` (not configured by the
template; `--exceptions:none` does not exist in Nim 2.2.10 — the closest
lever, `--panics:on`, saves only ~100 B).

## Serial error reporting (default on)

nim defects, `echo` and C `printf` output are routed to the Seed's debug UART
(USART_1 @ 115200, pins PG14/PG9) by the library's `nimphea/syscalls` module
(newlib `_write`/`_read` retargets, enabled with `enableUsartStdio`). Open a
115200 8N1 serial monitor to see the messages. To opt out, delete the
`switch("define", "UsartStdio")` line from `config.nims` (with the `when
defined(UsartStdio)` wiring in `src/basic.nim` still compiling cleanly).

Debugger workflow: `nim stlink` flashes the ELF via OpenOCD; attach
`arm-none-eabi-gdb build/<name>.elf` with a `target remote :3333` (or
`target extended-remote localhost:3333`) connection to the OpenOCD ST-Link
probe, continue, crash, `bt`. The unoptimized default build keeps breakpoints
and stepping reliable.

## Configuration

Open `config.nims` and edit the **Configuration** section at the top:

- Boot modes: `const bootMode = "bootSram"` / `= "bootQspi"` (BOOT_NONE is
  the default) — the linker script and BOOT_APP define are applied
  automatically by nimphea
- Extra libraries: uncomment `switch("define", "useCMSIS")` or
  `switch("define", "useFatFsLFN")`
- Flash PID/addresses: override `dfuPid`, `flashAddressInternal`,
  `flashAddressQspi`

## Notes

- ST-Link flashing only works for BOOT_NONE; bootloaded modes use `nim flash`.
- Running `nim e <script.nims>` inside this directory is not supported (the
  ARM `--os:any` settings target device builds).