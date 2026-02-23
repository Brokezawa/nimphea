import nimphea

# Set up C++ interop macros
useNimpheaNamespace()

proc main() =
  # Initialize the Daisy Seed board
  var daisy = initDaisy()
  
  # Start the system log (optional, for debugging via USB serial)
  startLog()
  printLine("Nimphea Project Started!")

  while true:
    # Toggle the built-in LED every 500ms
    daisy.toggleLed()
    daisy.delay(500)

when isMainModule:
  main()
