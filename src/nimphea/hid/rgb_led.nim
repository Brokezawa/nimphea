## RGB LED Control
## ================
##
## 3-channel RGB LED control with software PWM.
##
## **Features:**
## - Control 3 LEDs as RGB unit
## - Software PWM with gamma correction
## - Integration with Color module
## - Per-channel or combined control
##
## **Usage:**
## ```nim
## import nimphea/hid/rgb_led
## import nimphea_color
##
## var rgb: RgbLed
## rgb.init(D10(), D11(), D12(), false)  # R, G, B pins, not inverted
##
## # Set by channels
## rgb.set(1.0, 0.0, 0.0)  # Red
##
## # Set by color object
## var purple = createColor(0.5, 0.0, 0.5)
## rgb.setColor(purple)
##
## # In main loop at 1kHz
## while true:
##   rgb.update()
##   hw.delay(1)
## ```

import nimphea
import nimphea_color  # For Color type

useNimpheaModules(rgb_led)

type
  RgbLed* {.importcpp: "daisy::RgbLed", header: "hid/rgb_led.h".} = object
    ## RGB LED (3x LED configured as an RGB unit)

proc init*(rgb: var RgbLed, red, green, blue: Pin, invert: bool)
  {.importcpp: "#.Init(@)".}
  ## Initialize the RGB LED with 3 pins.
  ##
  ## **Parameters:**
  ## - `red` - Pin for the red channel
  ## - `green` - Pin for the green channel
  ## - `blue` - Pin for the blue channel
  ## - `invert` - True to invert all channels (for common-anode LEDs)
proc set*(rgb: var RgbLed, r, g, b: cfloat) {.importcpp: "#.Set(@)".}
  ## Set RGB LED color by channels.
  ##
  ## **Parameters:**
  ## - `r` - Red brightness (0.0 to 1.0)
  ## - `g` - Green brightness (0.0 to 1.0)
  ## - `b` - Blue brightness (0.0 to 1.0)
  ##
  ## **Example:**
  ## ```nim
  ## rgb.set(1.0, 0.0, 0.0)  # Red
  ## rgb.set(0.0, 1.0, 0.0)  # Green
  ## ```
proc set*(rgb: var RgbLed, r, g, b: float) {.inline.} = rgb.set(r.cfloat, g.cfloat, b.cfloat)
  ## Set RGB LED color by channels as Nim floats (retained float→cfloat overload).

proc setRed*(rgb: var RgbLed, val: cfloat) {.importcpp: "#.SetRed(@)".}
  ## Set the red channel only.
proc setRed*(rgb: var RgbLed, val: float) {.inline.} = rgb.setRed(val.cfloat)
  ## Set the red channel as a Nim float.
proc setGreen*(rgb: var RgbLed, val: cfloat) {.importcpp: "#.SetGreen(@)".}
  ## Set the green channel only.
proc setGreen*(rgb: var RgbLed, val: float) {.inline.} = rgb.setGreen(val.cfloat)
  ## Set the green channel as a Nim float.
proc setBlue*(rgb: var RgbLed, val: cfloat) {.importcpp: "#.SetBlue(@)".}
  ## Set the blue channel only.
proc setBlue*(rgb: var RgbLed, val: float) {.inline.} = rgb.setBlue(val.cfloat)
  ## Set the blue channel as a Nim float.

proc setColor*(rgb: var RgbLed, c: Color) {.importcpp: "#.SetColor(@)".}
  ## Set the RGB LED using a Color object.
  ##
  ## **Example:**
  ## ```nim
  ## var purple = createColor(0.5, 0.0, 0.5)
  ## rgb.setColor(purple)
  ## ```
proc update*(rgb: var RgbLed) {.importcpp: "#.Update()".}
  ## Update all 3 LED PWM states (must be called at a regular interval,
  ## typically 1kHz).
