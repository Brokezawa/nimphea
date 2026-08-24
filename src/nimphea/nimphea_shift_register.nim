## nimphea_shift_register
## ========================
##
## Nim wrapper for CD4021 shift register device driver (friendly layer over
## `dev/sr4021`, which owns the generic `ShiftRegister4021[ND, NP]` bindings).
##
## The CD4021 is an 8-stage CMOS shift register commonly used for:
## - Expanding digital inputs (buttons, switches)
## - Keyboard scanning (e.g., Daisy Field uses 2 daisy-chained for 16 keys)
## - General-purpose parallel-to-serial conversion
##
## **Hardware Specifications:**
## - Supply Voltage: 3V to 18V
## - Clock Frequency: 3MHz at 5V, 8.5MHz at 15V
## - 8 parallel inputs per device
## - Supports daisy-chaining (series connection)
## - Supports parallel operation (multiple data lines, shared clock/latch)
##
## **Example - Simple 8-button scanner:**
## ```nim
## import nimphea
## import nimphea_shift_register
##
## var sr: ShiftRegister4021_1  # Single device (8 inputs)
## var config: ShiftRegisterConfig_1
##
## config.clk = D0()
## config.latch = D1()
## config.data[0] = D2()
## config.delay_ticks = 10
##
## sr.init(config)
##
## while true:
##   sr.update()  # Read all 8 inputs
##
##   for i in 0..<8:
##     if sr.state(i):
##       # Button i is pressed (HIGH)
##
##   hw.delay(10)
## ```
##
## **Example - Daisy Field keyboard (16 keys, 2 chained devices):**
## ```nim
## var keyboard: ShiftRegister4021_2  # 2 daisy-chained devices
## var config: ShiftRegisterConfig_2
##
## config.clk = D8()
## config.latch = D7()
## config.data[0] = D10()
##
## keyboard.init(config)
##
## while true:
##   keyboard.update()
##
##   for key in 0..<16:  # 8 inputs × 2 devices
##     if keyboard.state(key):
##       # Key is pressed
## ```

import nimphea
import nimphea/dev/sr4021
export sr4021

# Convenience aliases for common configurations
type
  ShiftRegisterConfig_1* = ShiftRegister4021Config[1, 1]  ## Single device (8 inputs)
  ShiftRegisterConfig_2* = ShiftRegister4021Config[2, 1]  ## 2 chained devices (16 inputs)
  ShiftRegisterConfig_3* = ShiftRegister4021Config[3, 1]  ## 3 chained devices (24 inputs)
  ShiftRegisterConfig_4* = ShiftRegister4021Config[4, 1]  ## 4 chained devices (32 inputs)
  ShiftRegisterConfig_1x2* = ShiftRegister4021Config[1, 2]  ## 1 device × 2 lines (16 inputs)
  ShiftRegisterConfig_2x2* = ShiftRegister4021Config[2, 2]  ## 2 devices × 2 lines (32 inputs)

  ShiftRegister4021_1* = ShiftRegister4021[1, 1]  ## Single CD4021 shift register (8 inputs)
  ShiftRegister4021_2* = ShiftRegister4021[2, 1]  ## 2 daisy-chained devices (16 inputs)
  ## Used by Daisy Field for keyboard scanning
  ShiftRegister4021_3* = ShiftRegister4021[3, 1]  ## 3 daisy-chained devices (24 inputs)
  ShiftRegister4021_4* = ShiftRegister4021[4, 1]  ## 4 daisy-chained devices (32 inputs)
  ShiftRegister4021_1x2* = ShiftRegister4021[1, 2]  ## 1 device × 2 parallel lines (16 inputs)
  ShiftRegister4021_2x2* = ShiftRegister4021[2, 2]  ## 2 devices × 2 parallel lines (32 inputs)

# Convenience helper for the common case: checking if a button is pressed (active-low)
proc pressed*[ND, NP](sr: ShiftRegister4021[ND, NP], index: int): bool {.inline.} =
  ## Check if the button at `index` is pressed (active-low logic).
  ##
  ## Assumes buttons connect input to ground when pressed.
  ## Returns `true` when the button is pressed.
  not sr.state(index)