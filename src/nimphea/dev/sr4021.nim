## 74HC4021 Shift Register Module - 8-bit Parallel-to-Serial Input
##
## Device driver for CD4021B 8-bit shift register (input expander).
## Supports daisy-chaining and parallel chains.
##
## **Hardware:** CD4021B CMOS 8-stage static shift register
## **Interface:** Parallel input, serial output
## **Supply:** 3V-18V (3.3V compatible)
## **Clock Freq:** Up to 3MHz at 5V, 8.5MHz at 15V
##
## **Pin Connections:**
## - Pin 10 → CLK (clock)
## - Pin 9  → P/!S (parallel load / serial shift, active LOW for load)
## - Pin 11 → Q7 (serial data output)
## - Pins 7,6,5,4,13,14,15,1 → P0-P7 (parallel data inputs)
##
## **Daisy Chaining:**
## Connect Q7 (pin 11) of first device to parallel input of next device.
##
## **Parallel Chains:**
## Multiple chains can share CLK and LATCH pins with separate data lines.
##
## **Data Layout:**
## When using multiple devices (example: 2 daisy-chained, 2 parallel):
## - states[0-7]   = Chain 0, Parallel 0
## - states[8-15]  = Chain 1, Parallel 0
## - states[16-23] = Chain 0, Parallel 1
## - states[24-31] = Chain 1, Parallel 1
##
## **Example:**
## ```nim
## import nimphea
## import nimphea/dev/sr4021
##
## # Single device
## var sr: ShiftRegister4021[1, 1]
## var cfg: ShiftRegister4021Config[1, 1]
## cfg.clk = newPin(PORTB, 0)
## cfg.latch = newPin(PORTB, 1)
## cfg.data[0] = newPin(PORTB, 2)
## cfg.delay_ticks = 10
##
## sr.init(cfg)
## sr.update()  # Read inputs
## if sr.state(0):  # Check pin P0
##   echo "Button pressed"
## ```

import nimphea


{.push header: "dev/sr_4021.h".}

type
  ShiftRegister4021Config*[NumDaisy, NumParallel: static int]
    {.importcpp: "daisy::ShiftRegister4021<#,#>::Config", bycopy.} = object
    clk* {.importcpp: "clk".}: Pin
    latch* {.importcpp: "latch".}: Pin
    data* {.importcpp: "data".}: array[NumParallel, Pin]
    delay_ticks* {.importcpp: "delay_ticks".}: uint32

  ShiftRegister4021*[NumDaisy, NumParallel: static int]
    {.importcpp: "daisy::ShiftRegister4021<#,#>", bycopy.} = object

# C++ API (bind-once)
proc init*[ND, NP](sr: var ShiftRegister4021[ND, NP],
                   cfg: ShiftRegister4021Config[ND, NP]) {.importcpp: "#.Init(@)".}
  ## Initialize shift register(s).
  ##
  ## **Parameters:**
  ## - `cfg`: Configuration with pins and delay settings
  ##
  ## **Template Parameters:**
  ## - `ND`: Number of daisy-chained devices
  ## - `NP`: Number of parallel chains
  ##
  ## Total inputs = 8 × ND × NP
proc update*[ND, NP](sr: var ShiftRegister4021[ND, NP]) {.importcpp: "#.Update()".}
  ## Read all inputs from shift register(s).
  ##
  ## Call this periodically (e.g., in your main loop) to sample all inputs.
  ## The states are stored internally and can be read with `state()`.
proc state*[ND, NP](sr: ShiftRegister4021[ND, NP], index: cint): bool {.importcpp: "#.State(@)".}
  ## Get the state of an input by C++ index.
proc getConfig*[ND, NP](sr: ShiftRegister4021[ND, NP]): ShiftRegister4021Config[ND, NP]
  {.importcpp: "#.GetConfig()".}
  ## Get the current configuration.

# Retained ergonomics overload: Nim int index cast to cint (see design D1)
proc state*[ND, NP](sr: ShiftRegister4021[ND, NP], index: int): bool {.inline.} = sr.state(index.cint)
  ## Get the state of an input.
  ##
  ## **Parameters:**
  ## - `index`: Input index (0 to 8×ND×NP - 1)
  ##
  ## **Returns:** true if input is HIGH, false if LOW
  ##
  ## **Note:** Call `update()` first to refresh the input states.
