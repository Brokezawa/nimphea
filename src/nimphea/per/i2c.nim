## I2C support for libDaisy Nim wrapper
##
## This module provides I2C (Inter-Integrated Circuit) communication support
## for the Daisy Audio Platform. It supports both master and slave modes,
## blocking and DMA transfers.
##
## The I2C peripheral is part of the type: `I2cHandle[I2C_1]` is a handcrafted
## handle for bus 1 — passing it to a driver configured for another bus is a
## compile-time error. The peripheral is set from the static parameter when
## the bus is initialized, so the runtime `periph` field no longer exists.
##
## **IMPORTANT - Blocking vs DMA Functions:**
##
## - **Blocking functions** (`write`, `read`, `writeRegister`, `readRegister`) will stall
##   the CPU while waiting for the I2C transaction to complete. This can cause **audio glitches**
##   if called from the audio callback or main loop during audio processing.
##
## - **DMA functions** (`transmitDma`, `receiveDma`) use Direct Memory Access to transfer
##   data in the background without blocking the CPU. These are **safe to use during audio
##   processing** if your buffers are in the correct memory region.
##
## **DMA Buffer Requirements:**
## - Buffers must be in D2 memory domain (not stack variables!)
## - Use `{.section: ".sram1_bss".}` or allocate on heap
## - Or use `dsy_dma_clear_cache_for_buffer()` before transfer (advanced)
##
## **DMA Availability:**
## - I2C1, I2C2, I2C3: Share a single DMA channel (only one can use DMA at a time)
## - I2C4: No DMA support (use blocking functions only)
##
## Example - Simple I2C master (blocking):
## ```nim
## import nimphea, per/i2c, per/uart
##
## var daisy = initDaisy()
## var i2c = initI2C[I2C_1](D11(), D12(), I2C_400KHZ)
##
## startLog()
##
## # Scan for devices (BLOCKS - don't use in audio callback!)
## var foundDevices: array[112, uint8]
## let count = i2c.scan(foundDevices)
## print("Found ")
## print(count)
## printLine(" devices")
##
## # Write to device (BLOCKS)
## var txData = [0x01'u8, 0xFF]
## if i2c.write(0x48, txData) == I2C_OK:
##   printLine("Write OK")
##
## # Read from device (BLOCKS)
## var rxData: array[4, uint8]
## if i2c.read(0x48, rxData) == I2C_OK:
##   printLine("Read OK")
## ```
##
## Example - Register access (blocking):
## ```nim
## # Write to register (BLOCKS)
## discard i2c.writeRegister(0x3C, 0x00, 0xAF)
##
## # Read from register (BLOCKS)
## let (result, value) = i2c.readRegister(0x3C, 0x01)
## ```
##
## Example - Non-blocking DMA transfer:
## ```nim
## import nimphea, per/i2c
##
## # DMA buffers MUST be in D2 memory, not on stack!
## var txBuffer {.section: ".sram1_bss".}: array[64, uint8]
## var transferComplete = false
##
## proc onTransferComplete(context: pointer, result: I2CResult) {.cdecl.} =
##   # Called from interrupt - keep this FAST!
##   transferComplete = true
##
## var daisy = initDaisy()
## var i2c = initI2C[I2C_1](D11(), D12(), I2C_400KHZ)
##
## # Start DMA transfer (non-blocking)
## discard i2c.transmitDma(0x48, txBuffer, onTransferComplete, nil)
##
## # CPU is free to do other work while transfer happens in background
## while not transferComplete:
##   # Do audio processing or other tasks
##   discard
## ```

# Import libdaisy which provides the macro system
import nimphea
export nimphea_core_types

{.push header: "per/i2c.h".}

type
  # I2C callback function pointer
  I2CCallbackFunctionPtr* = proc(context: pointer, result: I2CResult) {.cdecl.}

# Low-level C++ interface (bind-once, private — the wrappers own these)
proc init(i2c: var I2CHandleRaw, config: I2CConfigRaw): I2CResult {.importcpp: "#.Init(@)".}
proc getConfig(i2c: I2CHandleRaw): I2CConfigRaw {.importcpp: "#.GetConfig()".}

proc blockingTransmit(i2c: var I2CHandleRaw, address: uint16, data: ptr uint8,
                      size: uint16, timeout: uint32): I2CResult {.importcpp: "#.TransmitBlocking(@)".}
proc blockingReceive(i2c: var I2CHandleRaw, address: uint16, data: ptr uint8,
                     size: uint16, timeout: uint32): I2CResult {.importcpp: "#.ReceiveBlocking(@)".}
proc dmaTransmit(i2c: var I2CHandleRaw, address: uint16, data: ptr uint8, size: uint16,
                 callback: I2CCallbackFunctionPtr, callback_context: pointer): I2CResult {.importcpp: "#.TransmitDma(@)".}
proc dmaReceive(i2c: var I2CHandleRaw, address: uint16, data: ptr uint8, size: uint16,
                callback: I2CCallbackFunctionPtr, callback_context: pointer): I2CResult {.importcpp: "#.ReceiveDma(@)".}
proc readDataAtAddress(i2c: var I2CHandleRaw, address: uint16, mem_address: uint16,
                       mem_address_size: uint16, data: ptr uint8, data_size: uint16,
                       timeout: uint32): I2CResult {.importcpp: "#.ReadDataAtAddress(@)".}
proc writeDataAtAddress(i2c: var I2CHandleRaw, address: uint16, mem_address: uint16,
                        mem_address_size: uint16, data: ptr uint8, data_size: uint16,
                        timeout: uint32): I2CResult {.importcpp: "#.WriteDataAtAddress(@)".}

{.pop.} # header

# C++ constructor for the raw handle (private)
proc newI2CHandleRaw(): I2CHandleRaw {.importcpp: "daisy::I2CHandle()", constructor, header: "per/i2c.h".}

# =============================================================================
# Static-peripheral API (the bus is part of the type)
# =============================================================================

type
  I2cHandle*[P: static I2CPeripheral] = object
    ## I2C handle bound to a specific peripheral at compile time.
    ## Mismatched bus/driver pairings are type errors.
    raw: I2CHandleRaw

  I2cConfig*[P: static I2CPeripheral] = object
    ## I2C configuration bound to the same peripheral as its handle.
    ## The peripheral itself is implied by `P`; only the transport
    ## settings below are user-controlled.
    raw: I2CConfigRaw

# --- I2cConfig field accessors (the raw struct stays private) ----------------

proc pinConfig*[P: static I2CPeripheral](c: I2cConfig[P]): I2CPinConfig {.inline.} =
  c.raw.pin_config

proc pinConfig*[P: static I2CPeripheral](c: var I2cConfig[P]): var I2CPinConfig {.inline.} =
  c.raw.pin_config

proc speed*[P: static I2CPeripheral](c: I2cConfig[P]): I2CSpeed {.inline.} =
  c.raw.speed

proc speed*[P: static I2CPeripheral](c: var I2cConfig[P]): var I2CSpeed {.inline.} =
  c.raw.speed

proc mode*[P: static I2CPeripheral](c: I2cConfig[P]): I2CMode {.inline.} =
  c.raw.mode

proc mode*[P: static I2CPeripheral](c: var I2cConfig[P]): var I2CMode {.inline.} =
  c.raw.mode

proc address*[P: static I2CPeripheral](c: I2cConfig[P]): uint8 {.inline.} =
  c.raw.address

proc address*[P: static I2CPeripheral](c: var I2cConfig[P]): var uint8 {.inline.} =
  c.raw.address

# --- Handle lifecycle --------------------------------------------------------

proc init*[P: static I2CPeripheral](i2c: var I2cHandle[P], config: I2cConfig[P]): I2CResult =
  ## Initialize the I2C interface for the bus encoded in `P`.
  ## The peripheral is taken from the static parameter — a config built
  ## for another bus cannot be passed here (compile error).
  var cfg = config.raw
  cfg.periph = P
  result = i2c.raw.init(cfg)

proc getConfig*[P: static I2CPeripheral](i2c: I2cHandle[P]): I2cConfig[P] {.inline.} =
  result.raw = i2c.raw.getConfig()

# --- Low-level transfers (ptr forms, e.g. for D2-memory DMA buffers) ---------

proc blockingTransmit*[P: static I2CPeripheral](i2c: var I2cHandle[P], address: uint16,
                                                data: ptr uint8, size: uint16,
                                                timeout: uint32): I2CResult {.inline.} =
  i2c.raw.blockingTransmit(address, data, size, timeout)

proc blockingReceive*[P: static I2CPeripheral](i2c: var I2cHandle[P], address: uint16,
                                               data: ptr uint8, size: uint16,
                                               timeout: uint32): I2CResult {.inline.} =
  i2c.raw.blockingReceive(address, data, size, timeout)

proc dmaTransmit*[P: static I2CPeripheral](i2c: var I2cHandle[P], address: uint16,
                                           data: ptr uint8, size: uint16,
                                           callback: I2CCallbackFunctionPtr,
                                           callback_context: pointer): I2CResult {.inline.} =
  i2c.raw.dmaTransmit(address, data, size, callback, callback_context)

proc dmaReceive*[P: static I2CPeripheral](i2c: var I2cHandle[P], address: uint16,
                                          data: ptr uint8, size: uint16,
                                          callback: I2CCallbackFunctionPtr,
                                          callback_context: pointer): I2CResult {.inline.} =
  i2c.raw.dmaReceive(address, data, size, callback, callback_context)

proc readDataAtAddress*[P: static I2CPeripheral](i2c: var I2cHandle[P], address: uint16,
                                                 mem_address: uint16, mem_address_size: uint16,
                                                 data: ptr uint8, data_size: uint16,
                                                 timeout: uint32): I2CResult {.inline.} =
  i2c.raw.readDataAtAddress(address, mem_address, mem_address_size, data, data_size, timeout)

proc writeDataAtAddress*[P: static I2CPeripheral](i2c: var I2cHandle[P], address: uint16,
                                                  mem_address: uint16, mem_address_size: uint16,
                                                  data: ptr uint8, data_size: uint16,
                                                  timeout: uint32): I2CResult {.inline.} =
  i2c.raw.writeDataAtAddress(address, mem_address, mem_address_size, data, data_size, timeout)

proc initI2C*[P: static I2CPeripheral](sclPin, sdaPin: Pin,
                                       speed: I2CSpeed = I2C_400KHZ,
                                       mode: I2CMode = I2C_MASTER,
                                       slaveAddress: uint8 = 0x10): I2cHandle[P] =
  ## Initialize an I2C interface bound to the bus encoded in `P`
  ##
  ## Parameters:
  ##   sclPin: Clock pin (e.g., D11())
  ##   sdaPin: Data pin (e.g., D12())
  ##   speed: I2C_100KHZ, I2C_400KHZ, or I2C_1MHZ
  ##   mode: I2C_MASTER or I2C_SLAVE
  ##   slaveAddress: Device address when in slave mode
  ##
  ## Example:
  ## ```nim
  ## var i2c = initI2C[I2C_1](D11(), D12(), I2C_400KHZ)
  ## ```
  var config: I2cConfig[P]
  config.pinConfig.scl = sclPin
  config.pinConfig.sda = sdaPin
  config.speed = speed
  config.mode = mode
  config.address = slaveAddress
  result = I2cHandle[P](raw: newI2CHandleRaw())
  discard result.init(config)

# --- Blocking transfers ------------------------------------------------------

proc write*[P: static I2CPeripheral](i2c: var I2cHandle[P], deviceAddr: uint16,
                                     data: openArray[uint8],
                                     timeout: uint32 = 100): I2CResult {.inline.} =
  ## Write bytes to an I2C device
  if data.len > 0:
    result = i2c.raw.blockingTransmit(deviceAddr, addr data[0], uint16(data.len), timeout)
  else:
    result = I2C_OK

proc read*[P: static I2CPeripheral](i2c: var I2cHandle[P], deviceAddr: uint16,
                                    buffer: var openArray[uint8],
                                    timeout: uint32 = 100): I2CResult {.inline.} =
  ## Read bytes from an I2C device into provided buffer
  if buffer.len > 0:
    result = i2c.raw.blockingReceive(deviceAddr, addr buffer[0], uint16(buffer.len), timeout)
  else:
    result = I2C_OK

proc writeRegister*[P: static I2CPeripheral](i2c: var I2cHandle[P], deviceAddr: uint16,
                                             regAddr: uint8, value: uint8,
                                             timeout: uint32 = 100): I2CResult {.inline.} =
  ## Write a single byte to a device register
  var data = value
  result = i2c.raw.writeDataAtAddress(deviceAddr, regAddr, 1, addr data, 1, timeout)

proc readRegister*[P: static I2CPeripheral](i2c: var I2cHandle[P], deviceAddr: uint16,
                                            regAddr: uint8,
                                            timeout: uint32 = 100): tuple[result: I2CResult, value: uint8] {.inline.} =
  ## Read a single byte from a device register
  result.value = 0
  result.result = i2c.raw.readDataAtAddress(deviceAddr, regAddr, 1, addr result.value, 1, timeout)

proc writeRegisters*[P: static I2CPeripheral](i2c: var I2cHandle[P], deviceAddr: uint16,
                                              regAddr: uint8, values: openArray[uint8],
                                              timeout: uint32 = 100): I2CResult {.inline.} =
  ## Write multiple bytes to consecutive device registers
  if values.len > 0:
    result = i2c.raw.writeDataAtAddress(deviceAddr, regAddr, 1, addr values[0], uint16(values.len), timeout)
  else:
    result = I2C_OK

proc readRegisters*[P: static I2CPeripheral](i2c: var I2cHandle[P], deviceAddr: uint16,
                                             regAddr: uint8, buffer: var openArray[uint8],
                                             timeout: uint32 = 100): I2CResult {.inline.} =
  ## Read multiple bytes from consecutive device registers into provided buffer
  if buffer.len > 0:
    result = i2c.raw.readDataAtAddress(deviceAddr, regAddr, 1, addr buffer[0], uint16(buffer.len), timeout)
  else:
    result = I2C_OK

proc scan*[P: static I2CPeripheral](i2c: var I2cHandle[P], found: var openArray[uint8],
                                    timeout: uint32 = 10): int =
  ## Scan the I2C bus for devices, storing responding addresses in provided buffer
  ## Returns number of devices found. Only works in master mode.
  ## Buffer should be at least 112 bytes to hold all possible addresses (0x08-0x77)
  result = 0
  var dummy: uint8 = 0

  # Scan addresses 0x08 to 0x77 (valid 7-bit I2C addresses)
  for addr in 0x08'u16 .. 0x77'u16:
    if result >= found.len:
      break
    let res = i2c.raw.blockingTransmit(addr, addr(dummy), 0, timeout)
    if res == I2C_OK:
      found[result] = uint8(addr)
      inc result

# =============================================================================
# DMA (Non-Blocking) API
# =============================================================================

proc transmitDma*[P: static I2CPeripheral](i2c: var I2cHandle[P],
                                           deviceAddr: uint16,
                                           buffer: var openArray[uint8],
                                           callback: I2CCallbackFunctionPtr = nil,
                                           context: pointer = nil): I2CResult =
  ## Non-blocking DMA transmit to I2C device
  ##
  ## **CRITICAL:** Buffer MUST be in D2 memory domain:
  ## - Use `{.section: ".sram1_bss".}` pragma on buffer declaration
  ## - Or allocate on heap with alloc/create
  ## - **DO NOT use stack variables** (will cause DMA errors)
  ##
  ## **DMA Sharing:** I2C1/I2C2/I2C3 share one DMA channel. Only one can use DMA at a time.
  ## I2C4 has NO DMA support - use blocking functions only.
  ##
  ## Returns:
  ##   I2C_OK if transfer queued successfully, I2C_ERR on error
  ##
  ## Example:
  ## ```nim
  ## var txBuf {.section: ".sram1_bss".}: array[64, uint8]
  ##
  ## proc onComplete(ctx: pointer, res: I2CResult) {.cdecl.} =
  ##   echo "Transfer done!"
  ##
  ## discard i2c.transmitDma(0x48, txBuf, onComplete, nil)
  ## ```
  if buffer.len > 0:
    result = i2c.raw.dmaTransmit(deviceAddr, addr buffer[0], uint16(buffer.len),
                                 callback, context)
  else:
    result = I2C_OK

proc receiveDma*[P: static I2CPeripheral](i2c: var I2cHandle[P],
                                          deviceAddr: uint16,
                                          buffer: var openArray[uint8],
                                          callback: I2CCallbackFunctionPtr = nil,
                                          context: pointer = nil): I2CResult =
  ## Non-blocking DMA receive from I2C device
  ##
  ## **CRITICAL:** Buffer MUST be in D2 memory domain:
  ## - Use `{.section: ".sram1_bss".}` pragma on buffer declaration
  ## - Or allocate on heap with alloc/create
  ## - **DO NOT use stack variables** (will cause DMA errors)
  ##
  ## **DMA Sharing:** I2C1/I2C2/I2C3 share one DMA channel. Only one can use DMA at a time.
  ## I2C4 has NO DMA support - use blocking functions only.
  ##
  ## Returns:
  ##   I2C_OK if transfer queued successfully, I2C_ERR on error
  ##
  ## Example:
  ## ```nim
  ## var rxBuf {.section: ".sram1_bss".}: array[64, uint8]
  ##
  ## proc onComplete(ctx: pointer, res: I2CResult) {.cdecl.} =
  ##   # Process received data
  ##   discard
  ##
  ## discard i2c.receiveDma(0x48, rxBuf, onComplete, nil)
  ## ```
  if buffer.len > 0:
    result = i2c.raw.dmaReceive(deviceAddr, addr buffer[0], uint16(buffer.len),
                                callback, context)
  else:
    result = I2C_OK

when isMainModule:
  echo "libDaisy I2C wrapper - Clean API"