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

# Use the macro system for this module's compilation unit

{.push header: "per/sai.h".}

type
  # SaiHandle is defined in nimphea_core_types
  SaiConfigRaw* {.importcpp: "daisy::SaiHandle::Config", bycopy.} = object
    periph* {.importcpp: "periph".}: SaiPeripheral
    pin_config* {.importcpp: "pin_config".}: SaiPinConfig
    sr* {.importcpp: "sr".}: SampleRate
    bit_depth* {.importcpp: "bit_depth".}: SaiBitDepth
    a_sync* {.importcpp: "a_sync".}: SaiSync
    b_sync* {.importcpp: "b_sync".}: SaiSync
    a_dir* {.importcpp: "a_dir".}: SaiDirection
    b_dir* {.importcpp: "b_dir".}: SaiDirection
  
  SaiPinConfig* {.importcpp: "decltype(daisy::SaiHandle::Config{}.pin_config)", bycopy.} = object
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
proc initRaw(sai: var SaiHandleRaw, config: SaiConfigRaw): SaiResult {.importcpp: "#.Init(@)".}
  ## Initialize the SAI peripheral with the given configuration
proc deinitRaw(sai: var SaiHandleRaw): SaiResult {.importcpp: "#.DeInit()".}
  ## Deinitialize the SAI peripheral
proc getConfigRaw(sai: SaiHandleRaw): SaiConfigRaw {.importcpp: "#.GetConfig()".}
  ## Get the current configuration of the SAI peripheral

proc startDmaRaw(sai: var SaiHandleRaw, bufferRx, bufferTx: ptr int32, size: csize_t,
               callback: SaiCallback): SaiResult {.importcpp: "#.StartDma(@)".}
  ## Start DMA-based audio transfer in circular buffer mode
proc startDmaRaw(sai: var SaiHandleRaw, bufferRx, bufferTx: ptr int32, size: int,
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
  sai.startDmaRaw(bufferRx, bufferTx, size.csize_t, callback)

proc stopDmaRaw(sai: var SaiHandleRaw): SaiResult {.importcpp: "#.StopDma()".}
  ## Stop the DMA audio transfer

proc getSampleRateRaw(sai: SaiHandleRaw): cfloat {.importcpp: "#.GetSampleRate()".}
  ## Get the sample rate (Hz) based on the current configuration
proc getBlockSizeRaw(sai: SaiHandleRaw): csize_t {.importcpp: "#.GetBlockSize()".}
  ## Get the number of samples per audio block
proc getBlockRateRaw(sai: SaiHandleRaw): cfloat {.importcpp: "#.GetBlockRate()".}
  ## Get the block rate (Hz) of the current stream
proc getOffsetRaw(sai: SaiHandleRaw): csize_t {.importcpp: "#.GetOffset()".}
  ## Get the current offset within the SAI buffer (0 or size/2)
proc isInitializedRaw(sai: SaiHandleRaw): bool {.importcpp: "#.IsInitialized()".}
  ## Check if the SAI peripheral is initialized

# Constructors
proc newSaiHandleRaw(): SaiHandleRaw {.importcpp: "daisy::SaiHandle()", constructor, header: "per/sai.h".}
proc newSaiConfigRaw(): SaiConfigRaw {.importcpp: "daisy::SaiHandle::Config()", constructor, header: "per/sai.h".}

{.pop.} # header

# =============================================================================
# Helper Procedures
# =============================================================================

# =============================================================================
# Static-peripheral API (the SAI block is part of the type)
# =============================================================================

type
  SaiHandle*[P: static SaiPeripheral] = object
    ## SAI handle bound to a specific block at compile time.
    raw: SaiHandleRaw

  SaiConfig*[P: static SaiPeripheral] = object
    ## SAI configuration bound to the same block as its handle.
    ## The block itself is implied by `P`; only the transport settings
    ## below are user-controlled.
    raw: SaiConfigRaw

proc pinConfig*[P: static SaiPeripheral](c: SaiConfig[P]): SaiPinConfig {.inline.} =
  c.raw.pin_config

proc pinConfig*[P: static SaiPeripheral](c: var SaiConfig[P]): var SaiPinConfig {.inline.} =
  c.raw.pin_config

proc sampleRate*[P: static SaiPeripheral](c: SaiConfig[P]): SampleRate {.inline.} =
  c.raw.sr

proc sampleRate*[P: static SaiPeripheral](c: var SaiConfig[P]): var SampleRate {.inline.} =
  c.raw.sr

proc bitDepth*[P: static SaiPeripheral](c: SaiConfig[P]): SaiBitDepth {.inline.} =
  c.raw.bit_depth

proc bitDepth*[P: static SaiPeripheral](c: var SaiConfig[P]): var SaiBitDepth {.inline.} =
  c.raw.bit_depth

proc aSync*[P: static SaiPeripheral](c: SaiConfig[P]): SaiSync {.inline.} =
  c.raw.a_sync

proc aSync*[P: static SaiPeripheral](c: var SaiConfig[P]): var SaiSync {.inline.} =
  c.raw.a_sync

proc bSync*[P: static SaiPeripheral](c: SaiConfig[P]): SaiSync {.inline.} =
  c.raw.b_sync

proc bSync*[P: static SaiPeripheral](c: var SaiConfig[P]): var SaiSync {.inline.} =
  c.raw.b_sync

proc aDir*[P: static SaiPeripheral](c: SaiConfig[P]): SaiDirection {.inline.} =
  c.raw.a_dir

proc aDir*[P: static SaiPeripheral](c: var SaiConfig[P]): var SaiDirection {.inline.} =
  c.raw.a_dir

proc bDir*[P: static SaiPeripheral](c: SaiConfig[P]): SaiDirection {.inline.} =
  c.raw.b_dir

proc bDir*[P: static SaiPeripheral](c: var SaiConfig[P]): var SaiDirection {.inline.} =
  c.raw.b_dir

proc newSaiHandle*[P: static SaiPeripheral](): SaiHandle[P] {.inline.} =
  result = SaiHandle[P](raw: newSaiHandleRaw())

proc newSaiConfig*[P: static SaiPeripheral](): SaiConfig[P] {.inline.} =
  result = SaiConfig[P](raw: newSaiConfigRaw())

proc init*[P: static SaiPeripheral](sai: var SaiHandle[P], config: SaiConfig[P]): SaiResult =
  ## Initialize the SAI interface for the block encoded in `P`.
  var cfg = config.raw
  cfg.periph = P
  result = sai.raw.initRaw(cfg)

proc deinit*[P: static SaiPeripheral](sai: var SaiHandle[P]): SaiResult {.inline.} =
  sai.raw.deinitRaw()

proc getConfig*[P: static SaiPeripheral](sai: SaiHandle[P]): SaiConfig[P] {.inline.} =
  result.raw = sai.raw.getConfigRaw()

proc startDma*[P: static SaiPeripheral](sai: var SaiHandle[P], bufferRx, bufferTx: ptr int32,
                                        size: csize_t, callback: SaiCallback): SaiResult {.inline.} =
  sai.raw.startDmaRaw(bufferRx, bufferTx, size, callback)

proc startDma*[P: static SaiPeripheral](sai: var SaiHandle[P], bufferRx, bufferTx: ptr int32,
                                        size: int, callback: SaiCallback): SaiResult {.inline.} =
  sai.raw.startDmaRaw(bufferRx, bufferTx, size, callback)

proc stopDma*[P: static SaiPeripheral](sai: var SaiHandle[P]): SaiResult {.inline.} =
  sai.raw.stopDmaRaw()

proc getSampleRate*[P: static SaiPeripheral](sai: SaiHandle[P]): cfloat {.inline.} =
  sai.raw.getSampleRateRaw()

proc getBlockSize*[P: static SaiPeripheral](sai: SaiHandle[P]): csize_t {.inline.} =
  sai.raw.getBlockSizeRaw()

proc getBlockRate*[P: static SaiPeripheral](sai: SaiHandle[P]): cfloat {.inline.} =
  sai.raw.getBlockRateRaw()

proc getOffset*[P: static SaiPeripheral](sai: SaiHandle[P]): csize_t {.inline.} =
  sai.raw.getOffsetRaw()

proc isInitialized*[P: static SaiPeripheral](sai: SaiHandle[P]): bool {.inline.} =
  sai.raw.isInitializedRaw()

proc configurePinsStandard*[P: static SaiPeripheral](config: var SaiConfig[P], port: GPIOPort) =
  ## Configure SAI pins on the given GPIO port for the standard pinout.
  config.pinConfig.mclk = newPin(port, 2)
  config.pinConfig.fs = newPin(port, 4)
  config.pinConfig.sck = newPin(port, 5)
  config.pinConfig.sa = newPin(port, 6)
  config.pinConfig.sb = newPin(port, 3)

proc configureStandard48k24bit*[P: static SaiPeripheral](config: var SaiConfig[P]) =
  ## Configure SAI for 48 kHz 24-bit audio (the block is `P`).
  config.sampleRate = SAI_48KHZ
  config.bitDepth = SAI_24BIT
  config.aSync = MASTER
  config.bSync = MASTER
  config.aDir = TRANSMIT
  config.bDir = RECEIVE
