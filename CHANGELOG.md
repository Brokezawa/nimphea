# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-02-20

### Added
- CMSIS-DSP support: Comprehensive wrapper for ARM optimized math functions.
- Integrated CMSIS-DSP modules: `cmsis`, `cmsis_types`, `dsp_basic`, `dsp_filtering`, `dsp_transforms`, `dsp_statistics`, `dsp_fastmath`, `dsp_matrix`, `dsp_complex`, `dsp_support`, `dsp_controller`, `dsp_fixed`, `dsp_interpolation`.
- Automated build system support for CMSIS-DSP source bundles.
- Project templates for Basic and Audio applications.
- Handwritten documentation guides for installation and getting started.

### Changed
- Migrated all `unsafeAddr` usage to the modern `addr` operator.
- Restructured repository for better Nimble package compatibility.
- Moved all core modules under the `nimphea/` namespace prefix.
- Updated `nimphea.nimble` with post-install hooks to automatically build `libDaisy`.
- Relocated examples to a separate directory structure in preparation for external hosting.

### Fixed
- Improved exception safety by enforcing `{.raises: [].}` patterns in documentation.
- Fixed panic handler to be more idiomatic and reliable on bare metal.

## [1.0.0] - 2026-02-15
- Initial release of Nimphea.
- Core libDaisy wrappers for Daisy Seed, Pod, Patch, Field, Petal, Versio, and Legio.
- Peripheral support for ADC, DAC, GPIO, I2C, SPI, UART, and PWM.
- HID support for switches, encoders, and LEDs.
- Basic audio processing infrastructure.
