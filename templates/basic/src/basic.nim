## Minimal nimphea example: blink the built-in LED
##
## Shows the basic pattern every project shares: init the Daisy, then loop.

import nimphea
useNimpheaNamespace()

proc main() =
  var daisy = initDaisy()
  var ledState = false

  while true:
    ledState = not ledState
    daisy.setLed(ledState)
    daisy.delay(500)

when isMainModule:
  main()