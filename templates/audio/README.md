# Nimphea Audio Template

A starter project for the Daisy Audio Platform with a pre-configured audio
processing callback.

## Features

- Stereo audio passthrough boilerplate.
- Real-time safety guidelines (audio callback rules).
- Build/flash tasks in `config.nims` (same build system as the basic template).

## Usage

1. Copy this directory into your project root.
2. Provide the nimphea import path with your package manager of choice
   (the template ships no `nim.cfg`; your package manager creates one):
   - **atlas**: `atlas init`/`atlas install` writes a `nim.cfg` with the paths
   - **nimble**: install nimphea via `nimble install nimphea`
   - **manual**: `--path:"/path/to/nimphea/src"` in a `nim.cfg`
3. Build libDaisy once inside the nimphea checkout:
   ```bash
   nim e <nimphea>/scripts/init_libdaisy.nims
   ```
4. Build and flash:
   ```bash
   nim make             # build ARM ELF -> build/audio.elf
   nim bin              # generate the flashable build/audio.bin
   nim flash            # flash via DFU bootloader; or `nim stlink`
   ```
