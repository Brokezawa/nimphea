## UART and Serial Printing support for libDaisy Nim wrapper
##
## This module provides UART serial communication and logging/printing
## capabilities for the Daisy Seed. It includes both low-level UART
## control and high-level logging via USB CDC or UART.
##
## Basic Usage (High-Level Logging):
## ```nim
## import nimphea
## import nimphea/per/uart
## 
## var hw = newDaisySeed()
## 
## proc main() =
##   hw.init()
##   
##   # Start USB logging (appears as serial port on computer)
##   startLog()
##   
##   printLine("Hello from Daisy!")
##   print("Counter: ")
##   
##   var counter = 0
##   while true:
##     printLine($counter)
##     counter += 1
##     hw.delay(1000)
## ```
##
## UART Usage (Low-Level):
## ```nim
## var uart = newUartHandler()
## var config = newUartConfig()
## 
## config.periph = USART_1
## config.pin_config.tx = hw.getPin(14)  # Pin D14
## config.pin_config.rx = hw.getPin(15)  # Pin D15
## config.baudrate = 115200
## 
## if uart.init(config) == UART_OK:
##   let msg = "Hello UART!"
##   uart.blockingTransmit(msg.cstring, msg.len.csize_t)
## ```

# Import libdaisy which provides the macro system
import nimphea
export nimphea_core_types

# Use the macro system for this module's compilation unit
# Serial module includes both per/uart.h and hid/logger.h
useNimpheaModules(serial)

# NOTE: no `{.push importcpp.}` here — explicit `{.importcpp.}` pragmas are
# silently dropped inside a push region (the generated C++ then uses wrong
# lowercase names). Every binding carries its own inline pragma.
{.push header: "per/uart.h".}

# UART Handler methods
proc init*(this: var UartHandler, config: UartConfig): UartResult {.importcpp: "#.Init(@)".}
proc getConfig*(this: UartHandler): UartConfig {.importcpp: "#.GetConfig()".}

proc blockingTransmit*(this: var UartHandler, buff: ptr uint8, size: csize_t, 
                       timeout: uint32 = 100): UartResult {.importcpp: "#.BlockingTransmit(@)".}
proc blockingReceive*(this: var UartHandler, buffer: ptr uint8, size: uint16,
                      timeout: uint32 = 100): UartResult {.importcpp: "#.BlockingReceive(@)".}

proc checkError*(this: var UartHandler): cint {.importcpp: "#.CheckError()".}

{.pop.} # header

# =============================================================================
# High-Level Logging/Printing API
# =============================================================================

# Note: Logging functions (StartLog, Print, PrintLine) have been moved to
# libdaisy.nim to prevent circular dependencies and ambiguity.
# They are available via `import nimphea`.

# C++ constructors
proc newUartHandler*(): UartHandler {.importcpp: "daisy::UartHandler()", 
                                      constructor, header: "per/uart.h".}

proc newUartConfig*(): UartConfig {.importcpp: "daisy::UartHandler::Config()",
                                    constructor, header: "per/uart.h".}

# =============================================================================
# Helper Functions for UART
# =============================================================================

proc blockingTransmit*(uart: var UartHandler, data: cstring, 
                       timeout: uint32 = 100): UartResult =
  ## Transmit a C string via UART (blocking)
  let len = data.len
  result = uart.blockingTransmit(cast[ptr uint8](data), len.csize_t, timeout)

proc blockingTransmit*(uart: var UartHandler, data: openArray[uint8],
                       timeout: uint32 = 100): UartResult {.inline.} =
  ## Transmit a byte array via UART (blocking)
  if data.len > 0:
    result = uart.blockingTransmit(addr data[0], data.len.csize_t, timeout)
  else:
    result = UART_OK

proc blockingReceive*(uart: var UartHandler, buffer: var openArray[uint8],
                      timeout: uint32 = 100): UartResult =
  ## Receive data via UART (blocking) into provided buffer
  if buffer.len > 0:
    result = uart.blockingReceive(addr buffer[0], buffer.len.uint16, timeout)
  else:
    result = UART_OK

# Common baud rates
const
  BAUD_9600* = 9600'u32
  BAUD_19200* = 19200'u32
  BAUD_38400* = 38400'u32
  BAUD_57600* = 57600'u32
  BAUD_115200* = 115200'u32
  BAUD_230400* = 230400'u32
  BAUD_460800* = 460800'u32
  BAUD_921600* = 921600'u32
  BAUD_1000000* = 1000000'u32
  BAUD_2000000* = 2000000'u32

# MIDI baud rate
const BAUD_31250* = 31250'u32  ## Standard MIDI baud rate

# Helper to configure UART for common scenarios
proc configureForDebug*(config: var UartConfig, txPin, rxPin: Pin) =
  ## Configure UART for debug output (115200 baud, 8N1)
  config.periph = USART_1
  config.pin_config.tx = txPin
  config.pin_config.rx = rxPin
  config.baudrate = BAUD_115200
  config.mode = MODE_TX_RX
  config.stopbits = STOP_BITS_1
  config.parity = PARITY_NONE
  config.wordlength = WORD_BITS_8

proc configureForMidi*(config: var UartConfig, txPin, rxPin: Pin) =
  ## Configure UART for MIDI (31250 baud, 8N1)
  config.periph = USART_1
  config.pin_config.tx = txPin
  config.pin_config.rx = rxPin
  config.baudrate = BAUD_31250
  config.mode = MODE_TX_RX
  config.stopbits = STOP_BITS_1
  config.parity = PARITY_NONE
  config.wordlength = WORD_BITS_8

# =============================================================================
# Documentation and Examples
# =============================================================================

## USB Serial Logging Example:
## ```nim
## import nimphea
## import nimphea/per/uart
##
## var hw = newDaisySeed()
##
## proc main() =
##   hw.init()
##   startLog()  # Initialize USB CDC serial
##
##   printLine("Daisy Seed Started!")
##
##   var counter = 0
##   while true:
##     print("Counter: ")
##     printLine(counter)
##     counter += 1
##     hw.delay(1000)
##
## when isMainModule:
##   main()
## ```

when isMainModule:
  echo "libDaisy Serial/UART wrapper"
  echo "Provides USB logging and UART communication"
