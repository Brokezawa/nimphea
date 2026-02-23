# Nimphea Basic Template

A minimal starter project for the Daisy Audio Platform using Nimphea.

## Features
- Standard Nimble-based project structure.
- Pre-configured build and flash tasks.
- Basic LED blink and USB serial logging boilerplate.

## Usage

1. Install Nimphea:
   ```bash
   nimble install nimphea
   ```

2. Build for ARM:
   ```bash
   nimble make
   ```

3. Flash via USB DFU:
   - Put Daisy in DFU mode (BOOT + RESET).
   ```bash
   nimble flash
   ```

## Files
- `src/main.nim`: Main application entry point.
- `project.nimble`: Project configuration and build scripts.
- `src/panicoverride.nim`: Custom panic handler for bare metal.
