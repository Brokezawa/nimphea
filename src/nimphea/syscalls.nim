## Newlib syscall retargets for UART stdio
##
## Routes **runtime** error output — uncaught nim exceptions and defects,
## assertion failures, `echo`, and C `printf` — to a UART serial monitor by
## retargeting newlib's low-level syscalls (`_write`/`_read`/...). Modeled on
## nim-on-samd21's syscalls.nim.
##
## **When you need it:** a nim `raise`/`defect` message is written by the
## exception machinery (`system/excpt`) into newlib's stderr. On the Daisy
## there is no stderr device, so without this module runtime errors are
## *silently lost*. `startLog`/`printLine` (hid/logger, USB CDC or semihost)
## and the per/uart loggers cannot print those runtime messages — they are
## application-level channels that bypass stdio entirely. The two are
## complementary:
##   - `hid/logger` (`LoggerInternal`, USB CDC; `LoggerSemihost`, debugger):
##     app-level logging, no syscalls involved, keep it out of the audio
##     callback.
##   - `syscalls` (this module): runtime error channel — defects, asserts,
##     echo, printf — opt-in with the `UsartStdio` symbol.
##
## The retargets are only compiled when the `UsartStdio` symbol is declared
## (e.g. `switch("define", "UsartStdio")` in the project's config.nims, or
## `-d:UsartStdio`): without it, this module is inert and the library links
## no syscall overrides (zero overhead).
##
## Usage (project config.nims):
## ```nim
## switch("define", "UsartStdio")
## ```
## Usage (main module):
## ```nim
## import nimphea
## import nimphea/syscalls
## import nimphea/per/uart
##
## var seed = newDaisySeed()
## var uart = newUartHandler[USART_1]()
## var config = newUartConfig[USART_1]()
## config.setBaudrate(BAUD_115200)
## config.pinConfig.tx = newPin(PORTG, 14)
## config.pinConfig.rx = newPin(PORTG, 9)
##
## seed.init()
## if uart.init(config) == UART_OK:
##   enableUsartStdio(uart)  # after this, runtime errors/echo/printf reach the serial monitor
## ```
## Wire to any UART: USART_1 @ 115200 on the Seed's debug pins is the
## common choice; adjust the config for your board. `disableUsartStdio`
## reverts the retargets to silent no-ops.

when defined(UsartStdio):
  import std/posix

  import nimphea
  import nimphea/per/uart


  {.push cdecl, raises: [].}

  var usartStdioEnabled = false
  var stdioUart: UartHandle[USART_1]

  proc enableUsartStdio*[P: static UartPeripheral](uart: var UartHandle[P]) =
    ## Route newlib stdio (and nim defect output) through `uart`
    usartStdioEnabled = true
    stdioUart = uart

  proc disableUsartStdio*() =
    ## Restore silent stdio (write returns 0, no bytes sent)
    usartStdioEnabled = false

  proc sysClose(file: cint): cint {.exportc: "_close", used.} =
    result = -1

  proc sysLseek(file: cint, offset: cint, whence: cint): cint {.exportc: "_lseek", used.} =
    result = 0

  proc sysIsatty(file: cint): cint {.exportc: "_isatty", used.} =
    result = 0

  proc sysFstat(file: cint, st: ptr Stat): cint {.exportc: "_fstat", used.} =
    result = -1

  proc sysRead(file: cint, buf: pointer, len: csize_t): cint {.exportc: "_read", used.} =
    result = 0

  proc sysWrite(file: cint, buf: pointer, len: csize_t): csize_t {.exportc: "_write", used.} =
    if usartStdioEnabled:
      var data = cast[ptr uint8](buf)
      var remaining = len
      while remaining > 0:
        let chunk = if remaining > 255: 255'u32 else: remaining.uint32
        discard stdioUart.blockingTransmit(data, chunk.csize_t)
        data = cast[ptr uint8](cast[int](data) + chunk.int)
        remaining = remaining - chunk.csize_t
    result = len

  {.pop.} # cdecl, raises
