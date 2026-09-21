# scripts/init_libdaisy.nims — one-time setup: obtain and build the libDaisy dependency.
#
# Run with: nim e scripts/init_libdaisy.nims
#
# This script is self-contained: all paths are derived from this file's
# location, so it works from any working directory and needs no package
# manager. It:
#   1. Obtains libDaisy (as a git submodule when in a git checkout, otherwise
#      by cloning v8.1.0 into libDaisy/).
#   2. Builds the C++ library, producing libDaisy/build/libdaisy.a.
#   3. Builds the optional static archives used by some examples:
#      build/libfatfs_ccsbcs.a and build/libCMSISDSP.a.

import std/os, std/strutils

# Shell quoting that survives a contaminated config: `quoteShell` vanishes
# when a parent config.nims retargets to os:any (it is gated on
# defined(windows) or defined(posix)), e.g. running this script from a
# template directory. `hostOS` reflects the machine (not the target), and
# `quoteShellWindows`/`quoteShellPosix` are unconditional, so branch on it.
template quoteHostShell(s: string): string =
  when hostOS == "windows":
    quoteShellWindows(s)
  else:
    quoteShellPosix(s)

const repoRoot = currentSourcePath().parentDir.parentDir
const libDaisyDir = repoRoot / "libDaisy"
const buildDir = repoRoot / "build"
const libDaisyUrl = "https://github.com/electro-smith/libDaisy.git"
const armFlags = "-mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard -Os -ffunction-sections -fdata-sections"

proc fail(msg: string) =
  echo "ERROR: " & msg
  quit(1)

echo "=== Nimphea: libDaisy Initialization ==="
echo ""

# 0. Toolchain precheck (fail fast with a friendly error, not a cryptic make failure)
if findExe("arm-none-eabi-gcc").len == 0:
  fail("arm-none-eabi-gcc not found in PATH. Install the ARM toolchain first " &
       "(see docs/guides/installation.md).")
if findExe("arm-none-eabi-ar").len == 0:
  fail("arm-none-eabi-ar not found in PATH. Install the ARM toolchain first " &
       "(see docs/guides/installation.md).")

# 1. Obtain libDaisy
if not dirExists(libDaisyDir):
  if dirExists(repoRoot / ".git"):
    echo "Initializing git submodules..."
    exec "git submodule update --init --recursive"
  else:
    echo "Cloning libDaisy (not a git checkout, using a direct clone)..."
    exec "git clone --recurse-submodules --branch v8.1.0 " & libDaisyUrl & " " & libDaisyDir
else:
  echo "libDaisy already present at " & libDaisyDir

# 2. Build the C++ library
echo ""
echo "Building libDaisy C++ library (this may take several minutes)..."
withDir libDaisyDir:
  exec "make"

if not fileExists(libDaisyDir / "build" / "libdaisy.a"):
  fail("libDaisy build did not produce " & libDaisyDir / "build" / "libdaisy.a")
echo "✓ libDaisy/build/libdaisy.a"

# 3. Build optional static libraries
echo ""
echo "Building optional static libraries..."
if not dirExists(buildDir):
  mkdir(buildDir)

# libfatfs_ccsbcs.a — FatFs Long Filename support (single C file)
let fatfsInc = "-I" & libDaisyDir / "Middlewares/Third_Party/FatFs/src" &
               " -I" & libDaisyDir / "src/sys" &
               " -I" & libDaisyDir / "src" &
               " -I" & libDaisyDir / "Drivers/STM32H7xx_HAL_Driver/Inc" &
               " -I" & libDaisyDir / "Drivers/CMSIS_5/CMSIS/Core/Include" &
               " -I" & libDaisyDir / "Drivers/CMSIS-Device/ST/STM32H7xx/Include"
let ccsbcs = libDaisyDir / "Middlewares/Third_Party/FatFs/src/option/ccsbcs.c"
if fileExists(ccsbcs):
  exec "arm-none-eabi-gcc " & armFlags & " -DSTM32H750xx -DUSE_HAL_DRIVER -DCORE_CM7 " &
       fatfsInc & " -c " & quoteHostShell(ccsbcs) & " -o " & quoteHostShell(buildDir / "ccsbcs.o")
  exec "arm-none-eabi-ar rcs " & quoteHostShell(buildDir / "libfatfs_ccsbcs.a") & " " &
       quoteHostShell(buildDir / "ccsbcs.o")
  echo "✓ build/libfatfs_ccsbcs.a"
else:
  echo "Warning: " & ccsbcs & " not found; skipping libfatfs_ccsbcs.a"

# libCMSISDSP.a — ARM CMSIS-DSP optimized math library
echo "Building libCMSISDSP.a (this may take a minute)..."
let cmsisSrc = libDaisyDir / "Drivers/CMSIS-DSP/Source"
let cmsisIncs = "-I" & libDaisyDir / "Drivers/CMSIS-DSP/Include" &
                " -I" & libDaisyDir / "Drivers/CMSIS_5/CMSIS/Core/Include" &
                " -I" & libDaisyDir / "Drivers/CMSIS-Device/ST/STM32H7xx/Include"
let cmsisDefs = "-DARM_MATH_CM7 -DARM_MATH_MATRIX_CHECK -DARM_MATH_ROUNDING -DUNALIGNED_SUPPORT_DISABLE"
if dirExists(cmsisSrc):
  if not dirExists(buildDir / "cmsis_objs"):
    mkdir(buildDir / "cmsis_objs")
  let srcDirs = @["BasicMathFunctions", "CommonTables", "ComplexMathFunctions",
                  "ControllerFunctions", "FastMathFunctions", "FilteringFunctions",
                  "MatrixFunctions", "StatisticsFunctions", "SupportFunctions",
                  "TransformFunctions", "InterpolationFunctions"]
  var objs: seq[string] = @[]
  for srcDir in srcDirs:
    let dir = cmsisSrc / srcDir
    if dirExists(dir):
      for kind, path in walkDir(dir):
        if kind == pcFile and path.endsWith(".c"):
          let objName = buildDir / "cmsis_objs" / path.splitFile.name & ".o"
          let (_, exitCode) = gorgeEx("arm-none-eabi-gcc " & armFlags & " " & cmsisDefs &
                                      " " & cmsisIncs & " -c " & path & " -o " & objName)
          if exitCode == 0:
            objs.add(objName)
  if objs.len > 0:
    # Quote each object path: checkouts under directories with spaces must link.
    var quoted: seq[string] = @[]
    for o in objs:
      quoted.add(quoteHostShell(o))
    exec "arm-none-eabi-ar rcs " & buildDir / "libCMSISDSP.a " & quoted.join(" ")
    echo "✓ build/libCMSISDSP.a (" & $objs.len & " objects)"
  else:
    echo "Warning: No CMSIS-DSP objects compiled"
else:
  echo "Warning: " & cmsisSrc & " not found; skipping libCMSISDSP.a"

echo ""
echo "libDaisy initialization complete!"
