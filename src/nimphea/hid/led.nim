## LED Control
## ===========
##
## Single LED control with software PWM and gamma correction.
##
## **Features:**
## - Software PWM for brightness control
## - Automatic gamma correction (cubic curve)
## - Configurable update rate
## - Inversion support (for active-low LEDs)
##
## **Usage:**
## ```nim
## import nimphea/hid/led
##
## var led: Led
## led.init(D10(), false, 1000.0)  # Pin D10, not inverted, 1kHz update rate
##
## # Set brightness (0.0 to 1.0, gamma corrected automatically)
## led.set(0.5)
##
## # In main loop at 1kHz
## while true:
##   led.update()  # Must call at specified sample rate!
##   hw.delay(1)
## ```

import nimphea


type
  Led* {.importcpp: "daisy::Led", header: "hid/led.h".} = object
    ## Single LED with software PWM control

proc init*(led: var Led, pin: Pin, invert: bool, samplerate: cfloat = 1000.0'f32)
  {.importcpp: "#.Init(@)".}
  ## Initialize the LED on the specified pin.
  ##
  ## **Parameters:**
  ## - `pin` - Hardware pin for the LED
  ## - `invert` - True to invert brightness (for active-low LEDs)
  ## - `samplerate` - Rate at which `update` will be called in Hz (default: 1000Hz)
  ##
  ## **Example:**
  ## ```nim
  ## led.init(D10(), false, 1000.0)  # Update at 1kHz
  ## ```
proc set*(led: var Led, val: cfloat) {.importcpp: "#.Set(@)".}
  ## Set LED brightness (0.0 = off, 1.0 = full brightness).
  ##
  ## Value is cubed for gamma correction, then quantized to 8-bit for PWM.
proc set*(led: var Led, val: float) {.inline.} = led.set(val.cfloat)
  ## Set LED brightness as a Nim float (retained float→cfloat overload).
  ##
  ## **Example:**
  ## ```nim
  ## led.set(0.0)   # Off
  ## led.set(0.5)   # Half brightness (gamma corrected)
  ## ```
proc update*(led: var Led) {.importcpp: "#.Update()".}
  ## Update the LED PWM state (must be called at the sample rate from `init`).
proc setSampleRate*(led: var Led, sampleRate: cfloat) {.importcpp: "#.SetSampleRate(@)".}
  ## Change the update sample rate without reinitializing.
proc setSampleRate*(led: var Led, sampleRate: float) {.inline.} = led.setSampleRate(sampleRate.cfloat)
  ## Change the update sample rate as a Nim float (retained float→cfloat overload).
