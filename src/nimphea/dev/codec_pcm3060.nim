## PCM3060 Codec
## ==============
##
## Nim wrapper for the Texas Instruments PCM3060 audio codec.
##
## The PCM3060 is a high-performance codec used on Daisy Seed 2 and other
## advanced audio platforms.
##
## **Features:**
## - 24-bit stereo ADC and DAC
## - I2C control interface (SPI not yet supported)
## - High-quality audio processing
## - 24-bit MSB-aligned I2S mode
## - Power save control
## - 48kHz sample rate
##
## **Example:**
## ```nim
## import nimphea
## import nimphea/dev/codec_pcm3060
## import nimphea/per/i2c
##
## var i2c = initI2C[I2C_1](D16(), D17(), I2C_400KHZ)
## var codec: Pcm3060
##
## # Initialize I2C at 400kHz or less
## # ... i2c setup ...
##
## let result = codec.init(i2c)
## if result == Pcm3060Result.OK:
##   echo "Codec initialized successfully"
## ```

import nimphea
import nimphea/per/i2c


{.push header: "dev/codec_pcm3060.h".}

type
  Pcm3060Result* {.importcpp: "daisy::Pcm3060::Result", size: sizeof(cint).} = enum
    ## Return values for PCM3060 functions
    OK  ## Operation successful
    ERR ## Operation failed

  Pcm3060* {.importcpp: "daisy::Pcm3060".} = object
    ## PCM3060 codec driver
    ## 
    ## High-performance I2C-controlled audio codec with automatic configuration.
    ## Used on Daisy Seed 2 and platforms requiring premium audio quality.
    ## 
    ## Initialization performs MRST and SRST, sets format to 24-bit LJ,
    ## and disables power save for both ADC and DAC.

{.pop.}

proc init*[P: static I2CPeripheral](this: var Pcm3060, i2c: I2cHandle[P]): Pcm3060Result 
  {.importcpp: "#.Init(#)".}
  ## Initialize the PCM3060 codec
  ## 
  ## Performs the following:
  ## - Master reset (MRST) and system reset (SRST)
  ## - Sets format to 24-bit MSB-aligned I2S mode
  ## - Disables power save for ADC and DAC
  ## - Configures all registers to defaults
  ## 
  ## **Parameters:**
  ## - `i2c` - Initialized I2C handle configured at 400kHz or less
  ## 
  ## **Returns:** `Pcm3060Result.OK` on success, `Pcm3060Result.ERR` on failure
  ## 
  ## **Example:**
  ## ```nim
  ## var i2c = initI2C[I2C_1](D16(), D17(), I2C_400KHZ)
  ## var i2cCfg: I2cConfig[I2C_1]
  ## var codec: Pcm3060
  ## 
  ## # Initialize I2C at 400kHz
  ## i2cCfg.periph = I2CPeripheral.I2C_1
  ## i2cCfg.speed = I2CSpeed.I2C_400KHZ
  ## i2cCfg.pin_config.scl = newPin(PORTB, 8)
  ## i2cCfg.pin_config.sda = newPin(PORTB, 9)
  ## i2c.init(i2cCfg)
  ## 
  ## let result = codec.init(i2c)
  ## if result != Pcm3060Result.OK:
  ##   echo "Codec init failed"
  ## ```
