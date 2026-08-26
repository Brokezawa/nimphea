## Momentary/Latching Switch with Debouncing
## ==========================================
##
## Generic class for handling momentary/latching switches with debouncing.
## Inspired by Mutable Instruments Switch classes.
##
## **Features:**
## - Debounced button input
## - Rising/falling edge detection
## - Press duration tracking
## - Toggle or momentary modes
## - Normal or inverted polarity
##
## **Usage:**
## ```nim
## import nimphea/hid/switch
##
## var button: Switch
## button.init(D0())  # Simple momentary button on pin D0
##
## while true:
##   button.debounce()
##
##   if button.risingEdge():
##     echo "Button pressed!"
##
##   if button.pressed():
##     echo "Button held for ", button.timeHeldMs(), " ms"
##
##   delay(1)
## ```

import nimphea
export nimphea_core_types


# Switch, SwitchType, SwitchPolarity and GpioPull are defined in nimphea_core_types.

# =============================================================================
# Switch (bind-once)
# =============================================================================
proc newSwitch*(): Switch {.importcpp: "daisy::Switch()", constructor, header: "daisy_seed.h".}
  ## Create a new Switch instance

proc init*(sw: var Switch, pin: Pin, updateRate: cfloat,
           switchType: SwitchType, polarity: SwitchPolarity, pull: GpioPull)
  {.importcpp: "#.Init(@)", header: "hid/switch.h".}
  ## Initialize the switch with full configuration.
  ##
  ## **Example:**
  ## ```nim
  ## var button: Switch
  ## button.init(D0(), 0.0, TYPE_MOMENTARY, POLARITY_INVERTED, PULL_UP)
  ## ```
proc init*(sw: var Switch, pin: Pin, updateRate: cfloat = 0.0)
  {.importcpp: "#.Init(@)", header: "hid/switch.h".}
  ## Initialize the switch with default settings (momentary, inverted, pull-up).
  ##
  ## **Example:**
  ## ```nim
  ## var button: Switch
  ## button.init(D0())
  ## ```

proc debounce*(sw: var Switch) {.importcpp: "#.Debounce()", header: "hid/switch.h".}
  ## Update switch state with debouncing.
  ##
  ## Call this regularly (e.g., every 1ms) to update the switch state.
  ## Must be called for edge detection and timing to work correctly.
  ##
  ## **Example:**
  ## ```nim
  ## while true:
  ##   button.debounce()
  ##   delay(1)
  ## ```
proc risingEdge*(sw: Switch): bool {.importcpp: "#.RisingEdge()", header: "hid/switch.h".}
  ## Check if the button was just pressed (true for one cycle on the
  ## released-to-pressed transition).
proc fallingEdge*(sw: Switch): bool {.importcpp: "#.FallingEdge()", header: "hid/switch.h".}
  ## Check if the button was just released (true for one cycle on the
  ## pressed-to-released transition).
proc pressed*(sw: Switch): bool {.importcpp: "#.Pressed()", header: "hid/switch.h".}
  ## Check if the button is currently held down (after debouncing).
proc released*(sw: Switch): bool {.importcpp: "#.Released()", header: "hid/switch.h".}
  ## Check if the button is currently released (after debouncing).
proc rawState*(sw: var Switch): bool {.importcpp: "#.RawState()", header: "hid/switch.h".}
  ## Read raw button state without debouncing. Normally you want `pressed`.
proc timeHeldMs*(sw: Switch): cfloat {.importcpp: "#.TimeHeldMs()", header: "hid/switch.h".}
  ## Get how long the button has been held, in milliseconds (0 if not pressed).
