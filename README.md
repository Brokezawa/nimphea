# Nimphea

A comprehensive, type-safe Nim wrapper for the [libDaisy](https://github.com/electro-smith/libDaisy) hardware abstraction library, enabling elegant Nim development for the Electro-Smith Daisy Seed embedded audio platform.

[![CI](https://github.com/Brokezawa/nimphea/actions/workflows/ci.yml/badge.svg)](https://github.com/Brokezawa/nimphea/actions/workflows/ci.yml)
[![Docs](https://github.com/Brokezawa/nimphea/actions/workflows/docs.yml/badge.svg)](https://brokezawa.github.io/nimphea/)
[![Version](https://img.shields.io/badge/version-2.0.0-blue)](https://github.com/Brokezawa/nimphea/releases/tag/v2.0.0)
[![Nim](https://img.shields.io/badge/nim-2.0%2B-orange)](https://nim-lang.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## What is this?

This wrapper allows you to write firmware for the Daisy Seed embedded audio board using the Nim programming language instead of C++. It provides a clean, type-safe API that wraps libDaisy's hardware abstraction layer.

**Key Features:**
- Zero overhead - Direct C++ interop with no runtime cost
- Type safety - Nim's strong type system catches errors at compile time
- Clean API - Idiomatic Nim interfaces to libDaisy functionality
- Comprehensive - High coverage of libDaisy features
- Hardware Accelerated DSP - Full CMSIS-DSP support included
- Well documented - Searchable API reference and handwritten guides

## Quick Start

### Hardware Requirements
- **Daisy Seed** - STM32H750-based embedded audio board
- **USB cable** - For programming and power
- **Audio I/O** (optional) - For audio applications

### Software Requirements
- **Nim** - 2.0 or later
- **ARM Toolchain** - `arm-none-eabi-gcc` and related tools
- **dfu-util** - For uploading firmware

### Installation

Nimphea is package-manager-free: clone the repo and build with plain `nim`.
The library locates itself via the `NIMPHEA` environment variable, a sibling
`../nimphea` checkout, or `nimble path nimphea` (optional fallback) — so no
installation step is needed.

1. **Clone the library**:
```bash
git clone https://github.com/Brokezawa/nimphea.git
cd nimphea

# One-time setup: fetch libDaisy and build it (+ optional fatfs/CMSIS-DSP libs)
nim e scripts/init_libdaisy.nims
```

> **Note**: `nimble install nimphea` also works, but it does **not** clone or
> build libDaisy — run `nim e scripts/init_libdaisy.nims` once yourself.
> Prefer a checkout: `import nimphea` then resolves via `NIMPHEA` or a sibling
> `../nimphea` directory.

2. **Create a project from a template**:
Copy the bundled scaffold ([`templates/basic/`](templates/basic/)) into your
project root, or clone one of the starter templates:
- [Basic Template](https://github.com/Brokezawa/nimphea-template-basic)
- [Audio Template](https://github.com/Brokezawa/nimphea-template-audio)

3. **Build and Flash**:
Navigate to your project directory and use the self-contained task scripts
(the project locates nimphea via `NIMPHEA`/sibling automatically):
```bash
nim make           # build ARM binary -> build/<name>.elf / .bin
nim flash          # flash via DFU bootloader
nim stlink         # flash via ST-Link/OpenOCD
```

## Documentation
 Official docs (GitHub Pages): https://brokezawa.github.io/nimphea

- [Installation Guide](docs/guides/installation.md)
- [Getting Started](docs/guides/getting-started.md)
- [CMSIS-DSP Guide](docs/guides/getting-started.md)
- [API Reference](docs/API_REFERENCE.md)

## Examples

The [Nimphea Examples Repository](https://github.com/Brokezawa/nimphea-examples) contains 44 tested examples covering:

- **Basic** - GPIO, LEDs, buttons
- **Audio** - Passthrough, synthesis, effects
- **DSP** - CMSIS-DSP accelerated math
- **Peripherals** - ADC, PWM, I2C, SPI, UART, USB, MIDI
- **Displays** - OLED (I2C/SPI), LCD character displays
- **Sensors** - IMU, gesture, touch controllers
- **Storage** - SD Card, QSPI flash, SDRAM

## Templates

A self-contained project scaffold lives in [`templates/basic/`](templates/basic/):
copy it into your project root and build with `nim make` (no package
manager required). See [`templates/basic/README.md`](templates/basic/README.md).

## License

This wrapper follows the same MIT license as libDaisy. See [LICENSE](LICENSE) file for details.

## contributing

Contributions are welcome! See [CONTRIBUTING](docs/CONTRIBUTING.md) for details.
