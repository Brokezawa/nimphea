## Panic handler for embedded systems
## This overrides Nim's default panic handler for bare metal ARM targets

{.push stack_trace: off, profiler: off.}

proc rawoutput(s: string) =
  # No console on bare metal - blink an LED pattern / UART debug here if desired
  discard

proc panic(s: string) {.exportc: "panic", noreturn.} =
  while true:
    discard

{.pop.}