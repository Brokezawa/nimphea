## Self-contained build configuration for a nimphea project
## (ARM Cortex-M7 / Daisy / STM32H750)
##
## Copy this file (together with the src/ and *.nims files) into your project
## root. It needs no package manager: nimphea is located via
##   1. the NIMPHEA environment variable (path to the nimphea checkout), or
##   2. a sibling checkout at ../nimphea, or
##   3. `nimble path nimphea` when installed via a package manager.
##
## Commands (run from the project root):
##   nim e make.nims     Build the ARM binary -> build/<name>.elf/.bin
##   nim e flash.nims    Flash via DFU bootloader (dfu-util)
##   nim e stlink.nims   Flash via ST-Link/OpenOCD
##   nim e clear.nims    Remove build artifacts
##   nim cpp --noLinking src/<name>.nim   Compile without linking (check)

import std/os, std/strutils

# ---------------------------------------------------------------- project settings
# The binary/source name defaults to the project directory name, so
# src/<dirName>.nim must exist. Override `projName` to use a different name.
when not declared(projName):
  let projName = currentSourcePath().parentDir.split(DirSep)[^1]

# Optional extra -d: flags passed to the build, e.g. "-d:useCMSIS -d:bootQspi"
when not declared(customDefines):
  const customDefines = ""

# Optional overrides for flashing (Daisy bootloader defaults)
when not declared(dfuPid):
  const dfuPid = "df11"
when not declared(flashAddressInternal):
  const flashAddressInternal = "0x08000000"
when not declared(flashAddressQspi):
  const flashAddressQspi = "0x90040000"

# ------------------------------------------------------------------- nimphea lookup
proc resolveNimphea(): string =
  let fromEnv = getEnv("NIMPHEA")
  if fromEnv.len > 0 and fileExists(fromEnv / "src" / "nimphea.nim"):
    return fromEnv
  let sibling = currentSourcePath().parentDir.parentDir / "nimphea"
  if fileExists(sibling / "src" / "nimphea.nim"):
    return sibling
  let fromNimble = gorgeEx("nimble path nimphea 2>/dev/null").output.strip()
  if fromNimble.len > 0 and fileExists(fromNimble / "src" / "nimphea.nim"):
    return fromNimble
  echo "Error: could not locate the nimphea package."
  echo "Set NIMPHEA to the nimphea checkout path, or install nimphea via a package manager."
  quit(1)

let nimpheaPath = resolveNimphea()
let cliArgs = commandLineParams()

# NimScript runs (`nim e make.nims` etc.) must NOT receive the ARM compiler
# switches: `--os:standalone` makes the nim e interpreter look for a
# `panicoverride` module and abort. Real compiles always come from
# nim c/cpp/check/r, so those still get the full configuration.
let isNimscriptRun = cliArgs.len > 0 and
  (cliArgs[0] == "e" or cliArgs[^1].endsWith(".nims"))

# ------------------------------------------------------- compiler configuration
# Applied automatically to every nim compilation in this directory tree.
if not isNimscriptRun:
  switch("path", nimpheaPath / "src")
  switch("path", nimpheaPath / "src/nimphea")
  switch("backend", "cpp")
  switch("cpu", "arm")
  switch("os", "standalone")
  switch("cc", "gcc")
  switch("gcc.exe", "arm-none-eabi-gcc")
  switch("gcc.cpp.exe", "arm-none-eabi-g++")
  switch("mm", "arc")
  switch("opt", "size")
  switch("exceptions", "goto")
  switch("define", "useMalloc")
  switch("define", "noSignalHandler")

  # ARM CPU flags (Cortex-M7, FPU double-precision, hard ABI)
  switch("passC", "-mcpu=cortex-m7")
  switch("passC", "-mthumb")
  switch("passC", "-mfpu=fpv5-d16")
  switch("passC", "-mfloat-abi=hard")

  # General compiler flags from the libDaisy Makefile
  switch("passC", "-Wall")
  switch("passC", "-Wno-missing-attributes")
  switch("passC", "-Wno-stringop-overflow")
  switch("passC", "-fdata-sections")
  switch("passC", "-ffunction-sections")
  switch("passC", "-fno-exceptions")
  switch("passC", "-fno-rtti")
  switch("passC", "-fno-unwind-tables")
  switch("passC", "-fshort-enums")
  switch("passC", "-std=gnu++14")

  # libDaisy include paths (relative to the nimphea checkout)
  switch("passC", "-I" & nimpheaPath / "libDaisy/src")
  switch("passC", "-I" & nimpheaPath / "libDaisy")
  switch("passC", "-I" & nimpheaPath / "libDaisy/Drivers/STM32H7xx_HAL_Driver/Inc")
  switch("passC", "-I" & nimpheaPath / "libDaisy/Drivers/CMSIS_5/CMSIS/Core/Include")
  switch("passC", "-I" & nimpheaPath / "libDaisy/src/sys")
  switch("passC", "-I" & nimpheaPath / "libDaisy/Drivers/CMSIS-Device/ST/STM32H7xx/Include")
  switch("passC", "-I" & nimpheaPath / "libDaisy/Middlewares/ST/STM32_USB_Host_Library/Core/Inc")
  switch("passC", "-I" & nimpheaPath / "libDaisy/src/usbh")
  switch("passC", "-I" & nimpheaPath / "libDaisy/src/usbd")
  switch("passC", "-I" & nimpheaPath / "libDaisy/Middlewares/Third_Party/FatFs/src")
  switch("passC", "-I" & nimpheaPath / "libDaisy/Middlewares/ST/STM32_USB_Device_Library/Core/Inc")
  switch("passC", "-I" & nimpheaPath / "libDaisy/Middlewares/ST/STM32_USB_Host_Library/Class/MSC/Inc")

  # CMSIS-DSP include paths
  switch("passC", "-I" & nimpheaPath / "libDaisy/Drivers/CMSIS-DSP/Include")
  switch("passC", "-I" & nimpheaPath / "libDaisy/Drivers/CMSIS_5/CMSIS/DSP/Include")

  # Preprocessor defines from the libDaisy Makefile
  switch("passC", "-DUSE_HAL_DRIVER")
  switch("passC", "-DSTM32H750xx")
  switch("passC", "-DHSE_VALUE=16000000")
  switch("passC", "-DCORE_CM7")
  switch("passC", "-DSTM32H750IB")
  switch("passC", "-DARM_MATH_CM7")
  switch("passC", "-DUSE_FULL_LL_DRIVER")
  switch("passC", "-DFILEIO_ENABLE_FATFS_READER")

  # Linker flags
  switch("passL", "-lc")
  switch("passL", "-lm")
  switch("passL", "-lnosys")
  switch("passL", "-Wl,--cref")

  # Boot modes: BOOT_NONE (internal flash) is the default.
  #   -d:bootQspi / -d:bootSram route the app through the bootloader (QSPI).
  when defined(bootQspi):
    switch("passC", "-DBOOT_APP")
    switch("passL", "-T" & nimpheaPath / "libDaisy/core/STM32H750IB_qspi.lds")
  elif defined(bootSram):
    switch("passC", "-DBOOT_APP")
    switch("passL", "-T" & nimpheaPath / "libDaisy/core/STM32H750IB_sram.lds")

  # Optional: debug build (opt-in via -d:debug)
  when defined(debug):
    switch("opt", "none")
    switch("passC", "-g")
    switch("passC", "-ggdb")
    switch("passC", "-DDEBUG")

  # Optional: FatFs LFN support (opt-in via -d:useFatFsLFN)
  when defined(useFatFsLFN):
    switch("passL", "-L" & nimpheaPath / "build -lfatfs_ccsbcs")

  # Optional: CMSIS-DSP support (opt-in via -d:useCMSIS)
  when defined(useCMSIS):
    switch("passL", "-L" & nimpheaPath / "build -lCMSISDSP")

# ------------------------------------------------------------------- task procs
# Used by the task scripts (make.nims, flash.nims, stlink.nims, clear.nims).
# They are only defined here; the *.nims scripts call them once, so a build
# never runs twice.

proc doMake() =
  let buildDir = currentSourcePath().parentDir / "build"
  let cacheDir = buildDir / "nimcache"
  mkDir(buildDir)
  mkDir(cacheDir)

  var nimCmd = "nim cpp --noLinking:on --nimcache:" & quoteShell(cacheDir) & " "
  if customDefines.len > 0:
    nimCmd.add(customDefines & " ")
  nimCmd.add(quoteShell(currentSourcePath().parentDir / "src" / (projName & ".nim")))
  echo nimCmd
  exec nimCmd

  var objs: seq[string] = @[]
  for kind, path in walkDir(cacheDir):
    if kind == pcFile and path.endsWith(".o"):
      objs.add(path)
  if objs.len == 0:
    echo "Error: no object files found after compile"
    quit(1)

  var linkCmd = "arm-none-eabi-g++ -o " & quoteShell(buildDir / (projName & ".elf")) & " " &
                objs.join(" ")
  linkCmd.add(" -mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard")
  linkCmd.add(" --specs=nano.specs --specs=nosys.specs")
  linkCmd.add(" -L" & nimpheaPath / "libDaisy/build -ldaisy")
  if customDefines.contains("useCMSIS"):
    linkCmd.add(" -L" & nimpheaPath / "build -lCMSISDSP")
  if customDefines.contains("useFatFsLFN"):
    linkCmd.add(" -L" & nimpheaPath / "build -lfatfs_ccsbcs")
  if not customDefines.contains("bootSram") and not customDefines.contains("bootQspi"):
    let lds = nimpheaPath / "libDaisy/core/STM32H750IB_flash.lds"
    if fileExists(lds):
      linkCmd.add(" -T" & lds)
  linkCmd.add(" -Wl,-Map=" & quoteShell(buildDir / (projName & ".map")))
  linkCmd.add(" -Wl,--gc-sections -Wl,--print-memory-usage -Wl,--allow-multiple-definition")
  echo linkCmd
  exec linkCmd

  exec "arm-none-eabi-objcopy -O binary " & quoteShell(buildDir / (projName & ".elf")) &
       " " & quoteShell(buildDir / (projName & ".bin"))
  exec "arm-none-eabi-size " & quoteShell(buildDir / (projName & ".elf"))
  echo "Build complete: " & buildDir / (projName & ".bin")

proc doFlash() =
  let flashAddress =
    if customDefines.contains("bootQspi") or customDefines.contains("bootSram"):
      flashAddressQspi
    else:
      flashAddressInternal
  let bin = currentSourcePath().parentDir / "build" / (projName & ".bin")
  exec "dfu-util -a 0 -s " & flashAddress & ":leave -D " & quoteShell(bin) &
       " -d ,0483:" & dfuPid

proc doStlink() =
  if customDefines.contains("bootSram") or customDefines.contains("bootQspi"):
    echo "Error: ST-Link (OpenOCD) cannot be used with bootloaded modes"
    echo "       (BOOT_SRAM/BOOT_QSPI). Use 'nim e flash.nims' instead."
    quit(1)
  let elf = currentSourcePath().parentDir / "build" / (projName & ".elf")
  exec "openocd -f interface/stlink.cfg -f target/stm32h7x.cfg -c \"program " &
       quoteShell(elf) & " verify reset exit\""

proc doClear() =
  let buildDir = currentSourcePath().parentDir / "build"
  if dirExists(buildDir):
    rmDir(buildDir)
    echo "Removed " & buildDir