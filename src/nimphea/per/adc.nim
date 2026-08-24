## ADC (Analog to Digital Converter) support for libDaisy Nim wrapper
##
## This module provides comprehensive ADC functionality for the Daisy Audio Platform,
## including single-channel inputs, multiplexed inputs, and various conversion speeds.
##
## Example - Simple single-channel ADC:
## ```nim
## import nimphea, per/adc
## 
## var hw = initDaisy()
## 
## # Configure ADC channels
## var channels: array[2, AdcChannelConfig]
## channels[0].initSingle(A0())
## channels[1].initSingle(A1())
## 
## # Initialize ADC
## var adc = initAdcHandle(channels, OVS_32)
## adc.start()
## 
## while true:
##   let value1 = adc.getFloat(0)  # 0.0 to 1.0
##   let value2 = adc.getFloat(1)
##   hw.delay(10)
## ```
##
## Example - Multiplexed ADC (up to 8 inputs on one pin):
## ```nim
## # Configure mux: one ADC pin with 4 multiplexed inputs
## var channels: array[1, AdcChannelConfig]
## channels[0].initMux(
##   adcPin = A0(),
##   muxChannels = 4,  # Using a 4052 mux (2 select lines)
##   mux0 = D0(),      # First select line
##   mux1 = D1()       # Second select line
## )
## 
## var adc = initAdcHandle(channels, OVS_32)
## adc.start()
## 
## while true:
##   for i in 0..<4:
##     let value = adc.getMuxFloat(0, i)  # Channel 0, mux index i
##   hw.delay(10)
## ```

# Import libdaisy which provides the macro system
import nimphea
export nimphea_core_types

# Use the macro system for this module's compilation unit
useNimpheaModules(adc)

# =============================================================================
# AdcChannelConfig (bind-once)
# =============================================================================
proc initSingle*(config: var AdcChannelConfig, pin: Pin,
                 speed: ConversionSpeed = SPEED_8CYCLES_5)
  {.importcpp: "#.InitSingle(@)", header: "daisy_seed.h".}
  ## Initialize an ADC channel configuration for a single analog input
  ##
  ## Parameters:
  ##   config: The channel configuration object to initialize
  ##   pin: The analog input pin (e.g., A0(), A1(), etc.)
  ##   speed: Conversion speed - faster = less accurate but quicker reads

proc initMux*(config: var AdcChannelConfig, adcPin: Pin, muxChannels: csize_t,
              mux0: Pin, mux1: Pin = Pin(), mux2: Pin = Pin(),
              speed: ConversionSpeed = SPEED_8CYCLES_5)
  {.importcpp: "#.InitMux(@)", header: "daisy_seed.h".}
  ## Initialize an ADC channel configuration for a multiplexed input
  ##
  ## Supports CD405X series multiplexers (4051, 4052, 4053) to read
  ## multiple analog inputs through a single ADC channel.
  ##
  ## Parameters:
  ##   config: The channel configuration object to initialize
  ##   adcPin: The ADC input pin connected to the mux output
  ##   muxChannels: Number of mux inputs (1-8)
  ##   mux0: First select line (required for all muxes)
  ##   mux1: Second select line (required for 4+ channels)
  ##   mux2: Third select line (required for 8 channels)
  ##   speed: Conversion speed

proc initMux*(config: var AdcChannelConfig, adcPin: Pin, muxChannels: int,
              mux0: Pin, mux1: Pin = Pin(), mux2: Pin = Pin(),
              speed: ConversionSpeed = SPEED_8CYCLES_5) = ## retained: int -> csize_t ergonomics
  config.initMux(adcPin, muxChannels.csize_t, mux0, mux1, mux2, speed)

proc newAdcChannelConfig*(): AdcChannelConfig
  {.importcpp: "daisy::AdcChannelConfig()", constructor, header: "daisy_seed.h".}
  ## Create a new ADC channel configuration

# =============================================================================
# AdcHandle (bind-once)
# =============================================================================
proc init*(adc: var AdcHandle, cfg: ptr AdcChannelConfig, numChannels: csize_t,
           oversampling: OverSampling = OVS_32)
  {.importcpp: "#.Init(@)", header: "daisy_seed.h".}
proc start*(adc: var AdcHandle) {.importcpp: "#.Start()", header: "daisy_seed.h".}
  ## Start ADC conversions (must be called before reading values)
proc stop*(adc: var AdcHandle) {.importcpp: "#.Stop()", header: "daisy_seed.h".}
  ## Stop ADC conversions

proc get*(adc: AdcHandle, channel: uint8): uint16 {.importcpp: "#.Get(@)", header: "daisy_seed.h".}
proc getPtr*(adc: AdcHandle, channel: uint8): ptr uint16 {.importcpp: "#.GetPtr(@)", header: "daisy_seed.h".}
proc getFloat*(adc: AdcHandle, channel: uint8): cfloat {.importcpp: "#.GetFloat(@)", header: "daisy_seed.h".}
proc getMux*(adc: AdcHandle, channel: uint8, muxIndex: uint8): uint16 {.importcpp: "#.GetMux(@)", header: "daisy_seed.h".}
proc getMuxPtr*(adc: AdcHandle, channel: uint8, muxIndex: uint8): ptr uint16 {.importcpp: "#.GetMuxPtr(@)", header: "daisy_seed.h".}
proc getMuxFloat*(adc: AdcHandle, channel: uint8, muxIndex: uint8): cfloat {.importcpp: "#.GetMuxFloat(@)", header: "daisy_seed.h".}

# Retained ergonomics overloads: int channel indices cast to uint8 (see design D1)
proc get*(adc: AdcHandle, channel: int): uint16 = adc.get(channel.uint8)
proc getPtr*(adc: AdcHandle, channel: int): ptr uint16 = adc.getPtr(channel.uint8)
proc getFloat*(adc: AdcHandle, channel: int): cfloat {.inline.} = adc.getFloat(channel.uint8)
proc getMux*(adc: AdcHandle, channel: int, muxIndex: int): uint16 = adc.getMux(channel.uint8, muxIndex.uint8)
proc getMuxPtr*(adc: AdcHandle, channel: int, muxIndex: int): ptr uint16 = adc.getMuxPtr(channel.uint8, muxIndex.uint8)
proc getMuxFloat*(adc: AdcHandle, channel: int, muxIndex: int): cfloat {.inline.} = adc.getMuxFloat(channel.uint8, muxIndex.uint8)

proc newAdcHandle*(): AdcHandle {.importcpp: "daisy::AdcHandle()", constructor, header: "daisy_seed.h".}

proc initAdcHandle*(configs: var openArray[AdcChannelConfig],
                    oversampling: OverSampling = OVS_32): AdcHandle =
  ## Initialize an ADC handle with the given channel configurations
  ## (retained: openArray + len guard + csize_t conversion)
  ##
  ## Parameters:
  ##   configs: Array of channel configurations (up to 16 channels)
  ##   oversampling: Oversampling rate (OVS_32 is a good default balance)
  ##
  ## Example:
  ## ```nim
  ## var channels: array[3, AdcChannelConfig]
  ## channels[0].initSingle(A0())
  ## channels[1].initSingle(A1())
  ## channels[2].initSingle(A2())
  ## var adc = initAdcHandle(channels, OVS_32)
  ## adc.start()
  ## ```
  result = newAdcHandle()
  if configs.len > 0:
    result.init(addr configs[0], configs.len.csize_t, oversampling)

when isMainModule:
  echo "libDaisy ADC wrapper - Clean API"