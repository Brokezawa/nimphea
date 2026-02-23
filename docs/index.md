# Nimphea Documentation

Nimphea is an elegant Nim wrapper for the Daisy Audio Platform (STM32H7). It provides a high-level, type-safe API for building embedded synthesizers, effects, and audio tools while leveraging the performance of the underlying libDaisy C++ library.

## Getting Started

- [Installation Guide](guides/installation.md) - How to set up the ARM toolchain and Nimphea.
- [Starter Templates](#templates) - Quickly bootstrap a new project.
- [CMSIS-DSP Guide](guides/cmsis-dsp.md) - Using optimized ARM math functions.

## API Reference

- [Nimphea Core API](api/nimphea.html) - Main entry point.
- [Module Index](api/theindex.html) - Complete searchable index of all modules.

## Key Modules

- Peripherals: [ADC](api/nimphea/per/adc.html), [DAC](api/nimphea/per/dac.html), [GPIO](api/nimphea/per/gpio.html), [I2C](api/nimphea/per/i2c.html), [SPI](api/nimphea/per/spi.html), [UART](api/nimphea/per/uart.html)
- HID: [Switch](api/nimphea/hid/switch.html), [Encoder](api/nimphea/hid/encoder.html), [LED](api/nimphea/hid/led.html), [RGB LED](api/nimphea/hid/rgb_led.html), [MIDI](api/nimphea/hid/midi.html)
- DSP: [Basic Math](api/nimphea/cmsis/dsp_basic.html), [FFT](api/nimphea/cmsis/dsp_transforms.html), [Filters](api/nimphea/cmsis/dsp_filtering.html)
- System: [DMA](api/nimphea/sys/dma.html), [SDRAM](api/nimphea/sys/sdram.html), [FATFS](api/nimphea/sys/fatfs.html)

<a name="templates"></a>
## Project Templates

Start your project instantly with these GitHub templates:

1. [Basic Template](https://github.com/Brokezawa/nimphea-template-basic): Minimal LED blink and serial logging.
2. [Audio Template](https://github.com/Brokezawa/nimphea-template-audio): Pre-configured stereo audio callback.
3. [Starter Template](https://github.com/Brokezawa/nimphea-template-starter): Comprehensive setup with common hardware controls.

## Examples

The [Nimphea Examples Repository](https://github.com/Brokezawa/nimphea-examples) contains 40+ tested examples covering every aspect of the platform.
