# Nimphea v1.1.0 - One-Line Install Fix Plan (Updated)

## Executive Summary

This plan fixes the "one line install" requirement for nimphea v1.1.0 so that `nimble install nimphea` automatically:
1. Installs the package
2. Clones libDaisy with all submodules  
3. Builds libDaisy
4. Makes nimphea ready to use immediately

## Key Updates from Research

### Nimble Package Directory (IMPORTANT)
- **Nimble now stores packages in `$HOME/.nimble/pkgs2`** (changed from `pkgs` in Nim 2.0)
- The `nimble path <package>` command returns the installation path
- No need to hardcode paths - use `nimble path nimphea`

### Panicoverride
- **NO panicoverride in the nimphea library itself**
- panicoverride should ONLY be in user projects (examples, templates)
- The library should not export panic handling

### Auto-Installation
- **Fully automatic** - no opt-in required, no env vars
- Optional: `nimble init_libdaisy` task for rebuilding libDaisy
- `after install` hook must automatically clone and build

## Implementation Plan

### Phase 0: Revert Failed Commits

**Revert these commits first:**
- `3d68156` - blink: compile with --noLinking and link with arm-none-eabi-g++; add example clear task
- `0fd0f07` - nimphea: improve post-install instructions+auto-init opt-in; add toolchain note; simplify example/template build tasks; ensure panicoverride usage

```bash
git revert 3d68156 --no-edit
git revert 0fd0f07 --no-edit
```

### Phase 1: Fix nimphea.nimble

**File:** `/Users/zawa/Projects/nim/nimphea_dev/nimphea/nimphea.nimble`

#### Change 1: Remove panicoverride from srcDir

Current:
```nim
srcDir        = "src"
installDirs   = @["src", "libDaisy"]
```

Change srcDir to NOT include panicoverride:
```nim
srcDir        = "src"
# Don't install panicoverride.nim - it's for user projects only
installDirs   = @["src/nimphea", "libDaisy"]
installFiles  = @["src/nimphea.nim", "src/nimphea_macros.nim"]
```

#### Change 2: Automatic after install hook (no opt-in)

```nim
after install:
  ## Post-install: automatically initialize libDaisy
  ## This makes nimphea ready to use immediately after 'nimble install'
  echo "=== Nimphea Post-Install ==="
  echo "Setting up libDaisy..."
  
  let nimpheaPath = getCurrentDir()
  echo "Nimphea package path: " & nimpheaPath
  
  # Check for required tools
  let hasGit = programExists("git")
  let hasMake = programExists("make")
  
  if not hasGit:
    echo "ERROR: 'git' not found in PATH. Cannot clone libDaisy."
    echo "Please install git and run 'nimble init_libdaisy' manually."
    # Don't quit - installation should succeed even if libDaisy setup fails
  elif not hasMake:
    echo "ERROR: 'make' not found in PATH. Cannot build libDaisy."
    echo "Please install make and run 'nimble init_libdaisy' manually."
  else:
    # Attempt automatic initialization
    try:
      if not dirExists("libDaisy"):
        echo "Cloning libDaisy (recursive)..."
        exec "git clone --recursive https://github.com/electro-smith/libDaisy.git"
      else:
        echo "libDaisy directory found"
        # Check if it's a proper git repo
        if not dirExists(joinPath("libDaisy", ".git")):
          echo "libDaisy exists but is not a git repo. Re-cloning..."
          rmDir("libDaisy")
          exec "git clone --recursive https://github.com/electro-smith/libDaisy.git"
      
      # Ensure submodules are up to date
      withDir "libDaisy":
        echo "Updating libDaisy submodules..."
        exec "git submodule update --init --recursive"
        
        # Build libDaisy if not already built
        if not fileExists("build/libdaisy.a"):
          echo "Building libDaisy (this may take a few minutes)..."
          if not programExists("arm-none-eabi-gcc"):
            echo "WARNING: arm-none-eabi-gcc not found. Build may fail."
            echo "Install ARM toolchain from: https://daisy.audio/tutorials/cpp-dev-env/"
          exec "make"
          echo "✓ libDaisy built successfully"
        else:
          echo "✓ libDaisy already built"
      
      echo ""
      echo "=== Nimphea is ready to use! ==="
      
    except OSError as e:
      let emsg = if e.msg.len > 0: e.msg else: "(no message)"
      echo "ERROR: Automatic libDaisy initialization failed: " & emsg
      echo "Please run 'nimble init_libdaisy' manually in: " & nimpheaPath
```

#### Change 3: Simplified init_libdaisy task

```nim
task init_libdaisy, "Initialize and build libDaisy dependency":
  ## One-time setup: clone and build libDaisy C++ library
  ## Run this to rebuild libDaisy or if automatic setup failed
  
  echo "=== Nimphea: libDaisy Initialization ==="
  echo ""
  
  if not programExists("git"):
    echo "ERROR: 'git' not found in PATH. Install git and retry."
    quit(1)
  
  if not dirExists(libDaisyDir):
    echo "Cloning libDaisy (recursive)..."
    exec "git clone --recursive https://github.com/electro-smith/libDaisy.git"
  else:
    echo "libDaisy directory found"

  echo ""
  echo "Building libDaisy C++ library..."
  echo "This may take several minutes..."
  
  echo "Note: Recommended ARM toolchain: GCC Arm Embedded v10.3-2021.10 or later"
  echo "See: https://daisy.audio/tutorials/cpp-dev-env/"
  
  if not programExists("arm-none-eabi-gcc"):
    echo "WARNING: 'arm-none-eabi-gcc' not found in PATH. Build may fail."
  
  withDir libDaisyDir:
    exec "git submodule update --init --recursive"
    exec "make"  # Always rebuild when explicitly requested
  
  echo ""
  echo "✓ libDaisy initialization complete!"
```

### Phase 2: Fix blink.nimble

**File:** `/Users/zawa/Projects/nim/nimphea_dev/nimphea/nimphea-examples/examples/blink/blink.nimble`

#### Key Principles:
1. Use `nimble path nimphea` to find the installed package
2. Fix all indentation errors
3. Keep panicoverride in user project (src/panicoverride.nim)
4. Use pkgs2 directory structure

#### Complete Fixed blink.nimble:

```nim
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

# Build configuration
import os, strutils, strformat

proc getNimpheaPath(): string =
  ## Find nimphea package path using nimble path command
  ## Works with both local development and installed packages
  let result = gorge("nimble path nimphea 2>/dev/null").strip()
  if result.len > 0 and dirExists(result):
    return result
  # Fallback for local development
  let localPath = "../../.."
  if dirExists(localPath / "libDaisy"):
    return localPath
  return ""

task make, "Build for ARM Cortex-M7":
  ## Build example for ARM Cortex-M7 Daisy hardware
  
  let pkgPath = getNimpheaPath()
  if pkgPath == "":
    echo "Error: nimphea package not found."
    echo "Run 'nimble install nimphea' first."
    quit(1)
  
  echo "Using nimphea path: " & pkgPath
  
  # Verify libDaisy is built
  if not fileExists(pkgPath / "libDaisy/build/libdaisy.a"):
    echo "Error: libDaisy not built. Run 'nimble init_libdaisy' in nimphea package."
    quit(1)
  
  # Setup build directories
  let nimcacheDir = "build/nimcache"
  mkDir("build")
  mkDir(nimcacheDir)
  
  # Compile Nim to object files only (no linking)
  var nimCompile = "nim cpp --noLinking:on --nimcache:" & nimcacheDir
  nimCompile.add(" --cc:gcc")
  nimCompile.add(" --gcc.exe:arm-none-eabi-gcc")
  nimCompile.add(" --gcc.cpp.exe:arm-none-eabi-g++")
  nimCompile.add(" --cpu:arm --os:standalone --mm:arc --opt:size --exceptions:goto")
  nimCompile.add(" --define:useMalloc --define:noSignalHandler")
  nimCompile.add(" --path:src")
  nimCompile.add(" --path:" & pkgPath / "src")
  
  # ARM CPU flags
  nimCompile.add(" --passC:-mcpu=cortex-m7")
  nimCompile.add(" --passC:-mthumb")
  nimCompile.add(" --passC:-mfpu=fpv5-d16")
  nimCompile.add(" --passC:-mfloat-abi=hard")
  
  # Add include paths
  let libRoot = pkgPath / "libDaisy"
  nimCompile.add(" --passC:-I\"" & libRoot / "src\")")
  nimCompile.add(" --passC:-I\"" & libRoot & "\"")
  nimCompile.add(" --passC:-I\"" & libRoot / "Drivers/STM32H7xx_HAL_Driver/Inc\")")
  nimCompile.add(" --passC:-I\"" & libRoot / "Drivers/CMSIS_5/CMSIS/Core/Include\")")
  nimCompile.add(" --passC:-I\"" & libRoot / "src/sys\")")
  nimCompile.add(" --passC:-I\"" & libRoot / "Drivers/CMSIS-Device/ST/STM32H7xx/Include\")")
  nimCompile.add(" --passC:-I\"" & libRoot / "Middlewares/ST/STM32_USB_Host_Library/Core/Inc\")")
  nimCompile.add(" --passC:-I\"" & libRoot / "src/usbh\")")
  nimCompile.add(" --passC:-I\"" & libRoot / "Middlewares/Third_Party/FatFs/src\")")
  
  nimCompile.add(" --passC:-DSTM32H750xx")
  nimCompile.add(" --passC:-DFILEIO_ENABLE_FATFS_READER")
  
  nimCompile.add(" src/blink.nim")
  
  echo "Compiling (no link): " & nimCompile
  exec nimCompile
  
  # Collect object files
  var objs: seq[string] = @[]
  for kind, path in walkDir(nimcacheDir):
    if kind == pcFile and path.endsWith(".o"):
      objs.add(path)
  if objs.len == 0:
    echo "Error: no object files found after compile"
    quit(1)
  
  # Link with ARM cross-linker
  let lds = pkgPath / "libDaisy/core/STM32H750IB_flash.lds"
  var linkCmd = "arm-none-eabi-g++ -o build/blink.elf " & join(objs, " ")
  linkCmd.add(" -mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard")
  linkCmd.add(" --specs=nano.specs --specs=nosys.specs")
  linkCmd.add(" -L" & pkgPath / "libDaisy/build -ldaisy")
  if fileExists(lds):
    linkCmd.add(" -T" & lds)
  linkCmd.add(" -Wl,-Map=build/blink.map -Wl,--gc-sections -Wl,--print-memory-usage")
  
  echo "Linking: " & linkCmd
  exec linkCmd
  
  # Generate binary and print size
  exec "arm-none-eabi-objcopy -O binary build/blink.elf build/blink.bin"
  exec "arm-none-eabi-size build/blink.elf"
  
  echo "✓ Build complete: build/blink.bin"

task clear, "Remove build artifacts for example":
  ## Remove all build artifacts (nimble clean cannot be overridden)
  if dirExists("build"):
    rmDir("build")
    echo "✓ Removed build/"

task flash, "Flash via DFU":
  exec "dfu-util -a 0 -s 0x08000000:leave -D build/blink.bin"

task stlink, "Flash via ST-Link":
  exec "openocd -f interface/stlink.cfg -f target/stm32h7x.cfg -c \"program build/blink.elf verify reset exit\""
```

### Phase 3: Update Template nimble Files

Apply same fixes to:
- `/Users/zawa/Projects/nim/nimphea_dev/nimphea/templates/basic/project.nimble`
- `/Users/zawa/Projects/nim/nimphea_dev/nimphea/templates/audio/project.nimble`

### Phase 4: Testing Flow

1. **Revert failed commits:**
   ```bash
   git revert 3d68156 --no-edit
   git revert 0fd0f07 --no-edit
   ```

2. **Uninstall nimphea:**
   ```bash
   nimble uninstall -i nimphea
   ```

3. **Install nimphea:**
   ```bash
   cd /Users/zawa/Projects/nim/nimphea_dev/nimphea
   nimble install
   ```
   
   **Expected:**
   - Package installs to `~/.nimble/pkgs2/nimphea-1.1.0`
   - libDaisy is cloned automatically
   - libDaisy is built automatically
   - Success message shown

4. **Verify installation:**
   ```bash
   nimble path nimphea
   ls ~/.nimble/pkgs2/nimphea-1.1.0/libDaisy/build/libdaisy.a
   ```

5. **Build blink example:**
   ```bash
   cd nimphea-examples/examples/blink
   nimble make
   ```
   
   **Expected:**
   - Finds nimphea via `nimble path`
   - Compiles successfully
   - Creates build/blink.bin

6. **Test clear task:**
   ```bash
   nimble clear
   ls build/  # Should fail (directory removed)
   ```

## Key Changes Summary

### nimphea.nimble
- ✅ Remove opt-in env var - make auto-install mandatory
- ✅ Use `nimble path nimphea` for path detection
- ✅ Don't include panicoverride in library exports
- ✅ Handle pkgs2 directory structure (automatic via nimble path)
- ✅ Add informative error messages

### blink.nimble (and other examples)
- ✅ Use `nimble path nimphea` to find package
- ✅ Fix indentation errors
- ✅ Fix walkDir usage (kind == pcFile)
- ✅ Verify libDaisy is built before compiling
- ✅ Proper clear task
- ✅ Keep panicoverride in user project only

## Success Criteria

1. ✅ `nimble install` from local directory works
2. ✅ libDaisy automatically cloned and built
3. ✅ Package installed to `~/.nimble/pkgs2/`
4. ✅ `nimble make` in blink example produces working binary
5. ✅ `nimble clear` removes all build artifacts
6. ✅ No panicoverride in library exports
7. ✅ Examples have their own panicoverride

## Notes

- The `nimble path` command handles pkgs/pkgs2 automatically
- Panicoverride is project-specific, not library-specific
- Auto-install is now mandatory (no opt-out)
- Users can rebuild libDaisy with `nimble init_libdaisy`
