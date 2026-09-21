# Installation Guide

[Home](../index.md) | [Installation](installation.md) | [Getting Started](getting-started.md) | [CMSIS-DSP](cmsis-dsp.md)

---

To develop with Nimphea, you need the ARM Embedded Toolchain and the Nim compiler.

## 1. Prerequisites

### ARM Toolchain
You need the `arm-none-eabi-gcc` toolchain to compile for the Daisy's Cortex-M7 processor.

- **macOS**: `brew install --cask gcc-arm-embedded`
- **Linux**: `sudo apt install gcc-arm-none-eabi libnewlib-arm-none-eabi`
- **Windows**: Download from [ARM Developer website](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain).

### DFU-Util
Required for flashing via USB.
- **macOS**: `brew install dfu-util`
- **Linux**: `sudo apt install dfu-util`

## 2. Install Nim
Nimphea requires Nim 2.0.0 or later.
Follow the instructions at [nim-lang.org](https://nim-lang.org/install.html).

## 3. Get Nimphea

Nimphea is package-manager-free. Clone the repo and build once:

```bash
git clone https://github.com/Brokezawa/nimphea.git
cd nimphea

# Fetch and build libDaisy (+ optional fatfs/CMSIS-DSP libs)
nim e scripts/init_libdaisy.nims
```

> **Submodules must be checked out recursively.** A plain `git clone` leaves
> `libDaisy/` (and its own nested dependencies) empty. Either clone with
> `--recurse-submodules` or run `git submodule update --init --recursive`
> inside the checkout *before* the init script. Package managers such as
> Atlas do not initialize nested submodules, so atlas-managed checkouts need
> this step run manually — otherwise the script sees an (empty) `libDaisy/`
> directory and the C++ build fails.

> **Running scripts from a project directory:** the helper scripts ignore
> your project's cross `config.nims` settings. If you use an older nimphea
> and see `undeclared identifier: 'quoteShell'`, re-run with
> `nim e --skipParentCfg:on <nimphea>/scripts/init_libdaisy.nims`.

`nimble install nimphea` also works (metadata-only; it does **not** clone or
build libDaisy — run `nim e scripts/init_libdaisy.nims` once yourself). With a
checkout, projects resolve it via the `NIMPHEA` environment variable or a
sibling `../nimphea` directory — no installation step needed.

## 4. Verify Installation
Check if you can run the ARM compiler:
```bash
arm-none-eabi-gcc --version
```

Now you are ready to create your first project! See the [Getting Started](getting-started.md) guide.
