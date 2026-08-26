## Logger
## ======
##
## USB and UART logging for debugging Daisy applications.
##
## The libDaisy `Logger<Destination>` template class is exposed as a set of
## pre-instantiated types (one per destination), because C++ non-type template
## parameters do not map to Nim generics. Use these types directly:
##
## - `UsbLogger` (= `LoggerInternal`) - internal USB (built into Daisy Seed)
## - `LoggerExternal` - external USB (if available on your board)
## - `LoggerSemihost` - stdout (requires a debugger connection)
## - `LoggerNone` - muted (all logging disabled, zero overhead)
##
## **Basic Usage:**
## ```nim
## import nimphea
## import nimphea/hid/logger
##
## proc main() =
##   var hw = initDaisy()
##   UsbLogger.startLog(false)         # false = don't wait for PC connection
##
##   UsbLogger.printLine("=== Daisy Seed Startup ===")
##
##   var counter = 0
##   while true:
##     hw.delay(1000)
##     UsbLogger.printLine(cstring("Counter: " & $counter))
##     inc counter
##
## when isMainModule:
##   main()
## ```
##
## **Notes:**
## - `print`/`printLine` take `cstring`; convert Nim strings explicitly (`cstring(s)`).
## - Do **not** log from the audio callback (causes glitches).
## - Buffer size 128 bytes; newline is `\r\n`; USB CDC needs no baud configuration.
## - For production, `LoggerNone` mutes all output with zero overhead.
## - The loggers are application-level channels (USB/semihost). Runtime error
##   messages (uncaught exceptions, defects, asserts, echo, printf) go to
##   newlib stderr instead and need `nimphea/syscalls` (the `UsartStdio`
##   retarget) to reach a serial monitor — see syscalls.nim.

import nimphea
import nimphea/nimphea_macros

when isMainModule:
  discard  # Examples removed for simplicity

useNimpheaModules(logger)

{.push header: "hid/logger.h".}

# ============================================================================
# Type Definitions
# ============================================================================

type
  # Individual Logger types for each destination
  # NOTE: We don't import LoggerDestination enum because the Logger template
  # in C++ uses non-type template parameters, which don't map well to Nim generics.
  # Instead, we provide pre-instantiated types for each destination.
  
  LoggerNone* {.importcpp: "daisy::Logger<daisy::LOGGER_NONE>",
                header: "hid/logger.h".} = object
    ## Logger with no output (all calls optimized away).
    ## Use for production builds to eliminate logging overhead.
  
  LoggerInternal* {.importcpp: "daisy::Logger<daisy::LOGGER_INTERNAL>",
                    header: "hid/logger.h".} = object
    ## Logger using internal USB port (most common).
    ## Built into Daisy Seed, appears as virtual serial port.
  
  LoggerExternal* {.importcpp: "daisy::Logger<daisy::LOGGER_EXTERNAL>",
                    header: "hid/logger.h".} = object
    ## Logger using external USB port (if supported by hardware).
  
  LoggerSemihost* {.importcpp: "daisy::Logger<daisy::LOGGER_SEMIHOST>",
                    header: "hid/logger.h".} = object
    ## Logger using semihosting (debugger stdout).
    ## Requires active debugger connection.

{.pop.} # header

# ============================================================================
# Type Aliases for Convenience
# ============================================================================

type
  UsbLogger* = LoggerInternal
    ## Alias for LoggerInternal (most common use case).
    ## Logs to internal USB port on Daisy Seed.
  
  NullLogger* = LoggerNone
    ## Alias for LoggerNone (disabled logging).
    ## All logging calls are optimized away at compile time.

# ============================================================================
# C++ Method Wrappers - LoggerInternal (most common)
# ============================================================================

proc print*(T: typedesc[LoggerInternal], format: cstring) {.
  importcpp: "daisy::Logger<daisy::LOGGER_INTERNAL>::Print(@)".}
  ## Print formatted string (no newline added).
  ##
  ## **Parameters:**
  ## - `format` - C-string to print
  ##
  ## **Example:**
  ## ```nim
  ## UsbLogger.print("Hello ")
  ## UsbLogger.print("World")  # Same line
  ## ```

proc printLine*(T: typedesc[LoggerInternal], format: cstring) {.
  importcpp: "daisy::Logger<daisy::LOGGER_INTERNAL>::PrintLine(@)".}
  ## Print formatted string with newline appended.
  ##
  ## **Parameters:**
  ## - `format` - C-string to print
  ##
  ## **Example:**
  ## ```nim
  ## UsbLogger.printLine("Line 1")
  ## UsbLogger.printLine("Line 2")
  ## ```

proc startLog*(T: typedesc[LoggerInternal], wait_for_pc: bool = false) {.
  importcpp: "daisy::Logger<daisy::LOGGER_INTERNAL>::StartLog(@)".}
  ## Start the logging session.
  ##
  ## **Parameters:**
  ## - `wait_for_pc` - If true, block until PC terminal connects (default: false)
  ##
  ## **Example:**
  ## ```nim
  ## UsbLogger.startLog(false)  # Non-blocking (recommended)
  ## # Or:
  ## UsbLogger.startLog(true)   # Wait for serial terminal
  ## ```

# ============================================================================
# C++ Method Wrappers - LoggerExternal
# ============================================================================

proc print*(T: typedesc[LoggerExternal], format: cstring) {.
  importcpp: "daisy::Logger<daisy::LOGGER_EXTERNAL>::Print(@)".}
  ## Print to external USB port (no newline).

proc printLine*(T: typedesc[LoggerExternal], format: cstring) {.
  importcpp: "daisy::Logger<daisy::LOGGER_EXTERNAL>::PrintLine(@)".}
  ## Print to external USB port (with newline).

proc startLog*(T: typedesc[LoggerExternal], wait_for_pc: bool = false) {.
  importcpp: "daisy::Logger<daisy::LOGGER_EXTERNAL>::StartLog(@)".}
  ## Start logging to external USB port.

# ============================================================================
# C++ Method Wrappers - LoggerSemihost
# ============================================================================

proc print*(T: typedesc[LoggerSemihost], format: cstring) {.
  importcpp: "daisy::Logger<daisy::LOGGER_SEMIHOST>::Print(@)".}
  ## Print to debugger stdout (no newline).

proc printLine*(T: typedesc[LoggerSemihost], format: cstring) {.
  importcpp: "daisy::Logger<daisy::LOGGER_SEMIHOST>::PrintLine(@)".}
  ## Print to debugger stdout (with newline).

proc startLog*(T: typedesc[LoggerSemihost], wait_for_pc: bool = false) {.
  importcpp: "daisy::Logger<daisy::LOGGER_SEMIHOST>::StartLog(@)".}
  ## Start semihosting logging.

# ============================================================================
# C++ Method Wrappers - LoggerNone (no-ops, optimized away)
# ============================================================================

proc print*(T: typedesc[LoggerNone], format: cstring) {.
  importcpp: "daisy::Logger<daisy::LOGGER_NONE>::Print(@)".}
  ## No-op (optimized away at compile time).

proc printLine*(T: typedesc[LoggerNone], format: cstring) {.
  importcpp: "daisy::Logger<daisy::LOGGER_NONE>::PrintLine(@)".}
  ## No-op (optimized away at compile time).

proc startLog*(T: typedesc[LoggerNone], wait_for_pc: bool = false) {.
  importcpp: "daisy::Logger<daisy::LOGGER_NONE>::StartLog(@)".}
  ## No-op (optimized away at compile time).

# ============================================================================
# Nim Helper Functions
# ============================================================================

template log*(T: typedesc[LoggerInternal], msg: string) =
  ## Log a Nim string with newline (convenience wrapper).
  T.printLine(cstring(msg))

template log*(T: typedesc[LoggerExternal], msg: string) =
  ## Log a Nim string with newline (convenience wrapper).
  T.printLine(cstring(msg))

template log*(T: typedesc[LoggerSemihost], msg: string) =
  ## Log a Nim string with newline (convenience wrapper).
  T.printLine(cstring(msg))

template log*(T: typedesc[LoggerNone], msg: string) =
  ## No-op (optimized away at compile time).
  T.printLine(cstring(msg))

# ============================================================================
# Usage Examples
# ============================================================================

when isMainModule:
  ## Compile-time examples (not executable without hardware)
  
  # Example 1: Basic logging
  block:
    type MyLogger = LoggerInternal
    
    MyLogger.startLog(false)
    MyLogger.print("Hello ")
    MyLogger.printLine("World!")
  
  # Example 2: Using the convenience alias
  block:
    UsbLogger.startLog()
    UsbLogger.printLine("Firmware v1.0.0")
    UsbLogger.printLine("Ready")
