# Package
version       = "0.1.0"
author        = "Nimphea Contributors"
description   = "Nimphea Example: led_drivers"
license       = "MIT"
srcDir        = "src"
bin           = @["led_drivers"]

# Dependencies
requires "nim >= 2.0.0"
requires "nimphea >= 1.1.0"

# Build configuration
import os, strutils, strformat

task make, "Build for ARM Cortex-M7":
  let nimpheaPath = gorge("nimble path nimphea").strip()
  if nimpheaPath == "":
    echo "Error: nimphea package not found. Run 'nimble install nimphea' first."
    quit(1)
  
  var nimCmd = "nim cpp"
  nimCmd.add(" --cpu:arm --os:standalone --mm:arc --opt:size --exceptions:goto")
  nimCmd.add(" --define:useMalloc --define:noSignalHandler")
  nimCmd.add(" --path:" & nimpheaPath / "src")
  
  # Link with libDaisy
  nimCmd.add(" --passL:-L" & nimpheaPath / "libDaisy/build")
  nimCmd.add(" --passL:-ldaisy")
  
  # ELF and BIN output
  let target = "led_drivers"
  nimCmd.add(" -o:build/" & target & ".elf")
  nimCmd.add(" src/" & target & ".nim")
  
  mkDir("build")
  exec nimCmd
  exec "arm-none-eabi-objcopy -O binary build/" & target & ".elf build/" & target & ".bin"
  exec "arm-none-eabi-size build/" & target & ".elf"

task flash, "Flash via DFU":
  exec "dfu-util -a 0 -s 0x08000000:leave -D build/led_drivers.bin"

task stlink, "Flash via ST-Link":
  exec "openocd -f interface/stlink.cfg -f target/stm32h7x.cfg -c \"program build/led_drivers.elf verify reset exit\""
