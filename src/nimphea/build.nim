## Build configuration for nimphea projects
##
## This module injects everything a project needs to compile and link against
## libDaisy using only `{.passC.}`/`{.passL.}` pragmas, with all paths derived
## from this module's own location (the nimphea checkout). Projects never need
## to know where nimphea lives: their package manager (atlas via `nim.cfg`,
## nimble, or a manual `--path`) supplies the import path, and this module
## supplies the C++ include paths, preprocessor defines, and link flags.
##
## ARM-specific flags are gated on `defined(arm)` (set by `--cpu:arm` in the
## project configuration), so host-side compilation of nimphea code never
## receives cross-compile flags.
##
## Optional features are enabled per project with the usual defines:
##   -d:useCMSIS       link the CMSIS-DSP static library
##   -d:useFatFsLFN    link the FatFs long-filename conversion library
##   -d:bootQspi       link with the QSPI boot linker script (BOOT_APP)
##   -d:bootSram       link with the SRAM boot linker script (BOOT_APP)
##   -d:debug          debug build flags (-g, -DDEBUG=1)

import std/os

const nimpheaRoot = currentSourcePath().parentDir.parentDir.parentDir

# ------------------------------------------------------------------------------
# libDaisy C++ include paths (resolved from this module's location)
# ------------------------------------------------------------------------------
{.passC: "-I" & nimpheaRoot / "libDaisy/src".}
{.passC: "-I" & nimpheaRoot / "libDaisy".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Drivers/STM32H7xx_HAL_Driver/Inc".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Drivers/STM32H7xx_HAL_Driver/Inc/Legacy".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Drivers/CMSIS_5/CMSIS/Core/Include".}
{.passC: "-I" & nimpheaRoot / "libDaisy/src/sys".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Drivers/CMSIS-Device/ST/STM32H7xx/Include".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Middlewares/ST/STM32_USB_Host_Library/Core/Inc".}
{.passC: "-I" & nimpheaRoot / "libDaisy/src/usbh".}
{.passC: "-I" & nimpheaRoot / "libDaisy/src/usbd".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Middlewares/Third_Party/FatFs/src".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Middlewares/ST/STM32_USB_Device_Library/Core/Inc".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Middlewares/Patched/ST/STM32_USB_Device_Library/Class/CDC/Inc".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Middlewares/ST/STM32_USB_Host_Library/Class/MSC/Inc".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Middlewares/ST/STM32_USB_Host_Library/Class/MIDI/Inc".}

# CMSIS-DSP include paths (headers always available, library is opt-in)
{.passC: "-I" & nimpheaRoot / "libDaisy/Drivers/CMSIS-DSP/Include".}
{.passC: "-I" & nimpheaRoot / "libDaisy/Drivers/CMSIS_5/CMSIS/DSP/Include".}

# Library-owned compiled C++ helpers (e.g. ui_init_helper) live next to the
# modules that {.compile.} them
{.passC: "-I" & nimpheaRoot / "src/nimphea".}

# Preprocessor defines from the libDaisy Makefile
{.passC: "-DUSE_HAL_DRIVER".}
{.passC: "-DSTM32H750xx".}
{.passC: "-DHSE_VALUE=16000000".}
{.passC: "-DCORE_CM7".}
{.passC: "-DSTM32H750IB".}
{.passC: "-DARM_MATH_CM7".}
{.passC: "-DUSE_FULL_LL_DRIVER".}
{.passC: "-DDATA_IN_D2_SRAM".}
{.passC: "-DFILEIO_ENABLE_FATFS_READER".}

# ------------------------------------------------------------------------------
# ARM target flags — only when the project compiles for --cpu:arm
# ------------------------------------------------------------------------------
when defined(arm):
  # ARM CPU flags (Cortex-M7, FPU double-precision, hard ABI)
  {.passC: "-mcpu=cortex-m7".}
  {.passC: "-mthumb".}
  {.passC: "-mfpu=fpv5-d16".}
  {.passC: "-mfloat-abi=hard".}

  # General compiler flags from the libDaisy Makefile
  {.passC: "-Wall".}
  {.passC: "-Wno-attributes".}
  {.passC: "-Wno-strict-aliasing".}
  {.passC: "-Wno-maybe-uninitialized".}
  {.passC: "-Wno-missing-attributes".}
  {.passC: "-Wno-stringop-overflow".}
  {.passC: "-Wno-register".}
  {.passC: "-fdata-sections".}
  {.passC: "-ffunction-sections".}
  {.passC: "-finline-functions".}
  {.passC: "-fno-exceptions".}
  {.passC: "-fno-rtti".}
  {.passC: "-fno-unwind-tables".}
  {.passC: "-fshort-enums".}
  {.passC: "-std=gnu++14".}

  # Debug vs release defines (the template's default profile declares -d:debug)
  when defined(debug):
    {.passC: "-g -ggdb -DDEBUG=1".}
  else:
    {.passC: "-DNDEBUG=1".}
    {.passC: "-DRELEASE=1".}

  # Linker flags (including the prebuilt libDaisy static library). The arch
  # flags must also be passed at link time so the g++ driver selects the
  # hard-float multilib, matching the compiled objects.
  {.passL: "-mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard".}
  {.passL: "--specs=nano.specs --specs=nosys.specs -lc -lm -lnosys -Wl,--cref".}
  {.passL: "-L" & nimpheaRoot / "libDaisy/build".}
  {.passL: "-ldaisy".}
  # Link hygiene: garbage-collect unused sections, report memory usage, and
  # tolerate the libnosys/daisy symbol overlaps.
  {.passL: "-Wl,--gc-sections".}
  {.passL: "-Wl,--print-memory-usage".}
  {.passL: "-Wl,--allow-multiple-definition".}

  # Boot modes: BOOT_NONE (internal flash) is the default and links the
  # flash linker script explicitly; bootloaded modes compile the startup unit
  # with -DBOOT_APP and link their respective linker scripts.
  {.compile: nimpheaRoot / "libDaisy/core/startup_stm32h750xx.c".}
  when defined(bootQspi):
    {.passC: "-Dqspi_layout -DBOOT_APP".}
    {.passL: "-T" & nimpheaRoot / "libDaisy/core/STM32H750IB_qspi.lds".}
  elif defined(bootSram):
    {.passC: "-Dsram_layout -DBOOT_APP".}
    {.passL: "-T" & nimpheaRoot / "libDaisy/core/STM32H750IB_sram.lds".}
  else:
    {.passC: "-Dflash_layout".}
    {.passL: "-T" & nimpheaRoot / "libDaisy/core/STM32H750IB_flash.lds".}

  # Optional: FatFs LFN support (opt-in via -d:useFatFsLFN)
  when defined(useFatFsLFN):
    {.passL: "-L" & nimpheaRoot / "build".}
    {.passL: "-lfatfs_ccsbcs".}

  # Optional: CMSIS-DSP support (opt-in via -d:useCMSIS)
  when defined(useCMSIS):
    {.passL: "-L" & nimpheaRoot / "build".}
    {.passL: "-lCMSISDSP".}
