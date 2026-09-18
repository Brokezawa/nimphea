## MAX11300 20-Port Programmable Mixed-Signal I/O Module
##
## Device driver for MAX11300 PIXI - 20-port ADC/DAC/GPIO device.
## Highly opinionated implementation optimized for Eurorack modular synthesis.
##
## This is a full wrapper around libDaisy's MAX11300 C++ driver, supporting:
## - 20 configurable pins (ADC, DAC, GPIO input/output)
## - DMA-based continuous updates via Start() method
## - Multiple voltage ranges (-10V to +10V)
## - Up to 4 devices on shared SPI bus (multi-slave)
##
## **IMPORTANT**: This implementation wraps libDaisy's C++ driver but has
## **NOT been tested on hardware**. It follows libDaisy's proven code and
## compiles successfully, but should be considered **experimental** until
## hardware validation is complete.
##
## Example:
## ```nim
## var pixi: MAX11300  # Single device
## var config: MAX11300Config
## config.transport_config.pin_config.defaults()
##
## if pixi.init(config) != MAX_OK:
##   # Handle error
##
## # Configure pins
## discard pixi.configurePinAsAnalogRead(0, PIN_0, ADC_NEG5_TO_5)
## discard pixi.configurePinAsAnalogWrite(0, PIN_1, DAC_NEG5_TO_5)
##
## # Start DMA updates (optional)
## discard pixi.start(nil, nil)
##
## # Read/write
## let cvIn = pixi.readAnalogPinVolts(0, PIN_0)
## pixi.writeAnalogPinVolts(0, PIN_1, cvIn)
## ```

import nimphea
import nimphea/per/spi

# Need to expose SPI types in the module
export SpiPeripheral, SpiBaudPrescaler


{.push header: "dev/max11300.h".}

# ============================================================================
# Types from MAX11300Types namespace
# ============================================================================

type
  MAX11300Pin* {.importcpp: "daisy::MAX11300Types::Pin", size: sizeof(cint).} = enum
    ## Represents a pin/port on the MAX11300 (20 pins total)
    PIN_0  = "daisy::MAX11300Types::Pin::PIN_0"
    PIN_1  = "daisy::MAX11300Types::Pin::PIN_1"
    PIN_2  = "daisy::MAX11300Types::Pin::PIN_2"
    PIN_3  = "daisy::MAX11300Types::Pin::PIN_3"
    PIN_4  = "daisy::MAX11300Types::Pin::PIN_4"
    PIN_5  = "daisy::MAX11300Types::Pin::PIN_5"
    PIN_6  = "daisy::MAX11300Types::Pin::PIN_6"
    PIN_7  = "daisy::MAX11300Types::Pin::PIN_7"
    PIN_8  = "daisy::MAX11300Types::Pin::PIN_8"
    PIN_9  = "daisy::MAX11300Types::Pin::PIN_9"
    PIN_10 = "daisy::MAX11300Types::Pin::PIN_10"
    PIN_11 = "daisy::MAX11300Types::Pin::PIN_11"
    PIN_12 = "daisy::MAX11300Types::Pin::PIN_12"
    PIN_13 = "daisy::MAX11300Types::Pin::PIN_13"
    PIN_14 = "daisy::MAX11300Types::Pin::PIN_14"
    PIN_15 = "daisy::MAX11300Types::Pin::PIN_15"
    PIN_16 = "daisy::MAX11300Types::Pin::PIN_16"
    PIN_17 = "daisy::MAX11300Types::Pin::PIN_17"
    PIN_18 = "daisy::MAX11300Types::Pin::PIN_18"
    PIN_19 = "daisy::MAX11300Types::Pin::PIN_19"

  AdcVoltageRange* {.importcpp: "daisy::MAX11300Types::AdcVoltageRange", size: sizeof(cint).} = enum
    ## ADC voltage ranges (assumes proper power supply)
    ## WARNING: DigitalRead pins are 0-5V only and corrupted by negative voltages
    ADC_0_TO_10      = "daisy::MAX11300Types::AdcVoltageRange::ZERO_TO_10"
    ADC_NEG5_TO_5    = "daisy::MAX11300Types::AdcVoltageRange::NEGATIVE_5_TO_5"
    ADC_NEG10_TO_0   = "daisy::MAX11300Types::AdcVoltageRange::NEGATIVE_10_TO_0"
    ADC_0_TO_2P5     = "daisy::MAX11300Types::AdcVoltageRange::ZERO_TO_2P5"

  DacVoltageRange* {.importcpp: "daisy::MAX11300Types::DacVoltageRange", size: sizeof(cint).} = enum
    ## DAC voltage ranges (assumes proper power supply)
    ## DigitalWrite pins are 0-5V only
    DAC_0_TO_10      = "daisy::MAX11300Types::DacVoltageRange::ZERO_TO_10"
    DAC_NEG5_TO_5    = "daisy::MAX11300Types::DacVoltageRange::NEGATIVE_5_TO_5"
    DAC_NEG10_TO_0   = "daisy::MAX11300Types::DacVoltageRange::NEGATIVE_10_TO_0"

  MAX11300Result* {.importcpp: "daisy::MAX11300Types::Result", size: sizeof(cint).} = enum
    ## Operation result codes
    MAX_OK  = "daisy::MAX11300Types::Result::OK"
    MAX_ERR = "daisy::MAX11300Types::Result::ERR"

  MAX11300DmaBuffer* {.importcpp: "daisy::MAX11300Types::DmaBuffer", bycopy.} = object
    ## DMA buffer for SPI transfers - must be in non-cached memory
    rx_buffer* {.importc: "rx_buffer".}: array[41, uint8]
    tx_buffer* {.importc: "tx_buffer".}: array[41, uint8]

  UpdateCompleteCallback* = proc(context: pointer) {.cdecl.}
    ## Callback called after each successful DMA update cycle

# ============================================================================
# Transport Layer Types (N=1 only - the libDaisy template is complex)
# ============================================================================

type
  MAX11300TransportPinConfig* {.importcpp: "daisy::MAX11300MultiSlaveSpiTransport::Config<1>::PinConfig", bycopy.} = object
    ## SPI pin configuration for transport layer
    nss*  {.importc: "nss".}: array[1, Pin]   ## Chip select pins (one per device)
    mosi* {.importc: "mosi".}: Pin             ## SPI MOSI
    miso* {.importc: "miso".}: Pin             ## SPI MISO
    sclk* {.importc: "sclk".}: Pin             ## SPI clock

  MAX11300TransportConfig* {.importcpp: "daisy::MAX11300MultiSlaveSpiTransport::Config<1>", bycopy.} = object
    ## Transport layer configuration
    pin_config*      {.importc: "pin_config".}: MAX11300TransportPinConfig
    periph*          {.importc: "periph".}: SpiPeripheral
    baud_prescaler*  {.importc: "baud_prescaler".}: SpiBaudPrescaler

# ============================================================================
# Device Driver Types (N=1 only)
# ============================================================================

type
  MAX11300Config* {.importcpp: "daisy::MAX11300<1>::Config", bycopy.} = object
    ## MAX11300 device configuration (supports N=1 only)
    transport_config* {.importc: "transport_config".}: MAX11300TransportConfig

  MAX11300* = object
    ## MAX11300 device wrapper (single device, N=1).
    ##
    ## The embedded `dmaBuffer` keeps SPI DMA buffers co-located with the
    ## driver object (must live in DMA-accessible memory on the target).
    cpp: MAX11300Cpp
    dmaBuffer {.align(4).}: MAX11300DmaBuffer
    numDevices: csize_t

  MAX11300Cpp* {.importcpp: "daisy::MAX11300<1>".} = object
    ## Underlying C++ MAX11300 driver object
    ##
    ## Note: MAX11300Cpp* must be declared after MAX11300 for Nim's
    ## forward reference handling within this module. It is exported for
    ## advanced use but normal code only touches `MAX11300`.

{.pop.}  # header

# ============================================================================
# Default Configuration Helpers
# ============================================================================

proc defaults*(config: var MAX11300TransportPinConfig) =
  ## Set default pin configuration for Daisy Seed.
  ## Default pins match libDaisy defaults:
  ## - SPI1: PORTB.5 (MOSI), PORTB.4 (MISO), PORTG.11 (SCLK)
  ## - CS0: PORTG.10
  config.mosi = newPin(PORTB, 5)
  config.miso = newPin(PORTB, 4)
  config.sclk = newPin(PORTG, 11)
  config.nss[0] = newPin(PORTG, 10)

proc defaults*(config: var MAX11300TransportConfig) =
  ## Set default transport configuration.
  config.pin_config.defaults()
  config.periph = SPI_1
  config.baud_prescaler = SPI_PS_8

# ============================================================================
# Device Driver API (bind-once via `#.cpp.` access path)
# ============================================================================

{.push header: "dev/max11300.h".}

# --- Initialization ---

proc init*(max: var MAX11300, config: MAX11300Config, dmaBuffer: ptr MAX11300DmaBuffer): MAX11300Result
  {.importcpp: "#.cpp.Init(@)".}

proc init*(max: var MAX11300, config: MAX11300Config): MAX11300Result =
  ## Initialize the MAX11300 device(s), passing the embedded DMA buffer
  ## (retained: avoids exposing the DMA-buffer pointer to callers).
  ##
  ## This performs:
  ## - SPI initialization and connectivity verification
  ## - Device configuration (ADC/DAC modes, conversion rates, etc.)
  ## - All pins initialized to High-Z (disabled) mode
  ##
  ## **Returns:** MAX_OK on success, MAX_ERR on failure
  ##
  ## **Note:** Call this once at startup before configuring pins.
  result = max.init(config, addr max.dmaBuffer)

# --- Pin Configuration ---

proc configurePinAsAnalogRead*(max: var MAX11300, device: csize_t,
                               pin: MAX11300Pin, range: AdcVoltageRange): MAX11300Result
  {.importcpp: "#.cpp.ConfigurePinAsAnalogRead(@)".}
  ## Configure pin as analog input (ADC).
  ## Requires appropriate power supply for the chosen range.
proc configurePinAsAnalogWrite*(max: var MAX11300, device: csize_t,
                                pin: MAX11300Pin, range: DacVoltageRange): MAX11300Result
  {.importcpp: "#.cpp.ConfigurePinAsAnalogWrite(@)".}
  ## Configure pin as analog output (DAC).
  ## Requires appropriate power supply for the chosen range.
proc configurePinAsDigitalRead*(max: var MAX11300, device: csize_t,
                                pin: MAX11300Pin, threshold: cfloat = 2.5'f32): MAX11300Result
  {.importcpp: "#.cpp.ConfigurePinAsDigitalRead(@)".}
  ## Configure pin as digital input (GPI); threshold defaults to 2.5V.
  ##
  ## **WARNING:** Digital input pins are 0-5V only. Voltages below -250mV
  ## will corrupt ALL analog readings on the device!
proc configurePinAsDigitalWrite*(max: var MAX11300, device: csize_t,
                                 pin: MAX11300Pin, voltage: cfloat = 5.0'f32): MAX11300Result
  {.importcpp: "#.cpp.ConfigurePinAsDigitalWrite(@)".}
  ## Configure pin as digital output (GPO); voltage (logic HIGH) defaults to 5.0V.
  ## Note: Digital outputs are 0-5V only (no negative voltages).
proc disablePin*(max: var MAX11300, device: csize_t, pin: MAX11300Pin): MAX11300Result
  {.importcpp: "#.cpp.DisablePin(@)".}
  ## Disable pin (set to High-Z mode).

# --- Analog I/O ---

proc readAnalogPinRaw*(max: var MAX11300, device: csize_t, pin: MAX11300Pin): uint16
  {.importcpp: "#.cpp.ReadAnalogPinRaw(@)".}
  ## Read raw 12-bit ADC value (0-4095) from the local buffer.
  ## Call `start()` for DMA updates, otherwise values may be stale.
proc readAnalogPinVolts*(max: var MAX11300, device: csize_t, pin: MAX11300Pin): cfloat
  {.importcpp: "#.cpp.ReadAnalogPinVolts(@)".}
  ## Read ADC value in volts from the local buffer (per configured range).
proc writeAnalogPinRaw*(max: var MAX11300, device: csize_t,
                        pin: MAX11300Pin, value: uint16)
  {.importcpp: "#.cpp.WriteAnalogPinRaw(@)".}
  ## Write raw 12-bit DAC value (0-4095) to the local buffer.
proc writeAnalogPinVolts*(max: var MAX11300, device: csize_t,
                          pin: MAX11300Pin, voltage: cfloat)
  {.importcpp: "#.cpp.WriteAnalogPinVolts(@)".}
  ## Write DAC value in volts to the local buffer (clamped to configured range).

# --- Digital I/O ---

proc readDigitalPin*(max: var MAX11300, device: csize_t, pin: MAX11300Pin): bool
  {.importcpp: "#.cpp.ReadDigitalPin(@)".}
  ## Read digital input state from the local buffer (true if above threshold).
proc writeDigitalPin*(max: var MAX11300, device: csize_t,
                      pin: MAX11300Pin, value: bool)
  {.importcpp: "#.cpp.WriteDigitalPin(@)".}
  ## Write digital output state to the local buffer.

# --- DMA Update Control ---

proc start*(max: var MAX11300, callback: UpdateCompleteCallback = nil,
            context: pointer = nil): MAX11300Result
  {.importcpp: "#.cpp.Start(@)".}
  ## Start continuous DMA updates.
  ##
  ## Begins automatic background updates that write all DAC/GPO values to
  ## hardware, read all ADC/GPI values from hardware, and invoke the
  ## callback (from interrupt context) after each cycle.
  ##
  ## **Note:** Reads/writes work in polling mode without this, but DMA
  ## updates provide much better performance and timing.
proc stop*(max: var MAX11300) {.importcpp: "#.cpp.Stop()".}
  ## Stop continuous DMA updates (completes the current cycle first).

# --- Utility Functions (static) ---

proc voltsTo12BitUint*(volts: cfloat, range: DacVoltageRange): uint16
  {.importcpp: "daisy::MAX11300<1>::VoltsTo12BitUint(@)".}
  ## Convert voltage to a 12-bit DAC code (0-4095, clamped to range).
proc twelveBitUintToVolts*(value: uint16, range: AdcVoltageRange): cfloat
  {.importcpp: "daisy::MAX11300<1>::TwelveBitUintToVolts(@)".}
  ## Convert a 12-bit ADC code to voltage.
