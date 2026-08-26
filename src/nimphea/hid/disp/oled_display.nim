## OLED Display (SSD130x) support for libDaisy Nim wrapper
##
## Wraps libDaisy's SSD130xDriver template by using its pre-instantiated typedefs.
## This matches libDaisy's own approach and works reliably with Nim's C++ interop.
##
## LibDaisy defines typedefs like: `using SSD130xI2c128x64Driver = SSD130xDriver<128, 64, SSD130xI2CTransport>`
## We wrap these typedefs and provide a clean Nim API that selects the right one at compile time.
##
## Example - I2C display:
## ```nim
## var display = initOledI2c(128, 64)
## display.fill(false)
## display.drawPixel(64, 32, true)
## display.update()
## ```
##
## Example - SPI display (faster):
## ```nim
## var display = initOledSpi(128, 64)
## while true:
##   display.fill(false)
##   display.drawCircle(64, 32, 10, true)
##   display.update()
##   hw.delay(50)
## ```

import nimphea
export nimphea_core_types
import nimphea/per/i2c
import nimphea/per/spi
# Shared 2D drawing primitives (drawLine/drawRect/fillRect/drawCircle)
import nimphea/hid/disp/draw2d


{.push header: "daisy_seed.h".}

# Generic C++ member functions
proc Init[T, C](display: var T, config: C) {.importcpp: "#.Init(@)", header: "daisy_seed.h".}
proc Width[T](display: T): csize_t {.importcpp: "#.Width()", header: "daisy_seed.h".}
proc Height[T](display: T): csize_t {.importcpp: "#.Height()", header: "daisy_seed.h".}
proc DrawPixel[T](display: var T, x: uint8, y: uint8, on: bool) {.importcpp: "#.DrawPixel(@)", header: "daisy_seed.h".}
proc Fill[T](display: var T, on: bool) {.importcpp: "#.Fill(@)", header: "daisy_seed.h".}
proc Update[T](display: var T) {.importcpp: "#.Update()", header: "daisy_seed.h".}

# Constructors
proc new128x64I2c(): OledDisplay128x64I2c {.importcpp: "daisy::SSD130xI2c128x64Driver()", constructor, header: "daisy_seed.h".}
proc new128x32I2c(): OledDisplay128x32I2c {.importcpp: "daisy::SSD130xI2c128x32Driver()", constructor, header: "daisy_seed.h".}
proc new64x48I2c(): OledDisplay64x48I2c {.importcpp: "daisy::SSD130xI2c64x48Driver()", constructor, header: "daisy_seed.h".}
proc new64x32I2c(): OledDisplay64x32I2c {.importcpp: "daisy::SSD130xI2c64x32Driver()", constructor, header: "daisy_seed.h".}

proc new128x64Spi(): OledDisplay128x64Spi {.importcpp: "daisy::SSD130x4WireSpi128x64Driver()", constructor, header: "daisy_seed.h".}
proc new128x32Spi(): OledDisplay128x32Spi {.importcpp: "daisy::SSD130x4WireSpi128x32Driver()", constructor, header: "daisy_seed.h".}
proc new64x48Spi(): OledDisplay64x48Spi {.importcpp: "daisy::SSD130x4WireSpi64x48Driver()", constructor, header: "daisy_seed.h".}
proc new64x32Spi(): OledDisplay64x32Spi {.importcpp: "daisy::SSD130x4WireSpi64x32Driver()", constructor, header: "daisy_seed.h".}

proc newI2cConfig(): OledDisplayI2cConfig {.importcpp: "daisy::SSD130xI2c128x64Driver::Config()", constructor, header: "daisy_seed.h".}
proc newSpiConfig(): OledDisplaySpiConfig {.importcpp: "daisy::SSD130x4WireSpi128x64Driver::Config()", constructor, header: "daisy_seed.h".}

# Transport defaults
proc Defaults*(config: var SSD130xI2CTransportConfig) {.importcpp: "#.Defaults()", header: "daisy_seed.h".}
proc Defaults*(config: var SSD130x4WireSpiTransportConfig) {.importcpp: "#.Defaults()", header: "daisy_seed.h".}

# =============================================================================
# High-Level Nim API - compile-time dispatch to correct template instantiation
# =============================================================================

template initOledI2c*(width, height: static[int], 
                      sclPin: Pin = newPin(PORTB, 8), 
                      sdaPin: Pin = newPin(PORTB, 9), 
                      address: uint8 = 0x3C): untyped =
  ## Initialize OLED via I2C - selects correct template instantiation at compile time
  when (width, height) == (128, 64):
    block:
      var result = new128x64I2c()
      var config = newI2cConfig()
      config.transport_config.Defaults()
      config.transport_config.i2c_config.pin_config.scl = sclPin
      config.transport_config.i2c_config.pin_config.sda = sdaPin
      config.transport_config.i2c_address = address
      result.Init(config)
      result
  elif (width, height) == (128, 32):
    block:
      var result = new128x32I2c()
      var config = newI2cConfig()
      config.transport_config.Defaults()
      config.transport_config.i2c_config.pin_config.scl = sclPin
      config.transport_config.i2c_config.pin_config.sda = sdaPin
      config.transport_config.i2c_address = address
      result.Init(config)
      result
  elif (width, height) == (64, 48):
    block:
      var result = new64x48I2c()
      var config = newI2cConfig()
      config.transport_config.Defaults()
      config.transport_config.i2c_config.pin_config.scl = sclPin
      config.transport_config.i2c_config.pin_config.sda = sdaPin
      config.transport_config.i2c_address = address
      result.Init(config)
      result
  elif (width, height) == (64, 32):
    block:
      var result = new64x32I2c()
      var config = newI2cConfig()
      config.transport_config.Defaults()
      config.transport_config.i2c_config.pin_config.scl = sclPin
      config.transport_config.i2c_config.pin_config.sda = sdaPin
      config.transport_config.i2c_address = address
      result.Init(config)
      result
  else:
    {.error: "Unsupported size. Use: 128x64, 128x32, 64x48, 64x32".}

template initOledSpi*(width, height: static[int],
                      dcPin: Pin = newPin(PORTB, 4),
                      resetPin: Pin = newPin(PORTB, 15),
                      sclkPin: Pin = newPin(PORTG, 11),
                      mosiPin: Pin = newPin(PORTB, 5),
                      nssPin: Pin = newPin(PORTG, 10)): untyped =
  ## Initialize OLED via SPI - selects correct template instantiation at compile time
  when (width, height) == (128, 64):
    block:
      var result = new128x64Spi()
      var config = newSpiConfig()
      config.transport_config.Defaults()
      config.transport_config.pin_config.dc = dcPin
      config.transport_config.pin_config.reset = resetPin
      config.transport_config.spi_config.pin_config.sclk = sclkPin
      config.transport_config.spi_config.pin_config.mosi = mosiPin
      config.transport_config.spi_config.pin_config.nss = nssPin
      result.Init(config)
      result
  elif (width, height) == (128, 32):
    block:
      var result = new128x32Spi()
      var config = newSpiConfig()
      config.transport_config.Defaults()
      config.transport_config.pin_config.dc = dcPin
      config.transport_config.pin_config.reset = resetPin
      config.transport_config.spi_config.pin_config.sclk = sclkPin
      config.transport_config.spi_config.pin_config.mosi = mosiPin
      config.transport_config.spi_config.pin_config.nss = nssPin
      result.Init(config)
      result
  elif (width, height) == (64, 48):
    block:
      var result = new64x48Spi()
      var config = newSpiConfig()
      config.transport_config.Defaults()
      config.transport_config.pin_config.dc = dcPin
      config.transport_config.pin_config.reset = resetPin
      config.transport_config.spi_config.pin_config.sclk = sclkPin
      config.transport_config.spi_config.pin_config.mosi = mosiPin
      config.transport_config.spi_config.pin_config.nss = nssPin
      result.Init(config)
      result
  elif (width, height) == (64, 32):
    block:
      var result = new64x32Spi()
      var config = newSpiConfig()
      config.transport_config.Defaults()
      config.transport_config.pin_config.dc = dcPin
      config.transport_config.pin_config.reset = resetPin
      config.transport_config.spi_config.pin_config.sclk = sclkPin
      config.transport_config.spi_config.pin_config.mosi = mosiPin
      config.transport_config.spi_config.pin_config.nss = nssPin
      result.Init(config)
      result
  else:
    {.error: "Unsupported size. Use: 128x64, 128x32, 64x48, 64x32".}

# Generic procs work on any OledDisplay (union type)
proc width*(display: OledDisplay): int {.inline.} = display.Width().int
proc height*(display: OledDisplay): int {.inline.} = display.Height().int
proc drawPixel*(display: var OledDisplay, x, y: int, on: bool = true) = display.DrawPixel(x.uint8, y.uint8, on)
proc fill*(display: var OledDisplay, on: bool = true) = display.Fill(on)
proc update*(display: var OledDisplay) = display.Update()

# 2D drawing primitives (shared Bresenham implementations from hid/disp/draw2d)
proc drawLine*(display: var OledDisplay, x0, y0, x1, y1: int, on: bool = true) =
  ## Draw a line using Bresenham's algorithm (see `hid/disp/draw2d`).
  draw2d.drawLine(display, x0, y0, x1, y1, on)

proc drawRect*(display: var OledDisplay, x, y, w, h: int, on: bool = true) =
  ## Draw a rectangle outline (see `hid/disp/draw2d`).
  draw2d.drawRect(display, x, y, w, h, on)

proc fillRect*(display: var OledDisplay, x, y, w, h: int, on: bool = true) =
  ## Draw a filled rectangle (see `hid/disp/draw2d`).
  draw2d.fillRect(display, x, y, w, h, on)

proc drawCircle*(display: var OledDisplay, x0, y0, radius: int, on: bool = true) =
  ## Draw a circle outline using the midpoint circle algorithm (see `hid/disp/draw2d`).
  draw2d.drawCircle(display, x0, y0, radius, on)

const
  OLED_I2C_ADDRESS_DEFAULT* = 0x3C
  OLED_I2C_ADDRESS_ALT* = 0x3D
