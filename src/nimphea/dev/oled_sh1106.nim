## SH1106 OLED Display driver for libDaisy Nim wrapper
##
## The SH1106 is a popular and cost-effective alternative to the SSD1306 OLED controller.
## It is nearly identical to the SSD130x series, with the primary difference being the
## column addressing scheme used in the Update() method. This driver extends the SSD130x
## driver and only overrides the Update() implementation.
##
## **Features:**
## - 128x64 monochrome display support
## - I2C and 4-wire SPI transport options
## - Compatible with SSD130x API (drop-in replacement)
## - Same drawing functions as SSD130x (pixel, line, rect, circle, etc.)
##
## **Hardware Notes:**
## - Common in cheap OLED modules (often labeled "SSD1306 compatible")
## - Column addressing differs: uses 0x02 base instead of 0x00
## - Uses same transports (SSD130xI2CTransport, SSD130x4WireSpiTransport)
##
## Example - I2C display:
## ```nim
## import nimphea
## import nimphea/dev/oled_sh1106
##
## var display = initSH1106I2c(128, 64)
## display.fill(false)
## display.drawPixel(64, 32, true)
## display.drawCircle(64, 32, 10, true)
## display.update()
## ```
##
## Example - SPI display (faster updates):
## ```nim
## import nimphea
## import nimphea/dev/oled_sh1106
##
## var display = initSH1106Spi(128, 64)
## while true:
##   display.fill(false)
##   display.drawRect(10, 10, 108, 44, true)
##   display.update()
##   hw.delay(50)
## ```
##
## **Differences from SSD130x:**
## - Update() uses different column start address (0x02 vs 0x00)
## - Same initialization sequence
## - Same framebuffer format
## - Same drawing API

import nimphea
export nimphea_core_types
import nimphea/per/i2c
import nimphea/per/spi
import nimphea/nimphea_macros
# Shared 2D drawing primitives (drawLine/drawRect/fillRect/drawCircle)
import nimphea/hid/disp/draw2d

useNimpheaModules(i2c, spi, sh1106)

{.push header: "daisy_seed.h".}
{.push importcpp.}

type
  # Pre-instantiated SH1106 Display types from libDaisy
  # Using the short typedefs defined in the macro system (SH1106I2c128x64, SH1106Spi128x64)
  # I2C variant (128x64 only)
  SH1106I2c128x64* {.importcpp: "SH1106I2c128x64".} = object
  
  # SPI variant (128x64 only)
  SH1106Spi128x64* {.importcpp: "SH1106Spi128x64".} = object
  
  # Config structs - reuse SSD130x transport types from nimphea_core_types
  # (identical structure)
  SH1106I2cConfig* {.importcpp: "SH1106I2c128x64::Config", bycopy.} = object
    transport_config* {.importc: "transport_config".}: SSD130xI2CTransportConfig
  
  SH1106SpiConfig* {.importcpp: "SH1106Spi128x64::Config", bycopy.} = object
    transport_config* {.importc: "transport_config".}: SSD130x4WireSpiTransportConfig
  
  # Union type for generic operations
  OledSH1106* = SH1106I2c128x64 | SH1106Spi128x64

{.pop.} # importcpp
{.pop.} # header

# Generic C++ member functions
proc Init[T, C](display: var T, config: C) {.importcpp: "#.Init(@)", header: "daisy_seed.h".}
proc Width[T](display: T): csize_t {.importcpp: "#.Width()", header: "daisy_seed.h".}
proc Height[T](display: T): csize_t {.importcpp: "#.Height()", header: "daisy_seed.h".}
proc DrawPixel[T](display: var T, x: uint8, y: uint8, on: bool) {.importcpp: "#.DrawPixel(@)", header: "daisy_seed.h".}
proc Fill[T](display: var T, on: bool) {.importcpp: "#.Fill(@)", header: "daisy_seed.h".}
proc Update[T](display: var T) {.importcpp: "#.Update()", header: "daisy_seed.h".}

# Constructors
proc newSH1106I2c(): SH1106I2c128x64 {.importcpp: "SH1106I2c128x64()", constructor, header: "daisy_seed.h".}
proc newSH1106Spi(): SH1106Spi128x64 {.importcpp: "SH1106Spi128x64()", constructor, header: "daisy_seed.h".}

proc newSH1106I2cConfig(): SH1106I2cConfig {.importcpp: "SH1106I2c128x64::Config()", constructor, header: "daisy_seed.h".}
proc newSH1106SpiConfig(): SH1106SpiConfig {.importcpp: "SH1106Spi128x64::Config()", constructor, header: "daisy_seed.h".}

# Transport defaults (reuse SSD130x transport defaults)
proc Defaults*(config: var SSD130xI2CTransportConfig) {.importcpp: "#.Defaults()", header: "daisy_seed.h".}
proc Defaults*(config: var SSD130x4WireSpiTransportConfig) {.importcpp: "#.Defaults()", header: "daisy_seed.h".}

# =============================================================================
# High-Level Nim API
# =============================================================================

template initSH1106I2c*(width, height: static[int], 
                        sclPin: Pin = newPin(PORTB, 8), 
                        sdaPin: Pin = newPin(PORTB, 9), 
                        address: uint8 = 0x3C): untyped =
  ## Initialize SH1106 OLED via I2C
  ## 
  ## **Parameters:**
  ## - `width`, `height` - Display dimensions (only 128x64 supported)
  ## - `sclPin` - I2C clock pin (default: PB8)
  ## - `sdaPin` - I2C data pin (default: PB9)
  ## - `address` - I2C address (default: 0x3C, alt: 0x3D)
  ## 
  ## **Returns:** Initialized display instance
  ## 
  ## **Example:**
  ## ```nim
  ## var oled = initSH1106I2c(128, 64)
  ## oled.fill(false)
  ## oled.drawPixel(64, 32, true)
  ## oled.update()
  ## ```
  when (width, height) == (128, 64):
    block:
      var result = newSH1106I2c()
      var config = newSH1106I2cConfig()
      config.transport_config.Defaults()
      config.transport_config.i2c_config.pin_config.scl = sclPin
      config.transport_config.i2c_config.pin_config.sda = sdaPin
      config.transport_config.i2c_address = address
      result.Init(config)
      result
  else:
    {.error: "SH1106 only supports 128x64 resolution".}

template initSH1106Spi*(width, height: static[int],
                        dcPin: Pin = newPin(PORTB, 4),
                        resetPin: Pin = newPin(PORTB, 15),
                        sclkPin: Pin = newPin(PORTG, 11),
                        mosiPin: Pin = newPin(PORTB, 5),
                        nssPin: Pin = newPin(PORTG, 10)): untyped =
  ## Initialize SH1106 OLED via SPI (faster than I2C)
  ## 
  ## **Parameters:**
  ## - `width`, `height` - Display dimensions (only 128x64 supported)
  ## - `dcPin` - Data/Command pin (default: PB4)
  ## - `resetPin` - Reset pin (default: PB15)
  ## - `sclkPin` - SPI clock pin (default: PG11)
  ## - `mosiPin` - SPI MOSI pin (default: PB5)
  ## - `nssPin` - SPI chip select pin (default: PG10)
  ## 
  ## **Returns:** Initialized display instance
  ## 
  ## **Example:**
  ## ```nim
  ## var oled = initSH1106Spi(128, 64)
  ## while true:
  ##   oled.fill(false)
  ##   oled.drawCircle(64, 32, 20, true)
  ##   oled.update()
  ##   hw.delay(50)
  ## ```
  when (width, height) == (128, 64):
    block:
      var result = newSH1106Spi()
      var config = newSH1106SpiConfig()
      config.transport_config.Defaults()
      config.transport_config.pin_config.dc = dcPin
      config.transport_config.pin_config.reset = resetPin
      config.transport_config.spi_config.pin_config.sclk = sclkPin
      config.transport_config.spi_config.pin_config.mosi = mosiPin
      config.transport_config.spi_config.pin_config.nss = nssPin
      result.Init(config)
      result
  else:
    {.error: "SH1106 only supports 128x64 resolution".}

# Generic procs work on any SH1106 display
proc width*(display: OledSH1106): int {.inline.} = 
  ## Get display width in pixels
  display.Width().int

proc height*(display: OledSH1106): int {.inline.} = 
  ## Get display height in pixels
  display.Height().int

proc drawPixel*(display: var OledSH1106, x, y: int, on: bool = true) = 
  ## Draw a single pixel
  ## 
  ## **Parameters:**
  ## - `x`, `y` - Pixel coordinates (0-based)
  ## - `on` - true for white, false for black
  display.DrawPixel(x.uint8, y.uint8, on)

proc fill*(display: var OledSH1106, on: bool = true) = 
  ## Fill entire display with a color
  ## 
  ## **Parameters:**
  ## - `on` - true for white, false for black
  display.Fill(on)

proc update*(display: var OledSH1106) = 
  ## Send framebuffer to display hardware
  ## Call this after drawing to make changes visible
  display.Update()

# 2D drawing primitives are shared via hid/disp/draw2d (re-exported)
# 2D drawing primitives (shared Bresenham implementations from hid/disp/draw2d)
proc drawLine*(display: var OledSH1106, x0, y0, x1, y1: int, on: bool = true) =
  ## Draw a line using Bresenham's algorithm (see `hid/disp/draw2d`).
  draw2d.drawLine(display, x0, y0, x1, y1, on)

proc drawRect*(display: var OledSH1106, x, y, w, h: int, on: bool = true) =
  ## Draw a rectangle outline (see `hid/disp/draw2d`).
  draw2d.drawRect(display, x, y, w, h, on)

proc fillRect*(display: var OledSH1106, x, y, w, h: int, on: bool = true) =
  ## Draw a filled rectangle (see `hid/disp/draw2d`).
  draw2d.fillRect(display, x, y, w, h, on)

proc drawCircle*(display: var OledSH1106, x0, y0, radius: int, on: bool = true) =
  ## Draw a circle outline using the midpoint circle algorithm (see `hid/disp/draw2d`).
  draw2d.drawCircle(display, x0, y0, radius, on)

# I2C address constants
const
  SH1106_I2C_ADDRESS_DEFAULT* = 0x3C
    ## Default I2C address for SH1106 displays
  SH1106_I2C_ADDRESS_ALT* = 0x3D
    ## Alternate I2C address (set via jumper on some modules)
