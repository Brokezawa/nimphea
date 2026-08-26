## UART and Serial Printing support for libDaisy Nim wrapper
##
## This module provides UART serial communication and logging/printing
## capabilities for the Daisy Seed. It includes both low-level UART
## control and high-level logging via USB CDC or UART.
##
## The UART peripheral is part of the type: `UartHandle[USART_1]` is bound to
## USART 1 — passing it a config built for another UART is a compile-time
## error. The peripheral is set from the static parameter when the interface
## is initialized, so the runtime `periph` field no longer exists.
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
##     hw.delay(ms(1000))
## ```
##
## UART Usage (Low-Level):
## ```nim
## var uart = newUartHandler[USART_1]()
## var config = newUartConfig[USART_1]()
## 
## config.pinConfig.tx = hw.getPin(14)  # Pin D14
## config.pinConfig.rx = hw.getPin(15)  # Pin D15
## config.setBaudrate(BAUD_115200)
## 
## if uart.init(config) == UART_OK:
##   let msg = "Hello UART!"
##   uart.blockingTransmit(msg.cstring, msg.len.csize_t)
## ```

# Import libdaisy
import nimphea
export nimphea_core_types

# NOTE: no `{.push importcpp.}` here — explicit `{.importcpp.}` pragmas are
# silently dropped inside a push region (the generated C++ then uses wrong
# lowercase names). Every binding carries its own inline pragma.
{.push header: "per/uart.h".}

# Low-level C++ interface (bind-once, private — the wrappers own these)
proc initRaw(this: var UartHandlerRaw, config: UartConfigRaw): UartResult {.importcpp: "#.Init(@)".}
proc getConfigRaw(this: UartHandlerRaw): UartConfigRaw {.importcpp: "#.GetConfig()".}

proc blockingTransmitRaw(this: var UartHandlerRaw, buff: ptr uint8, size: csize_t,
                         timeout: uint32 = 100): UartResult {.importcpp: "#.BlockingTransmit(@)".}
proc blockingReceiveRaw(this: var UartHandlerRaw, buffer: ptr uint8, size: uint16,
                        timeout: uint32 = 100): UartResult {.importcpp: "#.BlockingReceive(@)".}

proc checkErrorRaw(this: var UartHandlerRaw): cint {.importcpp: "#.CheckError()".}

{.pop.} # header

# C++ constructors for the raw types (private)
proc newUartHandlerRaw(): UartHandlerRaw {.importcpp: "daisy::UartHandler()",
                                           constructor, header: "per/uart.h".}

proc newUartConfigRaw(): UartConfigRaw {.importcpp: "daisy::UartHandler::Config()",
                                         constructor, header: "per/uart.h".}

# =============================================================================
# Static-peripheral API (the UART port is part of the type)
# =============================================================================

type
  UartHandle*[P: static UartPeripheral] = object
    ## UART handle bound to a specific peripheral at compile time.
    ## Mismatched port/pairings are type errors.
    raw: UartHandlerRaw

  UartConfig*[P: static UartPeripheral] = object
    ## UART configuration bound to the same peripheral as its handle.
    ## The peripheral is implied by `P`; only the transport settings
    ## below are user-controlled.
    raw: UartConfigRaw

# --- UartConfig field accessors (the raw struct stays private) --------------

proc pinConfig*[P: static UartPeripheral](c: UartConfig[P]): UartPinConfig {.inline.} =
  c.raw.pin_config

proc pinConfig*[P: static UartPeripheral](c: var UartConfig[P]): var UartPinConfig {.inline.} =
  c.raw.pin_config

proc baudrate*[P: static UartPeripheral](c: UartConfig[P]): uint32 {.inline.} =
  c.raw.baudrate

proc baudrate*[P: static UartPeripheral](c: var UartConfig[P]): var uint32 {.inline.} =
  c.raw.baudrate

proc mode*[P: static UartPeripheral](c: UartConfig[P]): UartMode {.inline.} =
  c.raw.mode

proc mode*[P: static UartPeripheral](c: var UartConfig[P]): var UartMode {.inline.} =
  c.raw.mode

proc wordLength*[P: static UartPeripheral](c: UartConfig[P]): UartWordLength {.inline.} =
  c.raw.wordlength

proc wordLength*[P: static UartPeripheral](c: var UartConfig[P]): var UartWordLength {.inline.} =
  c.raw.wordlength

proc stopBits*[P: static UartPeripheral](c: UartConfig[P]): UartStopBits {.inline.} =
  c.raw.stopbits

proc stopBits*[P: static UartPeripheral](c: var UartConfig[P]): var UartStopBits {.inline.} =
  c.raw.stopbits

proc parity*[P: static UartPeripheral](c: UartConfig[P]): UartParity {.inline.} =
  c.raw.parity

proc parity*[P: static UartPeripheral](c: var UartConfig[P]): var UartParity {.inline.} =
  c.raw.parity

# --- Handle lifecycle --------------------------------------------------------

proc init*[P: static UartPeripheral](this: var UartHandle[P], config: UartConfig[P]): UartResult =
  ## Initialize the UART interface for the port encoded in `P`.
  ## The peripheral is taken from the static parameter — a config built
  ## for another port cannot be passed here (compile error).
  var cfg = config.raw
  cfg.periph = P
  result = this.raw.initRaw(cfg)

proc getConfig*[P: static UartPeripheral](this: UartHandle[P]): UartConfig[P] {.inline.} =
  result.raw = this.raw.getConfigRaw()

proc checkError*[P: static UartPeripheral](this: var UartHandle[P]): cint {.inline.} =
  this.raw.checkErrorRaw()

proc blockingTransmit*[P: static UartPeripheral](this: var UartHandle[P], buff: ptr uint8,
                                                 size: csize_t, timeout: uint32 = 100): UartResult {.inline.} =
  this.raw.blockingTransmitRaw(buff, size, timeout)

proc blockingReceive*[P: static UartPeripheral](this: var UartHandle[P], buffer: ptr uint8,
                                                size: uint16, timeout: uint32 = 100): UartResult {.inline.} =
  this.raw.blockingReceiveRaw(buffer, size, timeout)

# --- Makers ------------------------------------------------------------------

proc newUartHandler*[P: static UartPeripheral](): UartHandle[P] {.inline.} =
  ## Create an uninitialized UART handle bound to the port encoded in `P`.
  result.raw = newUartHandlerRaw()

proc newUartConfig*[P: static UartPeripheral](): UartConfig[P] {.inline.} =
  ## Create a UART configuration bound to the port encoded in `P`.
  result.raw = newUartConfigRaw()

# =============================================================================
# Helper Functions for UART
# =============================================================================

proc blockingTransmit*[P: static UartPeripheral](uart: var UartHandle[P], data: cstring,
                                                 timeout: uint32 = 100): UartResult =
  ## Transmit a C string via UART (blocking)
  let len = data.len
  result = uart.blockingTransmit(cast[ptr uint8](data), len.csize_t, timeout)

proc blockingTransmit*[P: static UartPeripheral](uart: var UartHandle[P], data: openArray[uint8],
                                                 timeout: uint32 = 100): UartResult {.inline.} =
  ## Transmit a byte array via UART (blocking)
  if data.len > 0:
    result = uart.blockingTransmit(addr data[0], data.len.csize_t, timeout)
  else:
    result = UART_OK

proc blockingReceive*[P: static UartPeripheral](uart: var UartHandle[P], buffer: var openArray[uint8],
                                                timeout: uint32 = 100): UartResult =
  ## Receive data via UART (blocking) into provided buffer
  if buffer.len > 0:
    result = uart.blockingReceive(addr buffer[0], buffer.len.uint16, timeout)
  else:
    result = UART_OK

# Common baud rates (typed: assign via setBaudrate)
const
  BAUD_9600* = baud(9600'u32)
  BAUD_19200* = baud(19200'u32)
  BAUD_38400* = baud(38400'u32)
  BAUD_57600* = baud(57600'u32)
  BAUD_115200* = baud(115200'u32)
  BAUD_230400* = baud(230400'u32)
  BAUD_460800* = baud(460800'u32)
  BAUD_921600* = baud(921600'u32)
  BAUD_1000000* = baud(1000000'u32)
  BAUD_2000000* = baud(2000000'u32)

# MIDI baud rate
const BAUD_31250* = baud(31250'u32)  ## Standard MIDI baud rate

proc setBaudrate*[P: static UartPeripheral](config: var UartConfig[P], rate: Baud) =
  ## Set the UART baud rate
  config.raw.baudrate = rate.uint32

# Helper to configure UART for common scenarios
proc configureForDebug*[P: static UartPeripheral](config: var UartConfig[P], txPin, rxPin: Pin) =
  ## Configure UART for debug output (115200 baud, 8N1)
  config.pinConfig.tx = txPin
  config.pinConfig.rx = rxPin
  config.setBaudrate(BAUD_115200)
  config.mode = MODE_TX_RX
  config.stopBits = STOP_BITS_1
  config.parity = PARITY_NONE
  config.wordLength = WORD_BITS_8

proc configureForMidi*[P: static UartPeripheral](config: var UartConfig[P], txPin, rxPin: Pin) =
  ## Configure UART for MIDI (31250 baud, 8N1)
  config.pinConfig.tx = txPin
  config.pinConfig.rx = rxPin
  config.raw.baudrate = BAUD_31250.uint32
  config.mode = MODE_TX_RX
  config.stopBits = STOP_BITS_1
  config.parity = PARITY_NONE
  config.wordLength = WORD_BITS_8

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
##     hw.delay(ms(1000))
##
## when isMainModule:
##   main()
## ```

when isMainModule:
  echo "Nimphea UART wrapper"
  echo "Provides USB logging and UART communication"