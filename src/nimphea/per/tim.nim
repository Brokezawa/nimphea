## Hardware Timer (TIM)
## ====================
##
## Hardware timer peripheral support for Daisy Seed.
##
## Supports general-purpose TIM peripherals:
## - TIM2, TIM5 (32-bit counters)
## - TIM3, TIM4 (16-bit counters)
##
## **Features:**
## - High-precision timing (up to 200MHz/240MHz)
## - Tick-based or time-based measurements (us/ms)
## - Configurable period and prescaler
## - User callbacks on period elapsed
## - Blocking delays (delayTick, delayMs, delayUs)
##
## **Note:** DaisySeed uses TIM2 internally for timing/delay purposes at maximum frequency.
##
## **Usage:**
## ```nim
## import nimphea/per/tim
##
## var timer: TimerHandle
## var config = createTimerConfig()
## config.periph = TIM_PERIPH_TIM2
## config.dir = TIMER_DIR_UP
## config.period = 0xffffffff  # Max for 32-bit
## config.enable_irq = false
##
## discard timer.init(config)
## discard timer.start()
##
## # Get current tick
## let tick = timer.getTick()
##
## # Delay for 1000us
## timer.delayUs(1000)
## ```

import nimphea/nimphea_macros

useNimpheaModules(tim)

type
  TimerPeripheral* {.importcpp: "daisy::TimerHandle::Config::Peripheral",
                     header: "per/tim.h".} = enum
    ## Hardware timer peripheral selection
    TIM_PERIPH_TIM2 = 0  ## 32-bit counter (recommended for long periods)
    TIM_PERIPH_TIM3      ## 16-bit counter
    TIM_PERIPH_TIM4      ## 16-bit counter
    TIM_PERIPH_TIM5      ## 32-bit counter

  TimerCounterDir* {.importcpp: "daisy::TimerHandle::Config::CounterDir",
                     header: "per/tim.h".} = enum
    ## Counter direction
    TIMER_DIR_UP = 0     ## Count up from 0 to period
    TIMER_DIR_DOWN       ## Count down from period to 0

  TimerResult* {.importcpp: "daisy::TimerHandle::Result",
                 header: "per/tim.h".} = enum
    ## Return values for timer functions
    TIMER_OK = 0         ## Operation successful
    TIMER_ERR            ## Operation failed

  TimerConfig* {.importcpp: "daisy::TimerHandle::Config",
                 header: "per/tim.h", bycopy.} = object
    ## Timer configuration structure
    periph*: TimerPeripheral    ## Hardware peripheral to use
    dir*: TimerCounterDir       ## Counter direction
    period*: uint32             ## Period in ticks (max: 0xffff for 16-bit, 0xffffffff for 32-bit)
    enable_irq*: bool           ## Enable interrupt for callbacks

  TimerHandle* {.importcpp: "daisy::TimerHandle",
                 header: "per/tim.h".} = object
    ## Hardware timer handle
    ##
    ## Provides access to one of the four general-purpose timers (TIM2-TIM5).

  TimerCallback* = proc(data: pointer) {.cdecl.}
    ## User callback type that fires at the end of each timer period
    ##
    ## **Note:** Requires `enable_irq = true` in config

# Constructor for config with defaults
proc createTimerConfig*(): TimerConfig {.importcpp: "daisy::TimerHandle::Config()".}
  ## Create a timer configuration with default values
  ##
  ## **Defaults:**
  ## - periph: TIM_PERIPH_TIM2
  ## - dir: TIMER_DIR_UP
  ## - period: 0xffffffff (max for 32-bit)
  ## - enable_irq: false

# Timer methods (bind-once)
proc init*(timer: var TimerHandle, config: TimerConfig): TimerResult {.importcpp: "#.Init(@)".}
  ## Initialize the timer according to the configuration.
  ##
  ## **Example:**
  ## ```nim
  ## var timer: TimerHandle
  ## var config = createTimerConfig()
  ## config.periph = TIM_PERIPH_TIM5
  ## config.period = 10000  # Wrap every 10000 ticks
  ## discard timer.init(config)
  ## ```
proc deinit*(timer: var TimerHandle): TimerResult {.importcpp: "#.DeInit()".}
  ## Deinitialize the timer.
proc getConfig*(timer: TimerHandle): TimerConfig {.importcpp: "#.GetConfig()".}
  ## Returns the current configuration.

proc setPeriod*(timer: var TimerHandle, ticks: uint32): TimerResult {.importcpp: "#.SetPeriod(@)".}
  ## Set the timer period in ticks; can be changed on-the-fly while running.
  ##
  ## **Example:**
  ## ```nim
  ## discard timer.setPeriod(200_000_000)  # Wrap every second at 200MHz
  ## ```
proc setPrescaler*(timer: var TimerHandle, val: uint32): TimerResult {.importcpp: "#.SetPrescaler(@)".}
  ## Set the prescaler applied to the TIM peripheral; can be changed on-the-fly.
  ##
  ## **Example:**
  ## ```nim
  ## discard timer.setPrescaler(200)  # Divide by 200 to get 1MHz ticks from 200MHz
  ## ```

proc start*(timer: var TimerHandle): TimerResult {.importcpp: "#.Start()".}
  ## Start the timer peripheral.
proc stop*(timer: var TimerHandle): TimerResult {.importcpp: "#.Stop()".}
  ## Stop the timer peripheral.

proc getFreq*(timer: var TimerHandle): uint32 {.importcpp: "#.GetFreq()".}
  ## Returns the tick frequency in Hz (typically 200MHz, or 240MHz in boost mode).
proc getTick*(timer: var TimerHandle): uint32 {.importcpp: "#.GetTick()".}
  ## Returns the current counter position.
  ##
  ## **Example:**
  ## ```nim
  ## let start = timer.getTick()
  ## # ... do work ...
  ## let elapsed = timer.getTick() - start
  ## ```
proc getMs*(timer: var TimerHandle): uint32 {.importcpp: "#.GetMs()".}
  ## Returns ticks scaled as milliseconds.
  ##
  ## **Warning:** Ensure the period can handle the max measurement to avoid wrapping!
proc getUs*(timer: var TimerHandle): uint32 {.importcpp: "#.GetUs()".}
  ## Returns ticks scaled as microseconds.
  ##
  ## **Warning:** Ensure the period can handle the max measurement to avoid wrapping!

proc delayTick*(timer: var TimerHandle, del: uint32) {.importcpp: "#.DelayTick(@)".}
  ## Blocking delay for the specified number of ticks.
  ##
  ## **Example:**
  ## ```nim
  ## timer.delayTick(1000)  # Wait 1000 ticks
  ## ```
proc delayMs*(timer: var TimerHandle, del: uint32) {.importcpp: "#.DelayMs(@)".}
  ## Blocking delay for the specified number of milliseconds.
  ##
  ## **Example:**
  ## ```nim
  ## timer.delayMs(100)  # Wait 100ms
  ## ```
proc delayUs*(timer: var TimerHandle, del: uint32) {.importcpp: "#.DelayUs(@)".}
  ## Blocking delay for the specified number of microseconds.
  ##
  ## **Example:**
  ## ```nim
  ## timer.delayUs(500)  # Wait 500us (0.5ms)
  ## ```

proc setCallback*(timer: var TimerHandle, cb: TimerCallback, data: pointer = nil)
  {.importcpp: "#.SetCallback(@)".}
  ## Set the callback that fires when the timer reaches the end of a period.
  ##
  ## **Note:** Requires `enable_irq = true` in config.
  ##
  ## **Example:**
  ## ```nim
  ## proc onPeriod(data: pointer) {.cdecl.} =
  ##   hw.setLed(true)
  ## timer.setCallback(onPeriod, nil)
  ## ```
