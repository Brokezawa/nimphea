## SPI (Serial Peripheral Interface) support for libDaisy Nim wrapper
##
## This module provides SPI communication support for the Daisy Audio Platform.
##
## ⚠️ **IMPORTANT - Blocking vs DMA Functions:**
##
## - **Blocking functions** (`write`, `read`, `transfer`) will stall the CPU while waiting
##   for the SPI transaction to complete. This can cause **audio glitches** if called from
##   the audio callback or main loop during audio processing.
##
## - **DMA functions** (`dmaTransmit`, `dmaReceive`, `dmaTransmitAndReceive`) use Direct
##   Memory Access to transfer data in the background without blocking the CPU. These are
##   **safe to use during audio processing** if your buffers are in the correct memory region.
##
## **DMA Buffer Requirements:**
## - Buffers must be in D2 memory domain (not stack variables!)
## - Use `{.section: ".sram1_bss".}` or allocate on heap
## - Or use `dsy_dma_clear_cache_for_buffer()` before transfer (advanced)
##
## Example - Simple SPI master (blocking):
## ```nim
## import nimphea, per/spi
##
## var daisy = initDaisy()
## var spi = initSPI(SPI_1, D8, D9, D10)
##
## # Write bytes (BLOCKS - don't use in audio callback!)
## discard spi.write([0x01'u8, 0x02, 0x03, 0x04])
##
## # Read bytes (BLOCKS)
## var buffer: array[4, uint8]
## discard spi.read(buffer)
##
## # Full-duplex transfer (BLOCKS)
## let txData = [0xAA'u8, 0xBB, 0xCC]
## var rxData: array[3, uint8]
## discard spi.transfer(txData, rxData)
## ```
##
## Example - SPI with register access (blocking):
## ```nim
## # Write to register (BLOCKS)
## discard spi.writeRegister(0x20, 0xFF)
##
## # Read from register (BLOCKS)
## let (result, value) = spi.readRegister(0x21)
## ```
##
## Example - Non-blocking DMA transfer:
## ```nim
## import nimphea, per/spi
##
## # DMA buffers MUST be in D2 memory, not on stack!
## var txBuffer {.section: ".sram1_bss".}: array[256, uint8]
## var transferComplete = false
##
## proc onTransferComplete(context: pointer, result: SpiResult) {.cdecl.} =
##   # Called from interrupt - keep this FAST!
##   transferComplete = true
##
## var daisy = initDaisy()
## var spi = initSPI(SPI_1, D8, D9, D10)
##
## # Start DMA transfer (non-blocking)
## discard spi.dmaTransmit(txBuffer, nil, onTransferComplete, nil)
##
## # CPU is free to do other work while transfer happens in background
## while not transferComplete:
##   # Do audio processing or other tasks
##   discard
## ```

# Import libdaisy which provides the macro system
import nimphea
export nimphea_core_types

# Use the macro system for this module's compilation unit

{.push header: "daisy_seed.h".}

type
  # SPI callback function pointers
  SpiStartCallbackFunctionPtr* = proc(context: pointer) {.cdecl.}
  SpiEndCallbackFunctionPtr* = proc(context: pointer, result: SpiResult) {.cdecl.}

# =============================================================================
# SpiHandle (bind-once)
# =============================================================================
proc initRaw(spi: var SpiHandleRaw, config: SpiConfigRaw): SpiResult {.importcpp: "#.Init(@)".}
proc getConfigRaw(spi: SpiHandleRaw): SpiConfigRaw {.importcpp: "#.GetConfig()".}

proc blockingTransmitRaw(spi: var SpiHandleRaw, buff: ptr uint8, size: csize_t,
                          timeout: uint32 = 100): SpiResult {.importcpp: "#.BlockingTransmit(@)".}
  ## Blocking transmit of `size` bytes

proc blockingReceiveRaw(spi: var SpiHandleRaw, buffer: ptr uint8, size: uint16,
                         timeout: uint32 = 100): SpiResult {.importcpp: "#.BlockingReceive(@)".}
  ## Blocking receive of `size` bytes

proc blockingTransmitAndReceiveRaw(spi: var SpiHandleRaw, tx_buff: ptr uint8, rx_buff: ptr uint8,
                                    size: csize_t, timeout: uint32 = 100): SpiResult {.importcpp: "#.BlockingTransmitAndReceive(@)".}
  ## Blocking full-duplex transfer of `size` bytes

proc dmaTransmitRaw(spi: var SpiHandleRaw, buff: ptr uint8, size: csize_t,
                     start_callback: SpiStartCallbackFunctionPtr,
                     end_callback: SpiEndCallbackFunctionPtr,
                     callback_context: pointer): SpiResult {.importcpp: "#.DmaTransmit(@)".}
  ## Non-blocking DMA transmit into a D2-memory buffer

proc dmaReceiveRaw(spi: var SpiHandleRaw, buff: ptr uint8, size: csize_t,
                    start_callback: SpiStartCallbackFunctionPtr,
                    end_callback: SpiEndCallbackFunctionPtr,
                    callback_context: pointer): SpiResult {.importcpp: "#.DmaReceive(@)".}
  ## Non-blocking DMA receive into a D2-memory buffer

proc dmaTransmitAndReceiveRaw(spi: var SpiHandleRaw, tx_buff: ptr uint8, rx_buff: ptr uint8,
                               size: csize_t,
                               start_callback: SpiStartCallbackFunctionPtr,
                               end_callback: SpiEndCallbackFunctionPtr,
                               callback_context: pointer): SpiResult {.importcpp: "#.DmaTransmitAndReceive(@)".}
  ## Non-blocking DMA full-duplex transfer between two D2-memory buffers

{.pop.} # header

# C++ constructor
proc newSpiHandleRaw(): SpiHandleRaw {.importcpp: "daisy::SpiHandle()", constructor, header: "daisy_seed.h".}

# =============================================================================
# Value-adding helpers
# =============================================================================

# Static-peripheral API (the bus is part of the type)
type
  SpiHandle*[P: static SpiPeripheral] = object
    ## SPI handle bound to a specific peripheral at compile time.
    ## Mismatched bus/driver pairings are type errors.
    raw: SpiHandleRaw

  SpiConfig*[P: static SpiPeripheral] = object
    ## SPI configuration bound to the same peripheral as its handle.
    ## The peripheral is implied by `P`; only the transport settings
    ## below are user-controlled.
    raw: SpiConfigRaw

# --- SpiConfig field accessors (the raw struct stays private) ---------------

proc pinConfig*[P: static SpiPeripheral](c: SpiConfig[P]): SpiPinConfig {.inline.} =
  c.raw.pin_config

proc pinConfig*[P: static SpiPeripheral](c: var SpiConfig[P]): var SpiPinConfig {.inline.} =
  c.raw.pin_config

proc mode*[P: static SpiPeripheral](c: SpiConfig[P]): SpiMode {.inline.} =
  c.raw.mode

proc mode*[P: static SpiPeripheral](c: var SpiConfig[P]): var SpiMode {.inline.} =
  c.raw.mode

proc direction*[P: static SpiPeripheral](c: SpiConfig[P]): SpiDirection {.inline.} =
  c.raw.direction

proc direction*[P: static SpiPeripheral](c: var SpiConfig[P]): var SpiDirection {.inline.} =
  c.raw.direction

proc dataSize*[P: static SpiPeripheral](c: SpiConfig[P]): culong {.inline.} =
  c.raw.datasize

proc dataSize*[P: static SpiPeripheral](c: var SpiConfig[P]): var culong {.inline.} =
  c.raw.datasize

proc nss*[P: static SpiPeripheral](c: SpiConfig[P]): SpiNss {.inline.} =
  c.raw.nss

proc nss*[P: static SpiPeripheral](c: var SpiConfig[P]): var SpiNss {.inline.} =
  c.raw.nss

proc baudPrescaler*[P: static SpiPeripheral](c: SpiConfig[P]): SpiBaudPrescaler {.inline.} =
  c.raw.baud_prescaler

proc baudPrescaler*[P: static SpiPeripheral](c: var SpiConfig[P]): var SpiBaudPrescaler {.inline.} =
  c.raw.baud_prescaler

proc clockPolarity*[P: static SpiPeripheral](c: SpiConfig[P]): SpiClockPolarity {.inline.} =
  c.raw.clock_polarity

proc clockPolarity*[P: static SpiPeripheral](c: var SpiConfig[P]): var SpiClockPolarity {.inline.} =
  c.raw.clock_polarity

proc clockPhase*[P: static SpiPeripheral](c: SpiConfig[P]): SpiClockPhase {.inline.} =
  c.raw.clock_phase

proc clockPhase*[P: static SpiPeripheral](c: var SpiConfig[P]): var SpiClockPhase {.inline.} =
  c.raw.clock_phase

# --- Handle lifecycle --------------------------------------------------------

proc init*[P: static SpiPeripheral](spi: var SpiHandle[P], config: SpiConfig[P]): SpiResult =
  ## Initialize the SPI interface for the peripheral encoded in `P`.
  ## The peripheral is taken from the static parameter — a config built
  ## for another bus cannot be passed here (compile error).
  var cfg = config.raw
  cfg.periph = P
  result = spi.raw.initRaw(cfg)

proc getConfig*[P: static SpiPeripheral](spi: SpiHandle[P]): SpiConfig[P] {.inline.} =
  result.raw = spi.raw.getConfigRaw()

# --- Low-level transfers (ptr forms, e.g. for D2-memory DMA buffers) ---------

proc blockingTransmit*[P: static SpiPeripheral](spi: var SpiHandle[P], buff: ptr uint8,
                                                size: csize_t, timeout: uint32 = 100): SpiResult {.inline.} =
  spi.raw.blockingTransmitRaw(buff, size, timeout)

proc blockingReceive*[P: static SpiPeripheral](spi: var SpiHandle[P], buffer: ptr uint8,
                                               size: uint16, timeout: uint32 = 100): SpiResult {.inline.} =
  spi.raw.blockingReceiveRaw(buffer, size, timeout)

proc blockingTransmitAndReceive*[P: static SpiPeripheral](spi: var SpiHandle[P], tx_buff: ptr uint8,
                                                          rx_buff: ptr uint8, size: csize_t,
                                                          timeout: uint32 = 100): SpiResult {.inline.} =
  spi.raw.blockingTransmitAndReceiveRaw(tx_buff, rx_buff, size, timeout)

proc dmaTransmit*[P: static SpiPeripheral](spi: var SpiHandle[P], buff: ptr uint8, size: csize_t,
                                           start_callback: SpiStartCallbackFunctionPtr,
                                           end_callback: SpiEndCallbackFunctionPtr,
                                           callback_context: pointer): SpiResult {.inline.} =
  spi.raw.dmaTransmitRaw(buff, size, start_callback, end_callback, callback_context)

proc dmaReceive*[P: static SpiPeripheral](spi: var SpiHandle[P], buff: ptr uint8, size: csize_t,
                                          start_callback: SpiStartCallbackFunctionPtr,
                                          end_callback: SpiEndCallbackFunctionPtr,
                                          callback_context: pointer): SpiResult {.inline.} =
  spi.raw.dmaReceiveRaw(buff, size, start_callback, end_callback, callback_context)

proc dmaTransmitAndReceive*[P: static SpiPeripheral](spi: var SpiHandle[P], tx_buff: ptr uint8,
                                                     rx_buff: ptr uint8, size: csize_t,
                                                     start_callback: SpiStartCallbackFunctionPtr,
                                                     end_callback: SpiEndCallbackFunctionPtr,
                                                     callback_context: pointer): SpiResult {.inline.} =
  spi.raw.dmaTransmitAndReceiveRaw(tx_buff, rx_buff, size, start_callback, end_callback, callback_context)

proc initSPI*[P: static SpiPeripheral](sclkPin, misoPin, mosiPin: Pin,
                                       nssPin: Pin = Pin(), speed: SpiBaudPrescaler = SPI_PS_8,
                                       mode: int = 0): SpiHandle[P] =
  ## Initialize the SPI interface bound to the peripheral encoded in `P`
  ## (retained: config assembly + mode mapping).
  ##
  ## Parameters:
  ##   sclkPin: Clock pin (e.g., D8)
  ##   misoPin: Master In Slave Out pin
  ##   mosiPin: Master Out Slave In pin
  ##   nssPin: Chip select pin (optional, use Pin() for software CS)
  ##   speed: Clock prescaler (SPI_PS_2 to SPI_PS_256)
  ##   mode: SPI mode 0-3 (sets clock polarity and phase)
  ##
  ## Example:
  ## ```nim
  ## var spi = initSPI[SPI_1](D8, D9, D10)
  ## ```
  result = SpiHandle[P](raw: newSpiHandleRaw())
  var config: SpiConfig[P]
  config.mode = SPI_MASTER
  config.direction = SPI_TWO_LINES
  config.dataSize = 8
  config.nss = if nssPin.port == PORTX: SPI_NSS_SOFT else: SPI_NSS_HARD_OUTPUT
  config.baudPrescaler = speed
  config.pinConfig.sclk = sclkPin
  config.pinConfig.miso = misoPin
  config.pinConfig.mosi = mosiPin
  config.pinConfig.nss = nssPin

  # Set SPI mode (0-3)
  case mode
  of 0:
    config.clockPolarity = SPI_CLOCK_POL_LOW
    config.clockPhase = SPI_CLOCK_PHASE_1
  of 1:
    config.clockPolarity = SPI_CLOCK_POL_LOW
    config.clockPhase = SPI_CLOCK_PHASE_2
  of 2:
    config.clockPolarity = SPI_CLOCK_POL_HIGH
    config.clockPhase = SPI_CLOCK_PHASE_1
  of 3:
    config.clockPolarity = SPI_CLOCK_POL_HIGH
    config.clockPhase = SPI_CLOCK_PHASE_2
  else: discard

  discard result.init(config)

proc transfer*[P: static SpiPeripheral](spi: var SpiHandle[P], txData: openArray[uint8],
               rxBuffer: var openArray[uint8], timeout: uint32 = 100): SpiResult {.inline.} =
  ## Full-duplex transfer (transmit and receive simultaneously).
  ## txData and rxBuffer must be the same length.
  if txData.len != rxBuffer.len:
    return SPI_ERR
  if txData.len > 0:
    result = spi.blockingTransmitAndReceive(addr txData[0], addr rxBuffer[0], csize_t(txData.len), timeout)
  else:
    result = SPI_OK

proc write*[P: static SpiPeripheral](spi: var SpiHandle[P], data: openArray[uint8], timeout: uint32 = 100): SpiResult {.inline.} =
  ## Write data via SPI (openArray wrapper with empty guard).
  if data.len > 0:
    result = spi.blockingTransmit(addr data[0], csize_t(data.len), timeout)
  else:
    result = SPI_OK

proc read*[P: static SpiPeripheral](spi: var SpiHandle[P], buffer: var openArray[uint8], timeout: uint32 = 100): SpiResult {.inline.} =
  ## Read data via SPI into the provided buffer (openArray wrapper with empty guard).
  if buffer.len > 0:
    result = spi.blockingReceive(addr buffer[0], uint16(buffer.len), timeout)
  else:
    result = SPI_OK

proc writeByte*[P: static SpiPeripheral](spi: var SpiHandle[P], data: uint8, timeout: uint32 = 100): SpiResult {.inline.} =
  ## Write a single byte.
  var b = data
  result = spi.blockingTransmit(addr b, 1, timeout)

proc readByte*[P: static SpiPeripheral](spi: var SpiHandle[P], timeout: uint32 = 100): tuple[result: SpiResult, data: uint8] {.inline.} =
  ## Read a single byte.
  result.data = 0
  result.result = spi.blockingReceive(addr result.data, 1, timeout)

proc transferByte*[P: static SpiPeripheral](spi: var SpiHandle[P], txByte: uint8, timeout: uint32 = 100): tuple[result: SpiResult, rxByte: uint8] {.inline.} =
  ## Transfer a single byte (full duplex).
  var tx = txByte
  result.rxByte = 0
  result.result = spi.blockingTransmitAndReceive(addr tx, addr result.rxByte, 1, timeout)

proc writeRegister*[P: static SpiPeripheral](spi: var SpiHandle[P], regAddr: uint8, value: uint8,
                    timeout: uint32 = 100): SpiResult =
  ## Write to a register (common SPI device pattern).
  var data: array[2, uint8] = [regAddr, value]
  result = spi.blockingTransmit(addr data[0], 2, timeout)

proc readRegister*[P: static SpiPeripheral](spi: var SpiHandle[P], regAddr: uint8,
                   timeout: uint32 = 100): tuple[result: SpiResult, value: uint8] =
  ## Read from a register.
  var txData: array[2, uint8] = [regAddr, 0x00]
  var rxData: array[2, uint8]
  result.result = spi.blockingTransmitAndReceive(addr txData[0], addr rxData[0], 2, timeout)
  result.value = rxData[1]

proc readRegisters*[P: static SpiPeripheral](spi: var SpiHandle[P], regAddr: uint8, buffer: var openArray[uint8],
                    timeout: uint32 = 100): SpiResult =
  ## Read multiple bytes from consecutive registers into the provided buffer.
  let count = buffer.len
  if count == 0:
    return SPI_OK

  var txData: array[256, uint8]  # Max SPI transfer size
  if count >= 256:
    return SPI_ERR

  txData[0] = regAddr
  var rxData: array[256, uint8]

  result = spi.blockingTransmitAndReceive(
    addr txData[0],
    addr rxData[0],
    csize_t(count + 1),
    timeout
  )

  if result == SPI_OK:
    for i in 0..<count:
      buffer[i] = rxData[i + 1]

# =============================================================================
# DMA (Non-Blocking) API
# =============================================================================

proc dmaTransmit*[P: static SpiPeripheral](spi: var SpiHandle[P],
                  buffer: var openArray[uint8],
                  startCallback: SpiStartCallbackFunctionPtr = nil,
                  endCallback: SpiEndCallbackFunctionPtr = nil,
                  context: pointer = nil): SpiResult =
  ## Non-blocking DMA transmit (openArray wrapper over `dmaTransmit` binding).
  ##
  ## ⚠️ **CRITICAL:** Buffer MUST be in D2 memory domain:
  ## - Use `{.section: ".sram1_bss".}` pragma on buffer declaration
  ## - Or allocate on heap with alloc/create
  ## - **DO NOT use stack variables** (will cause DMA errors)
  ##
  ## Returns SPI_OK if the transfer was queued successfully, SPI_ERR on error.
  ##
  ## Example:
  ## ```nim
  ## var txBuf {.section: ".sram1_bss".}: array[256, uint8]
  ##
  ## proc onComplete(ctx: pointer, res: SpiResult) {.cdecl.} =
  ##   echo "Transfer done!"
  ##
  ## discard spi.dmaTransmit(txBuf, nil, onComplete, nil)
  ## ```
  if buffer.len > 0:
    result = spi.dmaTransmit(addr buffer[0], csize_t(buffer.len),
                             startCallback, endCallback, context)
  else:
    result = SPI_OK

proc dmaReceive*[P: static SpiPeripheral](spi: var SpiHandle[P],
                 buffer: var openArray[uint8],
                 startCallback: SpiStartCallbackFunctionPtr = nil,
                 endCallback: SpiEndCallbackFunctionPtr = nil,
                 context: pointer = nil): SpiResult =
  ## Non-blocking DMA receive (openArray wrapper over `dmaReceive` binding).
  ##
  ## ⚠️ **CRITICAL:** Buffer MUST be in D2 memory domain. **DO NOT use stack.**
  ##
  ## Example:
  ## ```nim
  ## var rxBuf {.section: ".sram1_bss".}: array[256, uint8]
  ##
  ## proc onComplete(ctx: pointer, res: SpiResult) {.cdecl.} =
  ##   # Process received data
  ##   discard
  ##
  ## discard spi.dmaReceive(rxBuf, nil, onComplete, nil)
  ## ```
  if buffer.len > 0:
    result = spi.dmaReceive(addr buffer[0], csize_t(buffer.len),
                            startCallback, endCallback, context)
  else:
    result = SPI_OK

proc dmaTransmitAndReceive*[P: static SpiPeripheral](spi: var SpiHandle[P],
                            txBuffer: var openArray[uint8],
                            rxBuffer: var openArray[uint8],
                            startCallback: SpiStartCallbackFunctionPtr = nil,
                            endCallback: SpiEndCallbackFunctionPtr = nil,
                            context: pointer = nil): SpiResult =
  ## Non-blocking DMA full-duplex transfer (openArray wrapper over the binding).
  ##
  ## ⚠️ **CRITICAL:** Both buffers MUST be in D2 memory domain. **DO NOT use stack.**
  ## txBuffer and rxBuffer must be the same length.
  ##
  ## Example:
  ## ```nim
  ## var txBuf {.section: ".sram1_bss".}: array[256, uint8]
  ## var rxBuf {.section: ".sram1_bss".}: array[256, uint8]
  ##
  ## proc onComplete(ctx: pointer, res: SpiResult) {.cdecl.} =
  ##   # Transfer complete, process rxBuf
  ##   discard
  ##
  ## discard spi.dmaTransmitAndReceive(txBuf, rxBuf, nil, onComplete, nil)
  ## ```
  if txBuffer.len != rxBuffer.len:
    return SPI_ERR
  if txBuffer.len > 0:
    result = spi.dmaTransmitAndReceive(addr txBuffer[0], addr rxBuffer[0],
                                       csize_t(txBuffer.len),
                                       startCallback, endCallback, context)
  else:
    result = SPI_OK

when isMainModule:
  echo "libDaisy SPI wrapper - Clean API"
