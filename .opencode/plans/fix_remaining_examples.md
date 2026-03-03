# Fix Plan for Remaining Failing Examples

## Problem Summary

The remaining 16 failing examples have missing compile/link flags. These used to work in single-directory builds but broke when transitioning to the package system.

## Issues Identified

### 1. CMSIS Examples (cmsis_demo)
**Error:** `fatal error: arm_math.h: No such file or directory`

**Root Cause:** Missing CMSIS-DSP include path and ARM_MATH define

**Fix:** Add to `cmsis_demo.nimble`:
```nim
--passC:-I"<pkgPath>/libDaisy/Drivers/CMSIS-DSP/Include"
--passC:-DARM_MATH_CM7
```

### 2. FatFs Examples (wav_demo, sampler, looper, menu_dsl_demo, vu_meter, wavetable_synth)
**Error:** `undefined reference to 'ff_wtoupper'` and `ff_convert'`

**Root Cause:** libDaisy was built without FatFs support (USE_FATFS=1). The FatFs option files (that provide these functions) are not compiled into libdaisy.a.

**Fix:** Rebuild libDaisy with FatFs support:
```bash
cd libDaisy
make clean
make USE_FATFS=1
```

Then reinstall nimphea so the new libdaisy.a is included in the package.

## Implementation Steps

### Step 1: Update nimphea.nimble - Fix libDaisy Build

Modify the `after install` hook in `nimphea.nimble` to build libDaisy with FatFs support:

```nim
# In after install hook, change:
exec "make"

# To:
exec "make USE_FATFS=1"
```

Also update the `init_libdaisy` task similarly.

### Step 2: Update Example nimble Files - Add CMSIS-DSP Flags

For `cmsis_demo.nimble` and any other CMSIS-related examples, add:
```nim
# Add to nimCompile:
nimCompile.add(" --passC:-I\"" & libRoot / "Drivers/CMSIS-DSP/Include" & "\"")
nimCompile.add(" --passC:-DARM_MATH_CM7")
```

### Step 3: Rebuild Everything

```bash
# Uninstall nimphea
nimble uninstall -i nimphea

# Reinstall (will rebuild libDaisy with USE_FATFS=1)
nimble install

# Test examples
cd nimphea-examples
nim build_all.nims
```

## Files to Modify

1. **nimphea.nimble** - Add USE_FATFS=1 to libDaisy build commands
2. **nimphea-examples/examples/cmsis_demo/cmsis_demo.nimble** - Add CMSIS-DSP include paths

## Expected Results After Fix

- All 44 examples should build successfully
- CMSIS-DSP examples will find arm_math.h
- FatFs examples will link with ff_convert/ff_wtoupper functions

## Alternative for FatFs (If Rebuilding libDaisy Doesn't Work)

If rebuilding libDaisy isn't possible, manually add FatFs object files to the link command in each affected example nimble file:

```nim
# Add to linkCmd:
linkCmd.add(" " & libRoot & "/Middlewares/Third_Party/FatFs/src/option/ccsbcs.o")
```

But rebuilding libDaisy with USE_FATFS=1 is the cleaner solution.
