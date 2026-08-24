## Controls and sensors support for libDaisy Nim wrapper
##
## This module provides support for encoders, switches, analog controls, and ADC.
##
## Example - Simple button:
## ```nim
## import nimphea, hid/ctrl
##
## var daisy = initDaisy()
## var button = initSwitch(D2())
##
## while true:
##   button.debounce()
##   if button.pressed:
##     daisy.setLed(true)
##   elif button.released:
##     daisy.setLed(false)
##   daisy.delay(1)
## ```
##
## Example - Rotary encoder:
## ```nim
## var encoder = initEncoder(D0(), D1(), D2())
## var value = 0
##
## while true:
##   encoder.update()
##   value += encoder.increment
##   daisy.delay(1)
## ```
##
## Example - Analog input (ADC):
## ```nim
## var adc = initAdc(daisy, [A0(), A1()])
## adc.start()
##
## while true:
##   let knob1 = adc.value(0)  # 0.0 to 1.0
##   let knob2 = adc.value(1)
##   daisy.delay(10)
## ```

# Import libdaisy which provides the macro system
import nimphea
export nimphea_core_types
# AdcChannelConfig construction/read bindings are canonical in per/adc
import nimphea/per/adc
# All Switch bindings are canonical in hid/switch; re-export for convenience
import nimphea/hid/switch
export switch

# Use the macro system for this module's compilation unit
useNimpheaModules(controls, adc)

# C++ constructors
proc newEncoder*(): Encoder {.importcpp: "daisy::Encoder()", constructor, header: "daisy_seed.h".}
proc newAnalogControl*(): AnalogControl {.importcpp: "daisy::AnalogControl()", constructor, header: "hid/ctrl.h".}

# =============================================================================
# Switch (bindings are canonical in hid/switch, re-exported above)
# =============================================================================
proc initSwitch*(pin: Pin, updateRate: float = 1000.0,
                 switchType: SwitchType = TYPE_MOMENTARY,
                 polarity: SwitchPolarity = POLARITY_NORMAL,
                 pull: GpioPull = PULL_UP): Switch =
  ## Initialize a switch/button (retained: constructor + config assembly).
  ##
  ## Parameters:
  ##   pin: The GPIO pin the switch is connected to
  ##   updateRate: How often to check the switch (Hz)
  ##   switchType: TYPE_MOMENTARY or TYPE_TOGGLE
  ##   polarity: POLARITY_NORMAL or POLARITY_INVERTED
  ##   pull: PULL_UP, PULL_DOWN, or PULL_NOPULL
  ##
  ## Example:
  ## ```nim
  ## var button = initSwitch(D2())  # Simple momentary button
  ## ```
  result = newSwitch()
  result.init(pin, updateRate.cfloat, switchType, polarity, pull)

# =============================================================================
# Encoder (bind-once)
# =============================================================================
proc init*(enc: var Encoder, a: Pin, b: Pin, click: Pin, updateRate: cfloat = 1000.0)
  {.importcpp: "#.Init(@)", header: "daisy_seed.h".}
proc update*(enc: var Encoder) {.importcpp: "#.Debounce()", header: "daisy_seed.h".}
  ## Update encoder state (call this regularly)
proc increment*(enc: Encoder): int32 {.importcpp: "#.Increment()", header: "daisy_seed.h".}
  ## Get encoder position change since the last call (-N to +N)
proc pressed*(enc: Encoder): bool {.importcpp: "#.Pressed()", header: "daisy_seed.h".}
  ## Check if the encoder button is pressed
proc risingEdge*(enc: Encoder): bool {.importcpp: "#.RisingEdge()", header: "daisy_seed.h".}
  ## Check if the encoder button was just pressed
proc fallingEdge*(enc: Encoder): bool {.importcpp: "#.FallingEdge()", header: "daisy_seed.h".}
  ## Check if the encoder button was just released
proc timeHeld*(enc: Encoder): cfloat {.importcpp: "#.TimeHeldMs()", header: "daisy_seed.h".}
  ## Get how long the encoder button has been held, in milliseconds

proc initEncoder*(pinA, pinB: Pin, clickPin: Pin = Pin(), updateRate: float = 1000.0): Encoder =
  ## Initialize a rotary encoder (retained: constructor + config assembly).
  ##
  ## Parameters:
  ##   pinA, pinB: Encoder signal pins
  ##   clickPin: Optional click button pin (use Pin() to skip)
  ##   updateRate: How often to check the encoder (Hz)
  ##
  ## Example:
  ## ```nim
  ## var encoder = initEncoder(D0(), D1(), D2())  # With click
  ## ```
  result = newEncoder()
  result.init(pinA, pinB, clickPin, updateRate.cfloat)

# =============================================================================
# AnalogControl (bind-once + retained float overloads)
# =============================================================================
proc init*(ctrl: var AnalogControl, adcptr: ptr uint16, sr: cfloat, flip: bool = false,
           invert: bool = false, slewSeconds: cfloat = 0.002)
  {.importcpp: "#.Init(@)", header: "hid/ctrl.h".}
proc initBipolarCv*(ctrl: var AnalogControl, adcptr: ptr uint16, sr: cfloat)
  {.importcpp: "#.InitBipolarCv(@)", header: "hid/ctrl.h".}
proc process*(ctrl: var AnalogControl): cfloat {.importcpp: "#.Process()", header: "hid/ctrl.h".}
  ## Process the analog input and return the filtered value
proc value*(ctrl: AnalogControl): cfloat {.importcpp: "#.Value()", header: "hid/ctrl.h".}
  ## Get the current stored value without reprocessing
proc setCoeff*(ctrl: var AnalogControl, val: cfloat) {.importcpp: "#.SetCoeff(@)", header: "hid/ctrl.h".}
proc setScale*(ctrl: var AnalogControl, scale: cfloat) {.importcpp: "#.SetScale(@)", header: "hid/ctrl.h".}
proc setOffset*(ctrl: var AnalogControl, offset: cfloat) {.importcpp: "#.SetOffset(@)", header: "hid/ctrl.h".}
proc setSampleRate*(ctrl: var AnalogControl, sampleRate: cfloat) {.importcpp: "#.SetSampleRate(@)", header: "hid/ctrl.h".}
proc getRawValue*(ctrl: var AnalogControl): uint16 {.importcpp: "#.GetRawValue()", header: "hid/ctrl.h".}
  ## Get the raw unsigned 16-bit ADC value (0 to 65535)
proc getRawFloat*(ctrl: var AnalogControl): cfloat {.importcpp: "#.GetRawFloat()", header: "hid/ctrl.h".}
  ## Get a normalized float representing the raw ADC value (0.0 to 1.0)

# Retained ergonomics overloads: Nim float parameters cast to cfloat (see design D1)
proc setCoeff*(ctrl: var AnalogControl, coefficient: float) {.inline.} = ctrl.setCoeff(coefficient.cfloat)
  ## Set the coefficient of the one-pole smoothing filter (0.0 to 1.0;
  ## higher = less smoothing / faster response)
proc setScale*(ctrl: var AnalogControl, scale: float) {.inline.} = ctrl.setScale(scale.cfloat)
  ## Set the scaling factor applied by `process`
proc setOffset*(ctrl: var AnalogControl, offset: float) {.inline.} = ctrl.setOffset(offset.cfloat)
  ## Set the offset added to the processed value
proc setSampleRate*(ctrl: var AnalogControl, sampleRate: float) {.inline.} = ctrl.setSampleRate(sampleRate.cfloat)
  ## Set a new sample rate after initialization (Hz)

proc initAnalogControl*(adcPtr: ptr uint16, sampleRate: float, flip: bool = false,
                        invert: bool = false, slewSeconds: float = 0.002): AnalogControl =
  ## Initialize an AnalogControl for a potentiometer or CV input
  ## (retained: constructor + config assembly).
  ##
  ## This provides filtered, smoothed analog input with slew limiting.
  ##
  ## Parameters:
  ##   adcPtr: Pointer to raw ADC value (from AdcHandle.getPtr())
  ##   sampleRate: Rate at which `process` will be called (Hz)
  ##   flip: If true, flip the input (1.0 - input)
  ##   invert: If true, invert the input (-1.0 * input)
  ##   slewSeconds: Slew time in seconds for value changes (smoothing)
  ##
  ## Example:
  ## ```nim
  ## var knob = initAnalogControl(daisy.adc.getPtr(0), 1000.0)
  ## ```
  result = newAnalogControl()
  result.init(adcPtr, sampleRate.cfloat, flip, invert, slewSeconds.cfloat)

proc initBipolarCv*(adcPtr: ptr uint16, sampleRate: float): AnalogControl =
  ## Initialize an AnalogControl for bipolar CV input (-5V to +5V)
  ## (retained: constructor + config assembly).
  ##
  ## The output is in the range -1.0 to +1.0.
  ##
  ## Example:
  ## ```nim
  ## var cvInput = initBipolarCv(daisy.adc.getPtr(0), 1000.0)
  ## ```
  result = newAnalogControl()
  result.initBipolarCv(adcPtr, sampleRate.cfloat)

# =============================================================================
# AdcReader - convenience wrapper over the Onboard ADC of a DaisySeed
# (uses per/adc bindings for config construction; internal helpers bind the
#  embedded `DaisySeed::adc` member)
# =============================================================================
const MAX_ADC_CHANNELS = 16

type
  AdcReader* = object
    configs: array[MAX_ADC_CHANNELS, AdcChannelConfig]
    daisy: ptr DaisySeed
    numChannels: int

# Internal bindings for the DaisySeed's embedded adc member (used by AdcReader)
proc initAdc(hw: var DaisySeed, ca: ptr AdcChannelConfig, numChannels: csize_t,
             ovs: OverSampling = OVS_32) {.importcpp: "#.adc.Init(@)", header: "daisy_seed.h".}
proc startAdc(hw: var DaisySeed) {.importcpp: "#.adc.Start()", header: "daisy_seed.h".}
proc stopAdc(hw: var DaisySeed) {.importcpp: "#.adc.Stop()", header: "daisy_seed.h".}
proc getAdc(hw: var DaisySeed, chn: uint8): uint16 {.importcpp: "#.adc.Get(@)", header: "daisy_seed.h".}
proc getAdcFloat(hw: var DaisySeed, chn: uint8): cfloat {.importcpp: "#.adc.GetFloat(@)", header: "daisy_seed.h".}

proc initAdc*(daisy: var DaisySeed, pins: openArray[Pin],
              oversampling: int = 4): AdcReader =
  ## Initialize ADC for reading analog inputs (retained: fixed-size config
  ## array + openArray handling).
  ##
  ## Parameters:
  ##   daisy: The DaisySeed instance
  ##   pins: Array of analog pins to read (e.g., [A0(), A1(), A2()])
  ##   oversampling: Oversampling rate (0=NONE, 1=4x, 2=8x, 3=16x, 4=32x (default), 5=64x, etc.)
  ##
  ## Example:
  ## ```nim
  ## var adc = initAdc(daisy, [A0(), A1(), A6()])
  ## adc.start()
  ## let knob1Value = adc.value(0)  # Read first channel
  ## ```
  result.daisy = addr daisy
  result.numChannels = pins.len

  if pins.len > MAX_ADC_CHANNELS:
    # In embedded systems there is no graceful recovery; clamp to the max.
    result.numChannels = MAX_ADC_CHANNELS

  for i in 0..<result.numChannels:
    result.configs[i] = newAdcChannelConfig()
    result.configs[i].initSingle(pins[i])

  if result.numChannels > 0:
    daisy.initAdc(addr result.configs[0], result.numChannels.csize_t, cast[OverSampling](oversampling))

proc start*(adc: var AdcReader) =
  ## Start ADC conversions
  adc.daisy[].startAdc()

proc stop*(adc: var AdcReader) =
  ## Stop ADC conversions
  adc.daisy[].stopAdc()

proc rawValue*(adc: var AdcReader, channel: int): uint16 =
  ## Get raw ADC value (0-65535) for a channel
  adc.daisy[].getAdc(channel.uint8)

proc value*(adc: var AdcReader, channel: int): float =
  ## Get normalized ADC value (0.0-1.0) for a channel
  adc.daisy[].getAdcFloat(channel.uint8)

when isMainModule:
  echo "libDaisy Controls wrapper - Clean API"
