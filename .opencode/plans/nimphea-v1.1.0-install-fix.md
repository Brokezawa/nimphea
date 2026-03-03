# Nimphea v1.1.0 - One-Line Install Fix Plan

## Executive Summary

This plan fixes the "one line install" requirement for nimphea v1.1.0 so that `nimble install nimphea` automatically:
1. Installs the package
2. Clones libDaisy with all submodules
3. Builds libDaisy
4. Makes nimphea ready to use

## Current Issues

### 1. nimphea.nimble Issues
- `after install` hook is opt-in (requires `NIMPHEA_AUTO_INIT=1`)
- Doesn't automatically initialize libDaisy
- Error messages are warnings instead of failures

### 2. blink.nimble Issues
- Indentation errors (lines 52, 56, 104, 111 have extra leading spaces)
- Path detection is fragile
- Object file collection uses wrong walkDir syntax
- Missing proper panicoverride integration

### 3. Clean/Clear Task Issues
- `nimble clean` in examples doesn't remove all artifacts
- Need to add `clear` task for examples

## Implementation Plan

### Phase 1: Fix nimphea.nimble

**File:** `/Users/zawa/Projects/nim/nimphea_dev/nimphea/nimphea.nimble`

#### Change 1: Add helper procedure for path detection
```nim
proc getNimpheaInstallPath(): string =
  ## Get the path where nimphea is installed
  ## This works both during nimble install and for local development
  let rawPaths = gorge("nimble path nimphea 2>/dev/null || echo ''").strip()
  if rawPaths.len > 0:
    for ln in rawPaths.splitLines():
      let p = ln.strip()
      if p.len > 0 and dirExists(p):
        return p
  # Fallback to current directory (local development)
  return getCurrentDir()
```

#### Change 2: Rewrite `after install` hook
Replace the current opt-in auto-init with automatic initialization:

```nim
after install:
  ## Post-install: automatically initialize libDaisy
  ## This makes nimphea ready to use immediately after 'nimble install'
  echo "=== Nimphea Post-Install ==="
  echo "Setting up libDaisy..."
  
  let nimpheaPath = getCurrentDir()
  echo fmt"Nimphea package path: {nimpheaPath}"
  
  # Check for required tools
  let hasGit = programExists("git")
  let hasMake = programExists("make")
  
  if not hasGit:
    echo "ERROR: 'git' not found in PATH. Cannot clone libDaisy."
    echo "Please install git and run 'nimble init_libdaisy' manually."
  elif not hasMake:
    echo "ERROR: 'make' not found in PATH. Cannot build libDaisy."
    echo "Please install make and run 'nimble init_libdaisy' manually."
  else:
    # Attempt automatic initialization
    try:
      if not dirExists("libDaisy"):
        # Check if we're in a git repo with libDaisy as submodule
        if dirExists(".git") or fileExists(".git"):
          echo "Initializing libDaisy submodule..."
          exec "git submodule update --init --recursive"
        else:
          echo "Cloning libDaisy (recursive)..."
          exec "git clone --recursive https://github.com/electro-smith/libDaisy.git"
      else:
        echo "libDaisy directory found"
        # Check if it's a proper git repo or just a directory
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
      echo "You can now build examples: cd nimphea-examples/examples/blink && nimble make"
      
    except OSError as e:
      let emsg = if e.msg.len > 0: e.msg else: "(no message)"
      echo fmt"ERROR: Automatic libDaisy initialization failed: {emsg}"
      echo "Please run 'nimble init_libdaisy' manually in: {nimpheaPath}"
```

#### Change 3: Improve `init_libdaisy` task
Update to be more robust and informative:

```nim
task init_libdaisy, "Initialize and build libDaisy dependency":
  ## One-time setup: clone and build libDaisy C++ library
  ## Run this manually if automatic initialization failed
  
  echo "=== Nimphea: libDaisy Initialization ==="
  echo ""
  
  # Check for required tools
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
  
  # Recommend toolchain version
  echo "Note: Recommended ARM toolchain: GCC Arm Embedded v10.3-2021.10 or later"
  echo "See: https://daisy.audio/tutorials/cpp-dev-env/"
  
  if not programExists("arm-none-eabi-gcc"):
    echo "WARNING: 'arm-none-eabi-gcc' not found in PATH. Build may fail."
  
  withDir libDaisyDir:
    exec "git submodule update --init --recursive"
    if not fileExists("build/libdaisy.a"):
      exec "make"
    else:
      echo "libDaisy already built (build/libdaisy.a exists)"
  
  echo ""
  echo "✓ libDaisy initialization complete!"
```

### Phase 2: Fix blink.nimble

**File:** `/Users/zawa/Projects/nim/nimphea_dev/nimphea/nimphea-examples/examples/blink/blink.nimble`

#### Change 1: Fix indentation errors
Lines 52, 56, 104, 111 have extra leading spaces. Remove them.

#### Change 2: Fix object file collection
The current code uses `walkDir` incorrectly. Fix it:

```nim
# Collect object files produced by Nim in nimcacheDir
var objs: seq[string] = @[]
for kind, path in walkDir(nimcacheDir):
  if kind == pcFile and path.endsWith(".o"):
    objs.add(path)
if objs.len == 0:
  echo "Error: no object files found after compile; nim cache dir: " & nimcacheDir
  quit(1)
```

#### Change 3: Improve nimphea path detection
Make it more robust:

```nim
proc getNimpheaPath(): string =
  ## Find nimphea package path - checks nimble installation first, then local
  var pkgPath = ""
  
  # Try nimble path first
  let rawPaths = gorge("nimble path nimphea 2>/dev/null || echo ''")
  for ln in rawPaths.splitLines():
    let p = ln.strip()
    if p.len > 0 and dirExists(p):
      pkgPath = p
      break
  
  # Fallback to local relative path
  if pkgPath == "":
    let localPath = "../../../"
    if dirExists(localPath / "libDaisy"):
      pkgPath = localPath
  
  return pkgPath
```

#### Change 4: Complete corrected make task
Here's the full corrected `make` task:

```nim
task make, "Build for ARM Cortex-M7":
  ## Build example for ARM Cortex-M7 Daisy hardware
  
  let pkgPath = getNimpheaPath()
  if pkgPath == "":
    echo "Error: nimphea package not found."
    echo "Run 'nimble install nimphea' first."
    quit(1)
  
  echo fmt"Using nimphea path: {pkgPath}"
  
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
  nimCompile.add(" --path:" & pkgPath & "/src")
  
  # Use nimphea's panicoverride
  nimCompile.add(" --define:use_nimphea_panic")
  
  # ARM CPU flags
  nimCompile.add(" --passC:-mcpu=cortex-m7")
  nimCompile.add(" --passC:-mthumb")
  nimCompile.add(" --passC:-mfpu=fpv5-d16")
  nimCompile.add(" --passC:-mfloat-abi=hard")
  
  # Add include paths
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
  let lds = pkgPath & "/libDaisy/core/STM32H750IB_flash.lds"
  var linkCmd = "arm-none-eabi-g++ -o build/blink.elf " & join(objs, " ")
  linkCmd.add(" -mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard")
  linkCmd.add(" --specs=nano.specs --specs=nosys.specs")
  linkCmd.add(" -L" & pkgPath & "/libDaisy/build -ldaisy")
  if fileExists(lds):
    linkCmd.add(" -T" & lds)
  linkCmd.add(" -Wl,-Map=build/blink.map -Wl,--gc-sections -Wl,--print-memory-usage")
  
  echo "Linking: " & linkCmd
  exec linkCmd
  
  # Generate binary and print size
  exec "arm-none-eabi-objcopy -O binary build/blink.elf build/blink.bin"
  exec "arm-none-eabi-size build/blink.elf"
  
  echo "✓ Build complete: build/blink.bin"
```

#### Change 5: Update clear task
```nim
task clear, "Remove build artifacts for example":
  ## Remove all build artifacts (nimble clean cannot be overridden)
  if dirExists("build"):
    rmDir("build")
    echo "✓ Removed build/"
  if dirExists("nimcache"):
    rmDir("nimcache")
    echo "✓ Removed nimcache/"
```

### Phase 3: Test Installation Flow

1. **Uninstall existing nimphea:**
   ```bash
   nimble uninstall -i nimphea
   ```

2. **Install nimphea from local directory:**
   ```bash
   cd /Users/zawa/Projects/nim/nimphea_dev/nimphea
   nimble install
   ```
   
   **Expected output:**
   - Package installs
   - libDaisy is cloned (if not present)
   - libDaisy is built automatically
   - Success message: "Nimphea is ready to use!"

3. **Verify libDaisy is built:**
   ```bash
   nimble path nimphea
   ls -la <path>/libDaisy/build/libdaisy.a
   ```

### Phase 4: Test Example Build

1. **Navigate to blink example:**
   ```bash
   cd /Users/zawa/Projects/nim/nimphea_dev/nimphea/nimphea-examples/examples/blink
   ```

2. **Build the example:**
   ```bash
   nimble make
   ```
   
   **Expected output:**
   - Finds nimphea path
   - Compiles Nim code to object files
   - Links with arm-none-eabi-g++
   - Creates build/blink.elf and build/blink.bin
   - Shows binary size information

3. **Verify build artifacts:**
   ```bash
   ls -la build/
   # Should see: blink.bin, blink.elf, blink.map, nimcache/
   ```

### Phase 5: Test Clean/Clear

1. **Test nimble clean:**
   ```bash
   nimble clean
   ```
   - Check what it removes
   - Note: nimble clean typically only removes nimcache, not build/

2. **Test clear task:**
   ```bash
   nimble clear
   ```
   
   **Expected:**
   - Removes build/ directory completely
   - Removes any nimcache/ if present
   - Shows confirmation messages

3. **Verify cleanup:**
   ```bash
   ls -la build/ 2>&1 || echo "build/ removed successfully"
   ```

### Phase 6: Update Template Files

Apply the same blink.nimble fixes to:
- `/Users/zawa/Projects/nim/nimphea_dev/nimphea/templates/basic/project.nimble`
- `/Users/zawa/Projects/nim/nimphea_dev/nimphea/templates/audio/project.nimble`

## Rollback Strategy

If issues occur:

1. **Local libDaisy exists:** The code checks for existing libDaisy and won't re-clone if it's properly initialized

2. **Git submodule support:** If in a git repo, uses `git submodule update` instead of clone

3. **Manual fallback:** Users can always run `nimble init_libdaisy` manually if automatic init fails

4. **Non-fatal errors:** The `after install` hook catches exceptions and prints helpful error messages without failing the entire install

## Testing Checklist

- [ ] Uninstall nimphea
- [ ] Install nimphea with `nimble install`
- [ ] Verify libDaisy is cloned and built
- [ ] Navigate to blink example
- [ ] Run `nimble make` successfully
- [ ] Verify build/blink.bin exists
- [ ] Run `nimble clear` and verify cleanup
- [ ] Test template projects work

## Success Criteria

1. ✓ `nimble install nimphea` completes without errors
2. ✓ libDaisy is automatically cloned and built
3. ✓ `nimble make` in blink example produces working binary
4. ✓ `nimble clear` removes all build artifacts
5. ✓ Examples can be built immediately after installation

## Notes

- The ICM20948 patch has been removed (merged upstream) - no action needed
- Examples are isolated in nimphea-examples/ - they use the installed nimphea package
- Templates in templates/ should be updated after blink.nimble is verified working
- The `after install` hook runs in the installed package directory, not the source directory
