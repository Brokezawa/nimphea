## Project configuration for a Nimphea project
## This file is automatically loaded by the Nim compiler
##
## Build tasks are declared below and run bare with `nim <task>`
## (e.g. `nim make`, `nim flash`, `nim stlink`, `nim clear`), or are
## listed with `nim help`.
##
## Requirements: the Nim compiler and the Daisy Toolchain (which includes the
## ARM GCC toolchain). The nimphea import path is provided by your package
## manager (atlas writes a nim.cfg, nimble has its own mechanism) or with an
## explicit `--path`. Everything else — libDaisy include paths, defines, and
## link flags — comes automatically from nimphea itself via compiler pragmas.

import std/os, std/strutils

# ------------------------------------------------------------------------------
# Configuration — edit this section for YOUR project
# ------------------------------------------------------------------------------

# Binary/source name. Defaults to the project directory name, so
# src/<dirName>.nim must exist. Override to use a different name.
# Project/source name — must match src/<projName>.nim
const projName = "audio"

# Flash configuration — override per project when needed
when not declared(dfuPid):
  const dfuPid = "df11"  # DFU USB Product ID (Daisy bootloader)

when not declared(flashAddressInternal):
  const flashAddressInternal = "0x08000000"  # BOOT_NONE: direct internal flash

when not declared(flashAddressQspi):
  const flashAddressQspi = "0x90040000"  # BOOT_SRAM/BOOT_QSPI: flash via bootloader

# Boot mode and optional features:
#   - boot mode: edit `bootMode` below ("bootSram" or "bootQspi" to boot
#     from SRAM/QSPI flash via the DFU bootloader; "" = BOOT_NONE direct
#     internal flash). The linker script and BOOT_APP define are applied
#     automatically by nimphea; the tasks use the same const.
#   - `switch("define", "useCMSIS")`     # Link CMSIS-DSP accelerated math
#   - `switch("define", "useFatFsLFN")`  # FatFs long filename support

# Boot mode: "" (BOOT_NONE) | "bootSram" | "bootQspi"
const bootMode = ""
if bootMode.len > 0:
  switch("define", bootMode)

# ------------------------------------------------------------------------------
# Base configuration (matches libDaisy's Makefile)
# ------------------------------------------------------------------------------
switch("backend", "cpp")
switch("cpu", "arm")
# `os:any` is Nim's documented target for embedded systems (nimc.md "Nim for
# embedded systems": `--os:any --mm:arc -d:useMalloc`) and is preferred over
# the older `os:standalone`, which also forces a project-local
# `panicoverride` module. The compiler selection uses Nim's documented
# cross-compilation keys (`$cpu.$os.$cc.*`, nimc.md "Cross-compilation").
switch("os", "any")
switch("cc", "gcc")
switch("arm.any.gcc.exe", "arm-none-eabi-gcc")
switch("arm.any.gcc.cpp.exe", "arm-none-eabi-g++")
switch("arm.any.gcc.cpp.linkerexe", "arm-none-eabi-g++")
# Nim's distro config sets `*.options.linker = "-ldl"` for unix hosts, which
# is meaningless for the bare-metal arm-none-eabi link. Per nimc.md, later
# config files overwrite previous settings — blank the keys explicitly.
switch("gcc.options.linker", "")
switch("gcc.cpp.options.linker", "")
switch("arm.any.gcc.options.linker", "")
switch("arm.any.gcc.cpp.options.linker", "")
# Threading is not implemented for os:any (nimc.md); the distro config's
# global `threads:on` must be turned off here.
switch("threads", "off")
switch("mm", "arc")
switch("exceptions", "goto")

# ------------------------------------------------------------------------------
# Default dev profile — gdb/openocd-ready, unoptimized debug build
# ------------------------------------------------------------------------------
# - The default IS a debug build: `debugger:native` (DWARF + line directives
#   for arm-none-eabi-gdb via OpenOCD + ST-Link) and `-d:debug` (nimphea
#   adds -g/-ggdb/-DDEBUG=1). `debuginfo:off` skips the host `dsymutil`
#   step — nimphea's -ggdb already provides the debug info.
# - No optimization: `opt:size` applies to the release profile only.
# - `stackTrace`/`lineTrace` off: tracebacks are replaced by the debugger
#   (crash attach + `bt`) and by serial error messages (see `UsartStdio`).
# - `mm:arc` is fixed: zero allocation cost without heap churn, and the
#   exception machinery rides on it (there is no `exceptions:none` in Nim).
# - Runtime checks stay ON (they are only dropped by declaring `danger`).
switch("define", "debug")
switch("debugger", "native")
# `debugger:native` also sets the debug-info flag, which makes macOS-hosted
# nim run a host `dsymutil` on the ARM ELF (fails). Turn it back off: the
# line directives stay, and DWARF already comes from nimphea's `-ggdb`.
switch("debuginfo", "off")
switch("define", "useMalloc")
switch("define", "noSignalHandler")
switch("stackTrace", "off")
switch("lineTrace", "off")

# ------------------------------------------------------------------------------
# Release profile (opt-in)
# ------------------------------------------------------------------------------
# Build with `nim -d:release make`: release semantics (optimizer on) plus the
# size-optimized build below. Runtime checks remain enabled unless you also
# declare `danger` (see README). `-d:lto`/`-d:strip` are Nim compiler options
# (inert in Nim 2.2.10).
when defined(release):
  switch("opt", "size")

# Boot mode selection (opt-in via -d:bootQspi or -d:bootSram in this file)
# Default: direct flash (no bootloader)
#
# Three boot modes are supported — the linker scripts, BOOT_APP defines and
# optional library links are applied automatically by nimphea:
#
#   1. BOOT_NONE (default): Direct flash to internal flash (0x08000000)
#      - No bootloader required
#      - Fastest startup, full control over memory layout
#      - Best for new projects and development
#      - Use: leave `bootMode` empty (default)
#
#   2. BOOT_SRAM: Application runs from SRAM (0x20000000), loaded from bootloader
#      - Requires a DFU bootloader pre-installed on device
#      - Allows iterative development without re-flashing bootloader
#      - Limited SRAM (512KB) restricts application size
#      - Use: set `bootMode = "bootSram"` in the Configuration section above
#
#   3. BOOT_QSPI: Application stored in QSPI flash (0x90040000)
#      - Requires a DFU bootloader with QSPI support
#      - Provides large code space (8MB QSPI available)
#      - Essential for large applications (e.g., with CMSIS-DSP at 1MB)
#      - Use: set `bootMode = "bootQspi"` in the Configuration section above
#
# Flash commands change based on boot mode:
#   - BOOT_NONE: Use 'nim stlink' (direct flash via ST-Link) OR 'nim flash' (DFU)
#   - BOOT_SRAM: Use 'nim flash' (DFU bootloader required)
#   - BOOT_QSPI: Use 'nim flash' (DFU bootloader required)

# ------------------------------------------------------------------------------
# Tasks — run with `nim <task>`, list with `nim help`
# ------------------------------------------------------------------------------

let projectDir = currentSourcePath().parentDir

# Task-side boot mode (the nimscript VM cannot query switch()ed defines, so
# the tasks use the `bootMode` string const from the Configuration section)
let bootModeName =
  when bootMode == "bootQspi": "BOOT_QSPI"
  elif bootMode == "bootSram": "BOOT_SRAM"
  else: "BOOT_NONE"

task make, "Build for ARM Cortex-M7":
  ## Build project for ARM Cortex-M7 Daisy hardware
  ## Compile/link flags come from this file and from nimphea's own config
  ## (note: `setCommand` lets the compiler finish the build in-process after
  ## this script ends, so the flashable .bin is produced by the `bin` task)

  # Build directory
  let buildDir = projectDir / "build"
  mkDir(buildDir)

  # Native build: the task configures the compiler and hands the build back
  # to it in-process (nims.md "NimScript as a build tool"). The link flags
  # come from nimphea's build module; only the project-specific ones live
  # here (the -Wl,-Map/--gc-sections/--print-memory-usage/--allow-multiple
  # flags are library-owned, in src/nimphea/build.nim).
  switch("out", buildDir / (projName & ".elf"))
  switch("nimcache", buildDir / "nimcache")
  switch("passL", "-Wl,-Map=" & buildDir / (projName & ".map"))
  echo "Building " & projName & " (boot mode: " & bootModeName & ")..."
  setCommand("cpp", projectDir / "src" / (projName & ".nim"))

task bin, "Generate .bin and print size":
  ## Produce build/<name>.bin from the ELF and print the section sizes
  ## (Nim has no binary-format conversion backend; this uses the toolchain
  ## utilities, so it must run after `nim make` — see the `make` task)

  let buildDir = projectDir / "build"
  if not fileExists(buildDir / (projName & ".elf")):
    echo "Error: build/" & projName & ".elf not found — run 'nim make' first."
    quit(1)

  exec "arm-none-eabi-objcopy -O binary " & quoteShellPosix(buildDir / (projName & ".elf")) &
       " " & quoteShellPosix(buildDir / (projName & ".bin"))
  exec "arm-none-eabi-size " & quoteShellPosix(buildDir / (projName & ".elf"))
  echo "Flashable binary: " & buildDir / (projName & ".bin")

task clear, "Remove build artifacts":
  ## Remove all build artifacts
  if dirExists(projectDir / "build"):
    rmDir(projectDir / "build")
    echo "Removed " & projectDir / "build"

task flash, "Flash via DFU":
  ## Flash binary to Daisy via DFU
  ## Automatically detects boot mode and uses appropriate memory address
  ## Supports BOOT_NONE (internal flash) and BOOT_SRAM/BOOT_QSPI (bootloader-managed)

  let flashAddress =
    if bootMode == "bootQspi" or bootMode == "bootSram": flashAddressQspi
    else: flashAddressInternal
  # Produce the flashable .bin first (reuses the `bin` task; errors out
  # with a helpful message when `nim make` hasn't been run yet)
  binTask()
  let bin = projectDir / "build" / (projName & ".bin")
  exec "dfu-util -a 0 -s " & flashAddress & ":leave -D " & quoteShellPosix(bin) &
       " -d ,0483:" & dfuPid

task stlink, "Flash via ST-Link":
  ## Flash ELF to Daisy via OpenOCD and ST-Link debugger
  ## NOTE: Only works with BOOT_NONE mode (direct internal flash)
  ##       Bootloaded modes (BOOT_SRAM/BOOT_QSPI) require DFU flashing

  if bootMode == "bootSram" or bootMode == "bootQspi":
    echo "Error: ST-Link (OpenOCD) cannot be used with bootloaded modes (BOOT_SRAM/BOOT_QSPI)"
    echo "        These modes require DFU flashing. Use 'nim flash' instead."
    quit(1)

  let elf = projectDir / "build" / (projName & ".elf")
  exec "openocd -f interface/stlink.cfg -f target/stm32h7x.cfg -c \"program " &
       quoteShellPosix(elf) & " verify reset exit\""
