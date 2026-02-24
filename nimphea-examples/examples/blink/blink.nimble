# Package
version       = "0.1.0"
author        = "Nimphea Contributors"
description   = "Nimphea Example: blink"
license       = "MIT"
srcDir        = "src"
bin           = @["blink"]

# Dependencies
requires "nim >= 2.0.0"
requires "nimphea >= 1.1.0"
# Ensure panicoverride from nimphea is used when building examples installed via nimble

# Build configuration
import os, strutils, strformat

task make, "Build for ARM Cortex-M7":
  ## Simple, cross-platform example build that expects nimphea to be installed
  ## via nimble and libDaisy to be initialized (see nimphea.nimble after-install
  ## instructions). This task works on macOS/Linux/Windows (MSYS/WSL) as long
  ## as the ARM toolchain is available in PATH.

  var pkgPath = ""
  let rawPaths = gorge("nimble path nimphea")
  for ln in rawPaths.splitLines():
    let p = ln.strip()
    if p.len > 0 and dirExists(p):
      pkgPath = p
      break
  if pkgPath == "" and dirExists("../nimphea"):
    var p = "../nimphea"
    normalizePath(p)
    pkgPath = p
  if pkgPath == "":
    echo "Error: nimphea package not found. Run 'nimble install nimphea' and 'nimble init_libdaisy' as described in the nimphea README."
    quit(1)
  echo fmt"Using nimphea path: {pkgPath}"

  # Compile only (generate object files into build/nimcache), then link with
  # the ARM cross-linker. This avoids the host linker attempting to link
  # ARM object files (which fails on macOS/Linux/Windows hosts).
  let nimcacheDir = "build/nimcache"
  mkDir("build")
  mkDir(nimcacheDir)

  var nimCompile = "nim cpp --noLinking:on --nimcache:" & nimcacheDir
  nimCompile.add(" --cc:gcc")
  nimCompile.add(" --gcc.exe:arm-none-eabi-gcc")
  nimCompile.add(" --gcc.cpp.exe:arm-none-eabi-g++")
  nimCompile.add(" --cpu:arm --os:standalone --mm:arc --opt:size --exceptions:goto")
  nimCompile.add(" --define:useMalloc --define:noSignalHandler")
  nimCompile.add(" --path:src")
  nimCompile.add(" --path:" & pkgPath & "/src")

  # Add include paths defensively
  let libRoot = pkgPath & "/libDaisy"
  if dirExists(libRoot & "/src"):
    nimCompile.add(" --passC:-I\"" & libRoot & "/src\"")
  if dirExists(libRoot):
    nimCompile.add(" --passC:-I\"" & libRoot & "\"")
  let halInc = libRoot & "/Drivers/STM32H7xx_HAL_Driver/Inc"
  if dirExists(halInc): nimCompile.add(" --passC:-I\"" & halInc & "\"")
  let cmsisInc = libRoot & "/Drivers/CMSIS_5/CMSIS/Core/Include"
  if dirExists(cmsisInc): nimCompile.add(" --passC:-I\"" & cmsisInc & "\"")
  let sysInc = libRoot & "/src/sys"
  if dirExists(sysInc): nimCompile.add(" --passC:-I\"" & sysInc & "\"")
  let cmsisDevice = libRoot & "/Drivers/CMSIS-Device/ST/STM32H7xx/Include"
  if dirExists(cmsisDevice): nimCompile.add(" --passC:-I\"" & cmsisDevice & "\"")
  let usbHostInc = libRoot & "/Middlewares/ST/STM32_USB_Host_Library/Core/Inc"
  if dirExists(usbHostInc): nimCompile.add(" --passC:-I\"" & usbHostInc & "\"")
  let usbhTarget = libRoot & "/src/usbh"
  if dirExists(usbhTarget): nimCompile.add(" --passC:-I\"" & usbhTarget & "\"")
  let fatFsInc = libRoot & "/Middlewares/Third_Party/FatFs/src"
  if dirExists(fatFsInc): nimCompile.add(" --passC:-I\"" & fatFsInc & "\"")

  nimCompile.add(" --passC:-DSTM32H750xx")
  nimCompile.add(" --passC:-DFILEIO_ENABLE_FATFS_READER")

  nimCompile.add(" src/" & "blink.nim")

  echo "Compiling (no link): " & nimCompile
  exec nimCompile

  # Collect object files produced by Nim in nimcacheDir
  var objs: seq[string] = @[]
  for f in walkDir(nimcacheDir):
    if f.endsWith(".o"):
      objs.add(f)
  if objs.len == 0:
    echo "Error: no object files found after compile; nim cache dir: " & nimcacheDir
    quit(1)

  # Link using the ARM cross-linker
  let linkCmd = "arm-none-eabi-g++ -o build/" & "blink.elf " & join(objs, " ") & " -L" & pkgPath & "/libDaisy/build -ldaisy"
  echo "Linking: " & linkCmd
  exec linkCmd

  # Generate binary and print size
  exec "arm-none-eabi-objcopy -O binary build/blink.elf build/blink.bin"
  exec "arm-none-eabi-size build/blink.elf"

task clear, "Remove build artifacts for example":
  if dirExists("build"):
    try:
      rmDir("build")
    except OSError:
      echo "Warning: could not remove build/ directory"

task flash, "Flash via DFU":
  exec "dfu-util -a 0 -s 0x08000000:leave -D build/blink.bin"

task stlink, "Flash via ST-Link":
  exec "openocd -f interface/stlink.cfg -f target/stm32h7x.cfg -c \"program build/blink.elf verify reset exit\""
