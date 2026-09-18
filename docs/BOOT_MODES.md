# Boot Modes Guide

[← Home](index.md)

---

This document explains the three boot modes supported by Nimphea and how to choose the right one for your project.

## Overview

Nimphea applications can be deployed in three different ways, each with different trade-offs:

| Mode | Flash Location | Bootloader | Max Size | Best For |
|------|---|---|---|---|
| **BOOT_NONE** | Internal (0x08000000) | None | ~124KB | Development, simple projects |
| **BOOT_SRAM** | SRAM (0x24000000) | DFU (one-time flash) | ~480KB | Rapid iteration with bootloader |
| **BOOT_QSPI** | External (0x90040000) | DFU (one-time flash) | ~8MB chip (≈7.75MB app) | Large applications, libraries |

The Daisy bootloader ([open source](https://github.com/electro-smith/DaisyBootloader))
is flashed once via USB DFU (or the [web programmer](https://flash.daisy.audio);
binaries ship in `libDaisy/core/`) — no ST-Link needed. It lives in internal
flash like a normal application and can be updated or customized (e.g. custom
USB IDs) the same way. See the [official bootloader tutorial](https://docs.daisy.audio/tutorials/_a7_Getting-Started-Daisy-Bootloader/)
for variants (`intdfu`/`extdfu`), SD-card/USB-drive updates, and customization.

## Quick Decision Tree

```
Is your application < 120KB?
├─ Yes: Do you need fast iteration?
│  ├─ Yes → Use BOOT_SRAM (fast reload, no reflash)
│  └─ No → Use BOOT_NONE (simpler)
└─ No: Must use bootloader + QSPI
   └─ Use BOOT_QSPI (only option for large apps)

Special case: Using CMSIS-DSP? → Always BOOT_QSPI (library is 1MB)
Note: the bootloader is a one-time USB DFU flash (see below).
```

## Detailed Comparison

### BOOT_NONE (Direct Flash)

**What it is:** Application flashes directly to the Daisy's internal flash. No bootloader involved.

**Memory layout:**
- Application code: 0x08000000 to ~0x0801F000 (124KB available)
- Stack and static data: Remaining SRAM

**Advantages:**
- No bootloader required - can start fresh
- Simplest deployment - one flash operation
- Full control over memory layout
- Fastest execution (no bootloader overhead)
- Best for development and learning

**Disadvantages:**
- Limited to ~124KB of code
- Requires ST-Link or DFU mode selection each time
- No fast iteration mode

**When to use:**
- First project setup
- LED blink, serial logging, simple control
- Development and experimentation
- Total application < 100KB

**Flashing:**
```bash
nim make
nim stlink  # Via ST-Link (fastest)
# OR
nim flash   # Via USB DFU (no hardware required)
```

**Configuration in config.nims:**
```nim
const bootMode = ""  # or omit entirely
```

---

### BOOT_SRAM (Bootloader + SRAM Loading)

**What it is:** Application runs from SRAM, loaded via the Daisy bootloader
(open source, flashed once via USB DFU — see the overview above). Once the
bootloader is present, you can reload the application over USB without extra
hardware.

**Memory layout:**
- Bootloader: 0x08000000 to ~0x08020000 (~128KB internal flash)
- Application code: 0x24000000 (runs in AXI-SRAM at runtime, 480KB usable —
  0x20000000 is DTCMRAM, a separate 128KB region)
- Heap/stack: remaining SRAM + DTCMRAM

**Advantages:**
- Fast iteration - flash via USB without hardware
- Better size limit (~480KB app in SRAM)
- No ST-Link needed, ever (bootloader itself flashes over USB DFU)
- Good for embedded development workflow

**Disadvantages:**
- SRAM app space is limited (~480KB usable of the 512KB AXI-SRAM)
- Power cycle erases application (reboot returns to bootloader)
- SRAM execution is comparable to internal flash (both fast)

**When to use:**
- Rapid development with bootloader present
- Applications 100KB to 480KB
- Team projects where bootloader is pre-installed
- Faster iteration cycles preferred

**Setup (one-time):**
1. Flash the bootloader via USB DFU: enter DFU mode (Hold BOOT, press RESET,
   release BOOT), then flash a binary from `libDaisy/core/` (or use the
   [web programmer](https://flash.daisy.audio))
2. Enter bootloader: Hold BOOT, press RESET, release BOOT
3. Run: `nim flash` - loads to SRAM via USB

**Flashing:**
```bash
nim make
nim flash   # USB DFU only (bootloader required)
```

**Configuration in config.nims:**
```nim
const bootMode = "bootSram"
```

---

### BOOT_QSPI (Bootloader + External Flash)

**What it is:** Application stored in the external QSPI flash chip (8MB),
loaded via the Daisy bootloader. Provides large storage for feature-rich
applications.

**Memory layout:**
- Bootloader: 0x08000000 to ~0x08020000 (~128KB internal flash)
- Application code: 0x90040000 (in QSPI, 7936KB usable of the 8MB chip)
- Heap/stack: SRAM (reusable, doesn't count toward app size)

**Advantages:**
- Large code space (8MB QSPI chip, ≈7.75MB app space)
- Required for large libraries (CMSIS-DSP ~1MB)
- Fast iteration - reload over USB
- Persistent across power cycles
- Extra update methods: SD card / USB drive (`.bin` drop) besides DFU

**Disadvantages:**
- Requires the bootloader (one-time USB DFU flash, no ST-Link needed)
- Pick the `intdfu`/`extdfu` bootloader variant matching your USB port
- QSPI access slightly slower than internal flash/SRAM
- More complex memory layout

**When to use:**
- Applications > 120KB (especially > 300KB)
- Using CMSIS-DSP library (always required)
- Complex audio processing, filters, FFT
- Full-featured applications with UI framework

**Setup (one-time):**
1. Flash the bootloader via USB DFU as described above (pick the
   `intdfu`/`extdfu` variant for your USB port)
2. Enter bootloader: Hold BOOT, press RESET, release BOOT
3. First flash may take longer (programming QSPI)

**Flashing:**
```bash
nim make
nim flash   # USB DFU only (bootloader required)
```

**Configuration in config.nims:**
```nim
const bootMode = "bootQspi"
```

**Example: CMSIS-DSP (always BOOT_QSPI):**
```nim
const bootMode = "bootQspi"
switch("define", "useCMSIS")
```

---

## Common Scenarios

### Scenario 1: Brand New Project

**Goal:** Get something working on Daisy

**Steps:**
1. Use BOOT_NONE (no extra setup)
2. Flash with ST-Link or USB DFU
3. Start simple - blink, serial logging
4. Only switch modes if you hit size limit

**Example:**
```bash
# Create from template
git clone https://github.com/Brokezawa/nimphea-template-basic myproject
cd myproject

# Build and flash
nim make
nim stlink  # or: nim flash
```

### Scenario 2: Growing Beyond 120KB

**Goal:** Application is hitting size limit in BOOT_NONE

**Steps:**
1. Flash the bootloader once via USB DFU if not present (see above)
2. Choose BOOT_SRAM or BOOT_QSPI based on size
3. Update `bootMode` in config.nims
4. Flash via `nim flash`

**Decision:**
- Application < 480KB? → BOOT_SRAM (simpler)
- Application > 480KB? → BOOT_QSPI (required)
- Using CMSIS-DSP? → Always BOOT_QSPI

### Scenario 3: Using CMSIS-DSP for FFT

**Goal:** Fast Fourier Transform for spectral analysis

**Requirements:**
- CMSIS-DSP library is ~1MB (won't fit in internal flash)
- Must use BOOT_QSPI boot mode
- Bootloader flashed once via USB DFU if not present

**Configuration:**
```nim
# config.nims
const bootMode = "bootQspi"
switch("define", "useCMSIS")
```

**Build and flash:**
```bash
nim make      # Will link CMSIS-DSP library
nim flash     # Over USB with bootloader (2-3 seconds)
```

### Scenario 4: Team Project with Bootloader Pre-Installed

**Goal:** New developer joining project that already has bootloader

**Setup (one-time):**
1. No setup needed - bootloader already on device
2. Enter bootloader: Hold BOOT, press RESET, release BOOT
3. Run `nim flash` - loads via USB

**Daily workflow:**
```bash
nim make
nim flash    # Fast USB update, no hardware required
```

---

## Changing Boot Modes

### From BOOT_NONE to BOOT_SRAM

```nim
# config.nims - Change this line:
const bootMode = ""        # was: BOOT_NONE
# to:
const bootMode = "bootSram"
```

Then:
```bash
nim make
nim flash  # via the preinstalled/flashed bootloader
```

### From BOOT_SRAM to BOOT_QSPI

```nim
# config.nims
const bootMode = "bootQspi"  # was: "bootSram"
```

Then:
```bash
nim make
nim flash
```

### Reverting to BOOT_NONE

Flash directly to internal flash (overwrites the bootloader area), via
ST-Link **or** USB DFU using the STM32 ROM bootloader:

```bash
# Remove boot mode defines
const bootMode = ""

nim make
nim stlink   # Via ST-Link; or DFU-flash like any BOOT_NONE app
```

---

## Troubleshooting

### "stlink task requires BOOT_NONE mode"

**Problem:** Tried `nim stlink` with bootloaded application

**Solution:**
- Bootloaded modes (BOOT_SRAM, BOOT_QSPI) must use `nim flash` (DFU)
- Direct flash (BOOT_NONE) can use `nim stlink` (ST-Link)

**Fix:**
```bash
# Bootloader present (DFU mode): use DFU
nim flash

# No bootloader (plain BOOT_NONE app): flash directly
nim stlink
```

### Application Size Error

**Problem:** "Binary too large for internal flash"

**Solutions:**
1. Enable size optimization: check `-Os` flag in config.nims
2. Switch to BOOT_QSPI: enables external 8MB QSPI storage
3. Add CMSIS-DSP if needed: requires BOOT_QSPI anyway

### Bootloader Entry Not Working

**Problem:** Device won't enter bootloader (Hold BOOT + press RESET)

**Possible causes:**
1. Application is interfering (e.g., GPIO remapping)
2. Wrong bootloader variant for your USB port (`intdfu` vs `extdfu`)
3. Wrong button combination for your board

**Solution:**
- Try the other bootloader variant, or re-flash it via USB DFU / web programmer
- Check connected media for stray `.bin` files (auto-flash on boot)
- Try flashing with ST-Link in BOOT_NONE mode first

---

## Technical Details

### Memory Maps

**BOOT_NONE:**
```
0x08000000 ┌─────────────────────┐
           │  Application Code   │  ~124KB available
           │  (direct flash)     │  (128KB flash total)
0x0801F000 └─────────────────────┘
0x20000000 ┌─────────────────────┐
           │  DTCMRAM            │  128KB
0x20020000 └─────────────────────┘
0x24000000 ┌─────────────────────┐
           │  Stack + Heap       │  512KB AXI-SRAM
0x24080000 └─────────────────────┘
```

**BOOT_SRAM:**
```
0x08000000 ┌─────────────────────┐
           │  Daisy Bootloader   │  ~128KB (internal flash)
~0x08020000 └─────────────────────┘
0x20000000 ┌─────────────────────┐
           │  DTCMRAM            │  128KB
0x20020000 └─────────────────────┘
0x24000000 ┌─────────────────────┐
           │  Application Code   │  480KB (runs here)
           │  + Stack/Heap       │  (512KB SRAM minus 32KB
           └─────────────────────┘   reserved by the bootloader)
```

**BOOT_QSPI:**
```
0x08000000 ┌─────────────────────┐
           │  Daisy Bootloader   │  ~128KB (internal flash)
~0x08020000 └─────────────────────┘
0x90040000 ┌─────────────────────┐
           │  Application Code   │  7936KB (≈7.75MB of the
           │  (in QSPI flash)    │  8MB chip, from 0x90040000)
0x90800000 └─────────────────────┘
0x20000000 ┌─────────────────────┐
           │  DTCMRAM            │  128KB
0x20020000 └─────────────────────┘
0x24000000 ┌─────────────────────┐
           │  Stack + Heap       │  Full 512KB SRAM available
0x24080000 └─────────────────────┘  (not counted toward app size)
```

### Performance Notes

- **BOOT_NONE**: Fastest - code executes directly from flash
- **BOOT_SRAM**: Comparable to internal flash (AXI-SRAM is zero-wait-state)
- **BOOT_QSPI**: QSPI access has latency, but for most code this is negligible

---

## References

- [Getting Started](./guides/getting-started.md) - Project setup and build commands
- [Flashing Guide](./FLASH_GUIDE.md) - Flashing methods and tools
- [Daisy Bootloader tutorial](https://docs.daisy.audio/tutorials/_a7_Getting-Started-Daisy-Bootloader/) - Variants, DFU/SD/USB update methods, customization
- [DaisyBootloader source](https://github.com/electro-smith/DaisyBootloader) - Open-source bootloader (custom USB IDs, timeouts)
- Templates: [Basic](https://github.com/Brokezawa/nimphea-template-basic) | [Audio](https://github.com/Brokezawa/nimphea-template-audio)
