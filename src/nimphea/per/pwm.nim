## PWM (Pulse Width Modulation) support for libDaisy Nim wrapper
##
## This module provides hardware PWM support using the STM32 timer peripherals.
## PWM is useful for LED control, motor control, servo control, and generating
## analog-like signals.
##
## Example - Simple LED dimming:
## ```nim
## import nimphea, per/pwm
##
## var hw = initDaisy()
##
## # Initialize PWM on TIM3, channel 2 (internal LED on Daisy Seed)
## var pwm = newPwmHandle()
## discard pwm.initPwm(TIM_3, frequency = hz(1000.0))  # 1kHz
## discard pwm.channel2.init()
##
## # Fade LED in and out
## while true:
##   for brightness in 0..100:
##     pwm.channel2.set(brightness / 100.0)
##     hw.delay(ms(10))
##   for brightness in countdown(100, 0):
##     pwm.channel2.set(brightness / 100.0)
##     hw.delay(ms(10))
## ```
##
## Example - Multiple channels:
## ```nim
## # TIM4 with 4 channels (RGB LED + servo)
## var pwm = newPwmHandle()
## discard pwm.initPwm(TIM_4, frequency = hz(50.0))  # 50Hz for servo
##
## # Configure channels with specific pins
## discard pwm.channel1.init(D13)  # Red LED
## discard pwm.channel2.init(D14)  # Green LED
## discard pwm.channel3.init(D11)  # Blue LED
## discard pwm.channel4.init(D12)  # Servo control
##
## # Set RGB color and servo position
## pwm.channel1.set(1.0)    # Red full
## pwm.channel2.set(0.5)    # Green half
## pwm.channel3.set(0.0)    # Blue off
## pwm.channel4.set(0.075)  # Servo center (1.5ms @ 50Hz)
## ```

import nimphea

# Use the macro system for this module's compilation unit

{.push header: "daisy_seed.h".}

type
  # PWM Timer peripheral selection
  PwmPeripheral* {.importcpp: "daisy::PWMHandle::Config::Peripheral", size: sizeof(cint).} = enum
    TIM_3 = 0  ## TIM3 - 16-bit counter
    TIM_4 = 1  ## TIM4 - 16-bit counter
    TIM_5 = 2  ## TIM5 - 32-bit counter

  # PWM Result codes
  PwmResult* {.importcpp: "daisy::PWMHandle::Result", size: sizeof(cint).} = enum
    PWM_OK = 0
    PWM_ERR = 1

  # Channel polarity
  PwmPolarity* {.importcpp: "daisy::PWMHandle::Channel::Config::Polarity", size: sizeof(cint).} = enum
    POLARITY_HIGH = 0  ## Output high when active
    POLARITY_LOW       ## Output low when active

  # PWM Configuration
  PwmConfigRaw* {.importcpp: "daisy::PWMHandle::Config", bycopy.} = object
    periph* {.importc: "periph".}: PwmPeripheral
    prescaler* {.importc: "prescaler".}: uint32
    period* {.importc: "period".}: uint32

  # Channel Configuration
  PwmChannelConfig* {.importcpp: "daisy::PWMHandle::Channel::Config", bycopy.} = object
    pin* {.importc: "pin".}: Pin
    polarity* {.importc: "polarity".}: PwmPolarity

  # PWM Handle - must be declared before Channel since Channel references it
  PwmHandleRaw* {.importcpp: "daisy::PWMHandle".} = object

  # PWM Channel - nested class reference
  PwmChannel* {.importcpp: "daisy::PWMHandle::Channel".} = object

{.pop.} # header

# C++ constructors
proc newPwmHandle*(): PwmHandleRaw
  {.importcpp: "daisy::PWMHandle()", constructor, header: "daisy_seed.h".}

proc newPwmConfigRaw(periph: PwmPeripheral, prescaler: uint32, period: uint32): PwmConfigRaw
  {.importcpp: "daisy::PWMHandle::Config(@)", constructor, header: "daisy_seed.h".}

proc newPwmChannelConfig*(pin: Pin, polarity: PwmPolarity): PwmChannelConfig
  {.importcpp: "daisy::PWMHandle::Channel::Config(@)", constructor, header: "daisy_seed.h".}

# PwmHandle (bind-once)
# =============================================================================
proc init*(pwm: var PwmHandleRaw, config: PwmConfigRaw): PwmResult
  {.importcpp: "#.Init(@)", header: "daisy_seed.h".}
  ## Initialize the PWM peripheral from a config
proc deinit*(pwm: var PwmHandleRaw): PwmResult
  {.importcpp: "#.DeInit()", header: "daisy_seed.h".}
  ## Deinitialize the PWM peripheral

proc channel1*(pwm: var PwmHandleRaw): var PwmChannel {.importcpp: "#.Channel1()", header: "daisy_seed.h".}
  ## Get reference to channel 1
proc channel2*(pwm: var PwmHandleRaw): var PwmChannel {.importcpp: "#.Channel2()", header: "daisy_seed.h".}
  ## Get reference to channel 2
proc channel3*(pwm: var PwmHandleRaw): var PwmChannel {.importcpp: "#.Channel3()", header: "daisy_seed.h".}
  ## Get reference to channel 3
proc channel4*(pwm: var PwmHandleRaw): var PwmChannel {.importcpp: "#.Channel4()", header: "daisy_seed.h".}
  ## Get reference to channel 4

proc setPrescaler*(pwm: var PwmHandleRaw, prescaler: uint32)
  {.importcpp: "#.SetPrescaler(@)", header: "daisy_seed.h".}
  ## Change the prescaler after initialization
proc setPeriod*(pwm: var PwmHandleRaw, period: uint32)
  {.importcpp: "#.SetPeriod(@)", header: "daisy_seed.h".}
  ## Change the period after initialization (affects frequency and resolution)

# =============================================================================
# PwmChannel (bind-once + retained pin config assembly)
# =============================================================================
proc init*(channel: var PwmChannel, config: PwmChannelConfig): PwmResult
  {.importcpp: "#.Init(@)", header: "daisy_seed.h".}
proc init*(channel: var PwmChannel): PwmResult
  {.importcpp: "#.Init()", header: "daisy_seed.h".}
proc deinit*(channel: var PwmChannel): PwmResult
  {.importcpp: "#.DeInit()", header: "daisy_seed.h".}

proc init*(channel: var PwmChannel, pin: Pin, polarity: PwmPolarity = POLARITY_HIGH): PwmResult =
  ## Initialize a PWM channel on the given pin (retained: config assembly).
  ## Passing `Pin()` selects the channel's default pin.
  ##
  ## Example:
  ## ```nim
  ## pwm.channel1.init(D13)
  ## pwm.channel2.init()   # default pin
  ## ```
  if pin.port == PORTX:
    channel.init()
  else:
    var config = newPwmChannelConfig(pin, polarity)
    channel.init(config)

proc set*(channel: var PwmChannel, val: cfloat) {.importcpp: "#.Set(@)", header: "daisy_seed.h".}
  ## Set PWM duty cycle in the C++ float range 0.0..1.0 (raw binding)
proc set*(channel: var PwmChannel, dutyCycle: DutyCycle) {.inline.} = channel.set(dutyCycle.cfloat)
  ## Set PWM duty cycle (0.0 to 1.0) with the `DutyCycle` unit type
  ##
  ## Example:
  ## ```nim
  ## channel.set(duty(0.5))   # 50% duty cycle
  ## ```

proc setRaw*(channel: var PwmChannel, value: uint32)
  {.importcpp: "#.SetRaw(@)", header: "daisy_seed.h".}
  ## Set PWM duty cycle as a raw counter value (must be <= the timer's period)

# =============================================================================
# Value-adding helpers
# =============================================================================

proc calculatePwmParams(frequency: float, prescaler: var uint32, period: var uint32) =
  ## Calculate prescaler and period for a given frequency.
  ## System clock is 480MHz for STM32H750.
  const SYSCLK = 480_000_000.0

  # PWM frequency = SYSCLK / (2 * (period + 1) * (prescaler + 1))
  # We want to maximize period for best resolution

  if frequency <= 0.0:
    # Default to 1kHz
    prescaler = 0
    period = 0xFFFF
    return

  # Try prescaler = 0 first (no division)
  let targetTicks = SYSCLK / (2.0 * frequency)

  if targetTicks <= 0xFFFFFFFF.float:
    # Period fits the counter width (16-bit timers clamp in initPwm, TIM5 is 32-bit)
    prescaler = 0
    period = uint32(targetTicks) - 1
  else:
    # Need prescaler
    prescaler = uint32((targetTicks / 0xFFFF.float)) - 1
    let adjustedTicks = SYSCLK / (2.0 * frequency * (prescaler.float + 1.0))
    period = uint32(adjustedTicks) - 1

proc initPwm*[P: static PwmPeripheral](pwm: var PwmHandleRaw,
              frequency: Hz = hz(1000.0)): PwmResult =
  ## Initialize a PWM handle with a target frequency.
  ## (channels must still be initialized individually; the C++ handles are
  ## non-copyable, so the caller owns the handle and this fills it in place)
  ##
  ## Parameters:
  ##   pwm: handle created with `newPwmHandle(TIM_3)`-style ownership: declare
  ##        `var pwm = newPwmHandle()` and fill it in place
  ##   frequency: Target frequency in Hz (default 1000Hz / 1kHz)
  ##   (the timer bank is the static parameter `P`)
  ##
  ## Example:
  ## ```nim
  ## var pwm = newPwmHandle()
  ## discard initPwm[TIM_3](pwm, hz(1000.0))  # 1kHz
  ## pwm.channel1.init()
  ## ```
  var prescaler, period: uint32
  calculatePwmParams(frequency.float, prescaler, period)
  # For 16-bit timers (TIM3, TIM4), clamp period to 16-bit max
  if P != TIM_5 and period > 0xFFFF:
    period = 0xFFFF
  var config = newPwmConfigRaw(P, prescaler, period)
  result = init(pwm, config)

proc initPwmCustom*[P: static PwmPeripheral](pwm: var PwmHandleRaw,
                    prescaler: uint32, period: uint32): PwmResult =
  ## Initialize a PWM handle with explicit prescaler and period values.
  ## Frequency = SYSCLK / (2 * (period + 1) * (prescaler + 1))
  ##
  ## Example:
  ## ```nim
  ## # 100Hz PWM with maximum resolution
  ## var pwm = newPwmHandle[TIM_5]()
  ## discard pwm.initPwmCustom(0, 2_400_000)
  ## ```
  var config = newPwmConfigRaw(P, prescaler, period)
  result = init(pwm, config)

when isMainModule:
  echo "libDaisy PWM wrapper - Clean API"
