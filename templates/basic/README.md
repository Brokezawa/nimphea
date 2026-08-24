# nimphea basic template

Self-contained project scaffold for [nimphea](https://github.com/Brokezawa/nimphea)
(Daisy Seed / STM32H750 / ARM Cortex-M7). No package manager required.

## Layout

```
config.nims         # ARM build flags + nimphea lookup (self-contained)
make.nims           # build the ARM binary
flash.nims          # flash via DFU bootloader
stlink.nims         # flash via ST-Link/OpenOCD
clear.nims          # remove build/
src/basic.nim       # minimal example: blink the built-in LED
src/panicoverride.nim  # bare-metal panic handler
```

## Setup

1. Copy this directory (or just `config.nims`, the `*.nims` files and `src/`)
   into your project.
2. Build `libDaisy` once inside the nimphea checkout:

   ```bash
   nim e <nimphea>/scripts/init_libdaisy.nims
   ```

3. nimphea is located automatically in this order:
   - `NIMPHEA` environment variable (path to the nimphea checkout)
   - a sibling checkout: `../nimphea`
   - `nimble path nimphea` (when installed via a package manager)

## Usage

```bash
nim e make.nims            # build ARM binary -> build/<name>.elf / .bin
nim e flash.nims           # flash via DFU bootloader (dfu-util)
nim e stlink.nims          # flash via ST-Link/OpenOCD
nim e clear.nims           # remove build/
nim cpp --noLinking src/basic.nim   # compile check without linking
```

The binary/source name defaults to the project directory name: for a project
in `myproject/`, put your source at `src/myproject.nim` (or set `projName` in
`config.nims`).

## Options

- `-d:useCMSIS` / `-d:useFatFsLFN` / `-d:debug` / `-d:bootQspi` / `-d:bootSram` —
  add to `customDefines` in `config.nims` (e.g. `const customDefines = "-d:useCMSIS"`).
- Boot modes: BOOT_NONE (default, internal flash), BOOT_SRAM/BOOT_QSPI via the
  bootloader. ST-Link flashing only works for BOOT_NONE.