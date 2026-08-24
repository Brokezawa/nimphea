## SAI (Serial Audio Interface) support for Nimphea
##
## This module provides low-level SAI peripheral access for the Daisy Audio Platform.
## SAI is used for I2S audio communication with external codecs.
##
## **Note**: For most applications, you should use the high-level audio API in
## `nimphea.nim` instead of using SAI directly. This module is provided for
## advanced use cases requiring custom audio configurations.
##
## Example - Custom SAI configuration:
## ```nim
## import nimphea, nimphea_sai
## 
## var sai: SaiHandle
## var config = newSaiConfig()
## 
## # Configure SAI1 for 48kHz, 24-bit audio
## config.periph = SAI_1
## config.sr = SAI_48KHZ
## config.bit_depth = SAI_24BIT
## config.a_sync = MASTER
## config.b_sync = SLAVE
## config.a_dir = RECEIVE
## config.b_dir = TRANSMIT
## 
## # Configure pins
## config.pin_config.fs = newPin(PORTE, 4)
## config.pin_config.mclk = newPin(PORTE, 2)
## config.pin_config.sck = newPin(PORTE, 5)
## config.pin_config.sa = newPin(PORTE, 6)
## config.pin_config.sb = newPin(PORTE, 3)
## 
## # Initialize SAI
## let result = sai.init(config)
## if result != SAI_OK:
##   # Handle error
##   discard
## 
## # Define audio callback
## proc audioCallback(inputBuf, outputBuf: ptr int32, size: csize_t) {.cdecl.} =
##   # Process audio samples
##   for i in 0..<size:
##     outputBuf[i] = inputBuf[i]  # Pass through
## 
## # Allocate DMA buffers (must be in DMA-capable memory)
## var rxBuffer: array[256, int32]
## var txBuffer: array[256, int32]
## 
## # Start DMA transfer
## discard sai.startDma(rxBuffer[0].addr, txBuffer[0].addr, 256, audioCallback)
## ```

import nimphea
export nimphea_core_types
import nimphea/nimphea_macros

# Use the macro system for this module's compilation unit
useNimpheaModules(sai)

{.push header: "per/sai.h".}

type
  # SaiHandle is defined in nimphea_core_types
  SaiConfig* {.importcpp: "daisy::SaiHandle::Config", bycopy.} = object
    periph* {.importcpp: "periph".}: SaiPeripheral
    pin_config* {.importcpp: "pin_config".}: SaiPinConfig
    sr* {.importcpp: "sr".}: SampleRate
    bit_depth* {.importcpp: "bit_depth".}: SaiBitDepth
    a_sync* {.importcpp: "a_sync".}: SaiSync
    b_sync* {.importcpp: "b_sync".}: SaiSync
    a_dir* {.importcpp: "a_dir".}: SaiDirection
    b_dir* {.importcpp: "b_dir".}: SaiDirection
  
  SaiPinConfig* {.importcpp: "daisy::SaiHandle::Config::pin_config", bycopy.} = object
    mclk* {.importcpp: "mclk".}: Pin
    fs* {.importcpp: "fs".}: Pin
    sck* {.importcpp: "sck".}: Pin
    sa* {.importcpp: "sa".}: Pin
    sb* {.importcpp: "sb".}: Pin
  
  SaiPeripheral* {.importcpp: "daisy::SaiHandle::Config::Peripheral", size: sizeof(cint).} = enum
    SAI_1
    SAI_2
  
  SaiBitDepth* {.importcpp: "daisy::SaiHandle::Config::BitDepth", size: sizeof(cint).} = enum
    SAI_16BIT
    SAI_24BIT
    SAI_32BIT
  
  SaiSync* {.importcpp: "daisy::SaiHandle::Config::Sync", size: sizeof(cint).} = enum
    MASTER
    SLAVE
  
  SaiDirection* {.importcpp: "daisy::SaiHandle::Config::Direction", size: sizeof(cint).} = enum
    TRANSMIT
    RECEIVE
  
  SaiResult* {.importcpp: "daisy::SaiHandle::Result", size: sizeof(cint).} = enum
    SAI_OK = 0
    SAI_ERR = 1
  
  # SAI callback type
  SaiCallback* = proc(inputBuf, outputBuf: ptr int32, size: csize_t) {.cdecl.}

# Bind-once C++ methods for SaiHandle
proc init*(sai: var SaiHandle, config: SaiConfig): SaiResult {.importcpp: "#.Init(@)".}
  ## Initialize the SAI peripheral with the given configuration
proc deinit*(sai: var SaiHandle): SaiResult {.importcpp: "#.DeInit()".}
  ## Deinitialize the SAI peripheral
proc getConfig*(sai: SaiHandle): SaiConfig {.importcpp: "#.GetConfig()".}
  ## Get the current configuration of the SAI peripheral

proc startDma*(sai: var SaiHandle, bufferRx, bufferTx: ptr int32, size: csize_t,
               callback: SaiCallback): SaiResult {.importcpp: "#.StartDma(@)".}
  ## Start DMA-based audio transfer in circular buffer mode
proc startDma*(sai: var SaiHandle, bufferRx, bufferTx: ptr int32, size: int,
               callback: SaiCallback): SaiResult {.inline.} =
  ## Start DMA-based audio transfer (retained: int -> csize_t overload).
  ## Buffers must be in DMA-capable memory.
  ##
  ## Example:
  ## ```nim
  ## var rxBuf: array[256, int32]
  ## var txBuf: array[256, int32]
  ## discard sai.startDma(rxBuf[0].addr, txBuf[0].addr, 256, audioCallback)
  ## ```
  sai.startDma(bufferRx, bufferTx, size.csize_t, callback)

proc stopDma*(sai: var SaiHandle): SaiResult {.importcpp: "#.StopDma()".}
  ## Stop the DMA audio transfer

proc getSampleRate*(sai: SaiHandle): cfloat {.importcpp: "#.GetSampleRate()".}
  ## Get the sample rate (Hz) based on the current configuration
proc getBlockSize*(sai: SaiHandle): csize_t {.importcpp: "#.GetBlockSize()".}
  ## Get the number of samples per audio block
proc getBlockRate*(sai: SaiHandle): cfloat {.importcpp: "#.GetBlockRate()".}
  ## Get the block rate (Hz) of the current stream
proc getOffset*(sai: SaiHandle): csize_t {.importcpp: "#.GetOffset()".}
  ## Get the current offset within the SAI buffer (0 or size/2)
proc isInitialized*(sai: SaiHandle): bool {.importcpp: "#.IsInitialized()".}
  ## Check if the SAI peripheral is initialized

# Constructors
proc newSaiConfig*(): SaiConfig {.importcpp: "daisy::SaiHandle::Config()", constructor.}

{.pop.} # header

# =============================================================================
# Helper Procedures
# =============================================================================

proc configurePinsStandard*(config: var SaiConfig, port: GPIOPort) =
  ## Configure SAI pins using a standard layout on a single GPIO port.
  ##
  ## This is a convenience function for common pin configurations.
  ##
  ## Standard pin layout (example for PORTE):
  ## - MCLK: port pin 2
  ## - FS:   port pin 4
  ## - SCK:  port pin 5
  ## - SA:   port pin 6
  ## - SB:   port pin 3
  ##
  ## Parameters:
  ##   config: SAI configuration to modify
  ##   port: GPIO port to use for all pins
  ##
  ## Example:
  ## ```nim
  ## var config = newSaiConfig()
  ## config.configurePinsStandard(PORTE)
  ## ```
  config.pin_config.mclk = newPin(port, 2)
  config.pin_config.fs = newPin(port, 4)
  config.pin_config.sck = newPin(port, 5)
  config.pin_config.sa = newPin(port, 6)
  config.pin_config.sb = newPin(port, 3)

proc configureStandard48k24bit*(config: var SaiConfig, peripheral: SaiPeripheral = SAI_1) =
  ## Configure SAI for standard 48kHz, 24-bit stereo audio.
  ##
  ## This sets up common defaults:
  ## - Sample rate: 48kHz
  ## - Bit depth: 24-bit
  ## - Block A: Master, Receive (input)
  ## - Block B: Slave, Transmit (output)
  ##
  ## **Note**: You still need to configure pins separately.
  ##
  ## Parameters:
  ##   config: SAI configuration to modify
  ##   peripheral: SAI peripheral to use (default: SAI_1)
  ##
  ## Example:
  ## ```nim
  ## var config = newSaiConfig()
  ## config.configureStandard48k24bit()
  ## config.configurePinsStandard(PORTE)
  ## ```
  config.periph = peripheral
  config.sr = SAI_48KHZ
  config.bit_depth = SAI_24BIT
  config.a_sync = MASTER
  config.b_sync = SLAVE
  config.a_dir = RECEIVE
  config.b_dir = TRANSMIT

when isMainModule:
  echo "libDaisy SAI wrapper - Serial Audio Interface support"
