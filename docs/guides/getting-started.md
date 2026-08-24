# Getting Started

[Home](../index.md) | [Installation](installation.md) | [Getting Started](getting-started.md) | [CMSIS-DSP](cmsis-dsp.md)

---

This guide will help you create and build your first Nimphea project.

## 0. Prerequisites

- Nim 2.0 or later
- ARM toolchain (`arm-none-eabi-gcc`) for building
- `dfu-util` for flashing (or an ST-Link probe + OpenOCD)
- A nimphea checkout with libDaisy built once:
  ```bash
  cd <nimphea>
  nim e scripts/init_libdaisy.nims
  ```

## 1. Create a Project from Template

The easiest way to start is the bundled scaffold (`templates/basic/` in the
nimphea checkout — it is also shipped with `nimble install`) or the GitHub
templates:

1. Copy `templates/basic/` into your project root (or click **"Use this
   template"** on one of the template repositories):
   - [Basic Template Repository](https://github.com/Brokezawa/nimphea-template-basic)
   - [Audio Template Repository](https://github.com/Brokezawa/nimphea-template-audio)
2. The scaffold locates nimphea automatically via the `NIMPHEA` environment
   variable, a sibling `../nimphea` checkout, or `nimble path nimphea` — in
   that order. Set it if your checkout lives elsewhere:
   ```bash
   export NIMPHEA=/path/to/nimphea
   ```

## 2. Project Structure

- `config.nims`: Your ARM build configuration (self-contained, no package manager).
- `make.nims` / `flash.nims` / `stlink.nims` / `clear.nims`: task scripts.
- `src/main.nim`: Your application code (rename to `src/<dirName>.nim` or set
  `projName` in `config.nims`).
- `build/`: Built binaries (generated).

## 3. Build the Project

```bash
nim e make.nims
```

This will:
1. Compile your Nim code using the C++ backend.
2. Link against the pre-built `libDaisy`.
3. Generate a `build/<name>.bin` file.

## 4. Flash to Daisy

1. Connect your Daisy Seed via USB.
2. Enter **DFU mode**:
   - Hold the **BOOT** button.
   - Press and release the **RESET** button.
   - Release the **BOOT** button.
3. Run the flash command:
   ```bash
   nim e flash.nims
   ```

## 5. Next Steps

- Explore the [Nimphea Examples](https://github.com/Brokezawa/nimphea-examples) for more complex use cases.
- Check the [API Reference](../theindex.html) for module documentation.
- Read the [CMSIS-DSP Guide](cmsis-dsp.html) for high-performance audio processing.