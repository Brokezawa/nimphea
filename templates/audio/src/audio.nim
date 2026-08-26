## Nimphea audio template: stereo audio passthrough
##
## Shows the real-time audio pattern: an `AudioCallback` runs on the audio
## interrupt with strict embedded rules, while the main loop handles lower
## priority tasks. Application logging goes to the Seed's USB CDC virtual
## serial port via the library's hid/logger module.

import nimphea
import nimphea/hid/logger


# Real-time audio callback — runs on the audio interrupt (~1ms @ 48kHz).
# RULES:
# - No heap allocations (no seq, no string, no new)
# - No blocking calls (no delay, no printing, no logging)
# - Keep it fast enough to fit within the block size
proc audioCallback(input, output: AudioBuffer, size: int) {.cdecl, raises: [].} =
  for i in 0..<size:
    # Stereo passthrough: input -> output
    output[0][i] = input[0][i]
    output[1][i] = input[1][i]

proc main() =
  # Initialize the Daisy Seed board
  var daisy = initDaisy()

  # Start audio processing with our callback
  daisy.startAudio(audioCallback)

  # Application logging via USB CDC (virtual serial port on the computer);
  # false = do not wait for the PC to connect. Runtime error messages
  # (defects/asserts) are a separate channel — see nimphea/syscalls.
  LoggerInternal.startLog(false)
  LoggerInternal.printLine(cstring("Audio Passthrough Template Started"))

  var ledState = false
  while true:
    # Main loop runs at lower priority than the audio callback;
    # use it for controls, displays, etc.
    ledState = not ledState
    daisy.setLed(ledState)
    daisy.delay(ms(1000))

when isMainModule:
  main()