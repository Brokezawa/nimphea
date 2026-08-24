## Gate Input
## ==========
##
## Generic class for handling gate/trigger inputs through GPIO (Eurorack gates, triggers, etc.)
##
## **Features:**
## - Trigger detection (rising/falling edge)
## - State reading (high/low)
## - Optional inversion (for BJT input circuits)
##
## **Usage:**
## ```nim
## import nimphea/hid/gatein
##
## var gate: GateIn
## gate.init(D0, true)  # Pin D0, inverted (typical for eurorack)
##
## # In main loop
## while true:
##   if gate.trig():
##     # Rising edge detected!
##     echo "Gate triggered"
##   
##   let isHigh = gate.state()
##   hw.delay(1)
## ```

import nimphea

useNimpheaModules(gatein)

type
  GateIn* {.importcpp: "daisy::GateIn", header: "hid/gatein.h".} = object
    ## Gate input handler for eurorack-style gate/trigger signals

proc init*(gate: var GateIn, pin: Pin, invert: bool = true) {.importcpp: "#.Init(@)".}
  ## Initialize a gate input on the specified pin.
  ##
  ## **Parameters:**
  ## - `pin` - Hardware pin to use
  ## - `invert` - True if pin state is HIGH when 0V at input (default: true for BJT circuits)
  ##
  ## **Note:** Default is true because typical eurorack gate inputs use
  ## inverting BJT circuits.
proc trig*(gate: var GateIn): bool {.importcpp: "#.Trig()".}
  ## Check if the gate input just transitioned (edge detect).
  ##
  ## **Returns:** True if the gate just went high (rising edge).
proc state*(gate: var GateIn): bool {.importcpp: "#.State()".}
  ## Get the current gate state.
  ##
  ## **Returns:** True if the gate is currently high.

