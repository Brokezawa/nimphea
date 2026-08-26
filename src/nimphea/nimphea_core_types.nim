## Nimphea Core Types - single source of truth for C++-backed types
##
## Every C++ type that is shared by two or more modules lives here exactly once.
## Modules re-export these types instead of re-declaring them, so the same C++
## type always maps to the same Nim type regardless of which modules are imported.
##
## Enum ordinals in this module match libDaisy v8.1.0 exactly.
##
## This module is internal - import it indirectly through `nimphea`.


# =============================================================================
# Hardware core (daisy_core.h - via daisy_seed.h)
# =============================================================================
{.push header: "daisy_seed.h".}

type
  GPIOPort* {.importcpp: "daisy::GPIOPort", size: sizeof(cint).} = enum
    PORTA = 0, PORTB, PORTC, PORTD, PORTE, PORTF, PORTG, PORTH, PORTI, PORTJ,
    PORTK, PORTX = 11 ## PORTX marks an invalid/dummy port

  Pin* {.importcpp: "daisy::Pin", bycopy.} = object
    port* {.importc: "port".}: GPIOPort
    pin* {.importc: "pin".}: uint8

  GPIOMode* {.importcpp: "daisy::GPIO::Mode", size: sizeof(cint).} = enum
    INPUT = 0
    OUTPUT
    OPEN_DRAIN
    ANALOG

  GPIOSpeed* {.importcpp: "daisy::GPIO::Speed", size: sizeof(cint).} = enum
    LOW = 0
    MEDIUM
    HIGH
    VERY_HIGH

  GPIO* {.importcpp: "daisy::GPIO".} = object

  # Sample rate enum (shared by AudioHandle and SaiHandle configs)
  SampleRate* {.importcpp: "daisy::SaiHandle::Config::SampleRate", size: sizeof(cint).} = enum
    SAI_8KHZ = 0
    SAI_16KHZ
    SAI_32KHZ
    SAI_48KHZ
    SAI_96KHZ

  AudioHandle* {.importcpp: "daisy::AudioHandle".} = object

  AudioConfig* {.importcpp: "daisy::AudioHandle::Config", bycopy.} = object
    blocksize* {.importc: "blocksize".}: csize_t
    samplerate* {.importc: "samplerate".}: SampleRate
    postgain* {.importc: "postgain".}: cfloat
    output_compensation* {.importc: "output_compensation".}: cfloat

  AudioResult* {.importcpp: "daisy::AudioHandle::Result", size: sizeof(cint).} = enum
    AUDIO_OK = 0
    AUDIO_ERR

  BoardVersion* {.importcpp: "daisy::DaisySeed::BoardVersion", size: sizeof(cint).} = enum
    BOARD_DAISY_SEED = 0
    BOARD_DAISY_SEED_1_1
    BOARD_DAISY_SEED_2_DFM

{.pop.} # header

# Pin constructor
proc newPin*(port: GPIOPort, pin: uint8): Pin
  {.importcpp: "daisy::Pin(@)", constructor, header: "daisy_seed.h".}

# =============================================================================
# Audio callback types (shared by nimphea, nimphea_audio, and all boards)
# =============================================================================
# Low-level C++ types matching libDaisy callback signatures
type
  ConstFloatPtrPtr* = ptr ptr cfloat   ## const float* const* (multi-channel input)
  FloatPtrPtr* = ptr ptr cfloat        ## float** (multi-channel output)
  AudioCallbackC* = proc(input: ConstFloatPtrPtr, output: FloatPtrPtr, size: csize_t) {.cdecl.}

  ConstFloatPtr* = ptr cfloat          ## const float* (interleaved input)
  FloatPtr* = ptr cfloat               ## float* (interleaved output)
  InterleavingAudioCallbackC* = proc(input: ConstFloatPtr, output: FloatPtr, size: csize_t) {.cdecl.}

  # Nim-friendly audio buffers and callbacks
  AudioBuffer* = ptr UncheckedArray[ptr UncheckedArray[cfloat]]
    ## Multi-channel audio buffer (non-interleaved)
  InterleavedAudioBuffer* = ptr UncheckedArray[cfloat]
    ## Interleaved audio buffer

  AudioCallback* = proc(input, output: AudioBuffer, size: int) {.cdecl, raises: [].}
    ## Nim-friendly multi-channel audio callback
  InterleavingAudioCallback* = proc(input, output: InterleavedAudioBuffer, size: int) {.cdecl, raises: [].}
    ## Nim-friendly interleaved audio callback

# =============================================================================
# Switch / Encoder / AnalogControl (hid/switch.h, hid/encoder.h, hid/ctrl.h)
# =============================================================================
{.push header: "hid/switch.h".}

type
  Switch* {.importcpp: "daisy::Switch".} = object

  SwitchType* {.importcpp: "daisy::Switch::Type", size: sizeof(cint).} = enum
    TYPE_TOGGLE = 0     ## Toggle/latching switch
    TYPE_MOMENTARY      ## Momentary pushbutton (default)

  SwitchPolarity* {.importcpp: "daisy::Switch::Polarity", size: sizeof(cint).} = enum
    POLARITY_NORMAL = 0   ## HIGH = pressed
    POLARITY_INVERTED     ## LOW = pressed

{.pop.} # header

# GPIO pull shared by Switch init and GPIO users (per/gpio.h)
type
  GpioPull* {.importcpp: "daisy::GPIO::Pull", size: sizeof(cint).} = enum
    PULL_NOPULL = 0
    PULL_UP
    PULL_DOWN

{.push header: "hid/encoder.h".}
type
  Encoder* {.importcpp: "daisy::Encoder".} = object
{.pop.} # header

{.push header: "hid/ctrl.h".}
type
  AnalogControl* {.importcpp: "daisy::AnalogControl".} = object
{.pop.} # header

# =============================================================================
# ADC (per/adc.h)
# =============================================================================
{.push header: "per/adc.h".}

type
  MuxPin* {.importcpp: "daisy::AdcChannelConfig::MuxPin", size: sizeof(cint).} = enum
    MUX_SEL_0 = 0
    MUX_SEL_1
    MUX_SEL_2

  ConversionSpeed* {.importcpp: "daisy::AdcChannelConfig::ConversionSpeed", size: sizeof(cint).} = enum
    SPEED_1CYCLES_5 = 0
    SPEED_2CYCLES_5
    SPEED_8CYCLES_5
    SPEED_16CYCLES_5
    SPEED_32CYCLES_5
    SPEED_64CYCLES_5
    SPEED_387CYCLES_5
    SPEED_810CYCLES_5

  OverSampling* {.importcpp: "daisy::AdcHandle::OverSampling", size: sizeof(cint).} = enum
    OVS_NONE = 0
    OVS_4
    OVS_8
    OVS_16
    OVS_32
    OVS_64
    OVS_128
    OVS_256
    OVS_512
    OVS_1024

  AdcChannelConfig* {.importcpp: "daisy::AdcChannelConfig", bycopy.} = object

  AdcHandle* {.importcpp: "daisy::AdcHandle".} = object

{.pop.} # header

# =============================================================================
# DAC (per/dac.h)
# =============================================================================
{.push header: "per/dac.h".}
type
  DacHandle* {.importcpp: "daisy::DacHandle".} = object
{.pop.} # header

# =============================================================================
# System (sys/system.h)
# =============================================================================
{.push header: "sys/system.h".}
type
  System* {.importcpp: "daisy::System".} = object
{.pop.} # header

# =============================================================================
# QSPI (per/qspi.h)
# =============================================================================
{.push header: "per/qspi.h".}

type
  QSPIDevice* {.importcpp: "daisy::QSPIHandle::Config::Device", size: sizeof(cint).} = enum
    IS25LP080D = 0
    IS25LP064A = 1

  QSPIMode* {.importcpp: "daisy::QSPIHandle::Config::Mode", size: sizeof(cint).} = enum
    MEMORY_MAPPED = 0
    INDIRECT_POLLING = 1

  QSPIConfig* {.importcpp: "daisy::QSPIHandle::Config", bycopy.} = object
    device* {.importc: "device".}: QSPIDevice
    mode* {.importc: "mode".}: QSPIMode

  QSPIHandle* {.importcpp: "daisy::QSPIHandle", byref.} = object

{.pop.} # header

# =============================================================================
# SDRAM (dev/sdram.h)
# =============================================================================
{.push header: "dev/sdram.h".}
type
  SdramHandle* {.importcpp: "daisy::SdramHandle".} = object
{.pop.} # header

# =============================================================================
# SAI (per/sai.h)
# =============================================================================
{.push header: "per/sai.h".}
type
  SaiHandle* {.importcpp: "daisy::SaiHandle".} = object
{.pop.} # header

# =============================================================================
# I2C (per/i2c.h)
# =============================================================================
{.push header: "per/i2c.h".}

type
  I2CHandleImpl* {.importcpp: "daisy::I2CHandle::Impl".} = object

  I2CPeripheral* {.importcpp: "daisy::I2CHandle::Config::Peripheral", size: sizeof(cint).} = enum
    I2C_1 = 0
    I2C_2
    I2C_3
    I2C_4

  I2CMode* {.importcpp: "daisy::I2CHandle::Config::Mode", size: sizeof(cint).} = enum
    I2C_MASTER = 0
    I2C_SLAVE

  I2CSpeed* {.importcpp: "daisy::I2CHandle::Config::Speed", size: sizeof(cint).} = enum
    I2C_100KHZ = 0
    I2C_400KHZ
    I2C_1MHZ

  I2CResult* {.importcpp: "daisy::I2CHandle::Result", size: sizeof(cint).} = enum
    I2C_OK = 0
    I2C_ERR

  I2CDirection* {.importcpp: "daisy::I2CHandle::Direction", size: sizeof(cint).} = enum
    I2C_TRANSMIT = 0
    I2C_RECEIVE

  I2CPinConfig* {.importcpp: "decltype(daisy::I2CHandle::Config{}.pin_config)", bycopy.} = object
    scl* {.importc: "scl".}: Pin
    sda* {.importc: "sda".}: Pin

  # Raw FFI types (D2-layout truth; the public static-peripheral wrappers
  # I2cHandle[P]/I2cConfig[P] live in per/i2c and own these)
  I2CConfigRaw* {.importcpp: "daisy::I2CHandle::Config", bycopy.} = object
    periph* {.importc: "periph".}: I2CPeripheral
    pin_config* {.importc: "pin_config".}: I2CPinConfig
    speed* {.importc: "speed".}: I2CSpeed
    mode* {.importc: "mode".}: I2CMode
    address* {.importc: "address".}: uint8

  I2CHandleRaw* {.importcpp: "daisy::I2CHandle".} = object
    pimpl* {.importc: "pimpl_".}: ptr I2CHandleImpl

{.pop.} # header

# =============================================================================
# SPI (per/spi.h)
# =============================================================================
{.push header: "per/spi.h".}

type
  SpiHandleImpl* {.importcpp: "daisy::SpiHandle::Impl".} = object

  SpiPeripheral* {.importcpp: "daisy::SpiHandle::Config::Peripheral", size: sizeof(cint).} = enum
    SPI_1 = 0
    SPI_2
    SPI_3
    SPI_4
    SPI_5
    SPI_6

  SpiMode* {.importcpp: "daisy::SpiHandle::Config::Mode", size: sizeof(cint).} = enum
    SPI_MASTER = 0
    SPI_SLAVE

  SpiDirection* {.importcpp: "daisy::SpiHandle::Config::Direction", size: sizeof(cint).} = enum
    SPI_TWO_LINES = 0
    SPI_TWO_LINES_TX_ONLY
    SPI_TWO_LINES_RX_ONLY
    SPI_ONE_LINE

  SpiClockPolarity* {.importcpp: "daisy::SpiHandle::Config::ClockPolarity", size: sizeof(cint).} = enum
    SPI_CLOCK_POL_LOW = 0
    SPI_CLOCK_POL_HIGH

  SpiClockPhase* {.importcpp: "daisy::SpiHandle::Config::ClockPhase", size: sizeof(cint).} = enum
    SPI_CLOCK_PHASE_1 = 0
    SPI_CLOCK_PHASE_2

  SpiNSS* {.importcpp: "daisy::SpiHandle::Config::NSS", size: sizeof(cint).} = enum
    SPI_NSS_SOFT = 0
    SPI_NSS_HARD_INPUT
    SPI_NSS_HARD_OUTPUT

  SpiBaudPrescaler* {.importcpp: "daisy::SpiHandle::Config::BaudPrescaler", size: sizeof(cint).} = enum
    SPI_PS_2 = 0
    SPI_PS_4
    SPI_PS_8
    SPI_PS_16
    SPI_PS_32
    SPI_PS_64
    SPI_PS_128
    SPI_PS_256

  SpiResult* {.importcpp: "daisy::SpiHandle::Result", size: sizeof(cint).} = enum
    SPI_OK = 0
    SPI_ERR

  SpiDmaDirection* {.importcpp: "daisy::SpiHandle::DmaDirection", size: sizeof(cint).} = enum
    SPI_DMA_RX = 0
    SPI_DMA_TX
    SPI_DMA_RX_TX

  SpiPinConfig* {.importcpp: "daisy::SpiHandle::Config::pin_config", bycopy.} = object
    sclk* {.importc: "sclk".}: Pin
    miso* {.importc: "miso".}: Pin
    mosi* {.importc: "mosi".}: Pin
    nss* {.importc: "nss".}: Pin

  SpiConfig* {.importcpp: "daisy::SpiHandle::Config", bycopy.} = object
    periph* {.importc: "periph".}: SpiPeripheral
    mode* {.importc: "mode".}: SpiMode
    direction* {.importc: "direction".}: SpiDirection
    datasize* {.importc: "datasize".}: culong
    clock_polarity* {.importc: "clock_polarity".}: SpiClockPolarity
    clock_phase* {.importc: "clock_phase".}: SpiClockPhase
    nss* {.importc: "nss".}: SpiNSS
    baud_prescaler* {.importc: "baud_prescaler".}: SpiBaudPrescaler
    pin_config* {.importc: "pin_config".}: SpiPinConfig

  SpiHandle* {.importcpp: "daisy::SpiHandle".} = object
    pimpl {.importc: "pimpl_".}: ptr SpiHandleImpl

{.pop.} # header

# =============================================================================
# UART (per/uart.h)
# =============================================================================
{.push header: "per/uart.h".}

type
  UartPeripheral* {.importcpp: "daisy::UartHandler::Config::Peripheral", size: sizeof(cint).} = enum
    USART_1 = 0
    USART_2
    USART_3
    UART_4
    UART_5
    USART_6
    UART_7
    UART_8
    LPUART_1

  UartStopBits* {.importcpp: "daisy::UartHandler::Config::StopBits", size: sizeof(cint).} = enum
    STOP_BITS_0_5 = 0
    STOP_BITS_1
    STOP_BITS_1_5
    STOP_BITS_2

  UartParity* {.importcpp: "daisy::UartHandler::Config::Parity", size: sizeof(cint).} = enum
    PARITY_NONE = 0
    PARITY_EVEN
    PARITY_ODD

  UartMode* {.importcpp: "daisy::UartHandler::Config::Mode", size: sizeof(cint).} = enum
    MODE_RX = 0
    MODE_TX
    MODE_TX_RX

  UartWordLength* {.importcpp: "daisy::UartHandler::Config::WordLength", size: sizeof(cint).} = enum
    WORD_BITS_7 = 0
    WORD_BITS_8
    WORD_BITS_9

  UartResult* {.importcpp: "daisy::UartHandler::Result", size: sizeof(cint).} = enum
    UART_OK = 0
    UART_ERR

  UartDmaDirection* {.importcpp: "daisy::UartHandler::DmaDirection", size: sizeof(cint).} = enum
    DMA_RX = 0
    DMA_TX

  UartPinConfig* {.importcpp: "daisy::UartHandler::Config::pin_config", bycopy.} = object
    tx* {.importcpp: "tx".}: Pin
    rx* {.importcpp: "rx".}: Pin

  UartConfig* {.importcpp: "daisy::UartHandler::Config", bycopy.} = object
    pin_config* {.importcpp: "pin_config".}: UartPinConfig
    periph* {.importcpp: "periph".}: UartPeripheral
    stopbits* {.importcpp: "stopbits".}: UartStopBits
    parity* {.importcpp: "parity".}: UartParity
    mode* {.importcpp: "mode".}: UartMode
    wordlength* {.importcpp: "wordlength".}: UartWordLength
    baudrate* {.importcpp: "baudrate".}: uint32

  UartHandler* {.importcpp: "daisy::UartHandler".} = object

{.pop.} # header

# =============================================================================
# SDMMC (per/sdmmc.h via daisy_seed.h)
# =============================================================================
{.push header: "daisy_seed.h".}
type
  SdmmcHandler* {.importcpp: "daisy::SdmmcHandler".} = object
{.pop.} # header

# =============================================================================
# USB + MIDI (hid/usb.h, hid/usb_midi.h, hid/midi.h)
# =============================================================================
{.push header: "hid/usb.h".}

type
  UsbPeriph* {.importcpp: "daisy::UsbHandle::UsbPeriph", size: sizeof(cint).} = enum
    FS_INTERNAL = 0
    FS_EXTERNAL
    FS_BOTH

  UsbHandle* {.importcpp: "daisy::UsbHandle".} = object

{.pop.} # header

{.push header: "hid/usb_midi.h".}

type
  MidiUsbPeriph* {.importcpp: "daisy::MidiUsbTransport::Config::Periph", size: sizeof(cint).} = enum
    MIDI_USB_INTERNAL = 0
    MIDI_USB_EXTERNAL
    MIDI_USB_HOST

  MidiUsbTransportConfig* {.importcpp: "daisy::MidiUsbTransport::Config", bycopy.} = object
    periph* {.importc: "periph".}: MidiUsbPeriph
    txRetryCount* {.importc: "tx_retry_count".}: uint8

  MidiUsbTransport* {.importcpp: "daisy::MidiUsbTransport".} = object

{.pop.} # header

{.push header: "hid/midi.h".}

type
  MidiMessageType* {.importcpp: "daisy::MidiMessageType", size: sizeof(cint).} = enum
    NoteOff
    NoteOn
    PolyphonicKeyPressure
    ControlChange
    ProgramChange
    ChannelPressure
    PitchBend
    SystemCommon
    SystemRealTime

  MidiEvent* {.importcpp: "daisy::MidiEvent", bycopy.} = object
    mType* {.importcpp: "type".}: MidiMessageType
    channel* {.importcpp: "channel".}: cint
    data* {.importcpp: "data".}: array[2, uint8]

  MidiUsbHandler* {.importcpp: "daisy::MidiHandler<daisy::MidiUsbTransport>".} = object
  MidiUsbHandlerConfig* {.importcpp: "daisy::MidiHandler<daisy::MidiUsbTransport>::Config", bycopy.} = object

  MidiUartTransport* {.importcpp: "daisy::MidiUartTransport".} = object

  MidiUartTransportConfig* {.importcpp: "daisy::MidiUartTransport::Config", bycopy.} = object
    periph* {.importcpp: "periph".}: UartPeripheral
    rx* {.importcpp: "rx".}: Pin
    tx* {.importcpp: "tx".}: Pin
    rx_buffer* {.importcpp: "rx_buffer".}: ptr uint8
    rx_buffer_size* {.importcpp: "rx_buffer_size".}: csize_t

  MidiUartHandler* {.importcpp: "daisy::MidiUartHandler".} = object
  MidiUartHandlerConfig* {.importcpp: "daisy::MidiUartHandler::Config", bycopy.} = object
    transport_config* {.importcpp: "transport_config".}: MidiUartTransportConfig

{.pop.} # header

# =============================================================================
# OLED transport configs (dev/oled_ssd130x.h) - shared by SSD130x and SH1106
# =============================================================================
{.push header: "dev/oled_ssd130x.h".}

type
  SSD130xI2CTransportConfig* {.importcpp: "daisy::SSD130xI2CTransport::Config", bycopy.} = object
    i2c_config* {.importc: "i2c_config".}: I2CConfigRaw
    i2c_address* {.importc: "i2c_address".}: uint8

  SSD130xSpiPinConfig* {.importcpp: "daisy::SSD130x4WireSpiTransport::Config::pin_config", bycopy.} = object
    dc* {.importc: "dc".}: Pin
    reset* {.importc: "reset".}: Pin

  SSD130x4WireSpiTransportConfig* {.importcpp: "daisy::SSD130x4WireSpiTransport::Config", bycopy.} = object
    spi_config* {.importc: "spi_config".}: SpiConfig
    pin_config* {.importc: "pin_config".}: SSD130xSpiPinConfig
    useDma* {.importc: "useDma".}: bool

  OledDisplay128x64I2c* {.importcpp: "daisy::SSD130xI2c128x64Driver".} = object
  OledDisplay128x32I2c* {.importcpp: "daisy::SSD130xI2c128x32Driver".} = object
  OledDisplay64x48I2c* {.importcpp: "daisy::SSD130xI2c64x48Driver".} = object
  OledDisplay64x32I2c* {.importcpp: "daisy::SSD130xI2c64x32Driver".} = object
  OledDisplay128x64Spi* {.importcpp: "daisy::SSD130x4WireSpi128x64Driver".} = object
  OledDisplay128x32Spi* {.importcpp: "daisy::SSD130x4WireSpi128x32Driver".} = object
  OledDisplay64x48Spi* {.importcpp: "daisy::SSD130x4WireSpi64x48Driver".} = object
  OledDisplay64x32Spi* {.importcpp: "daisy::SSD130x4WireSpi64x32Driver".} = object

  OledDisplayI2cConfig* {.importcpp: "daisy::SSD130xI2c128x64Driver::Config", bycopy.} = object
    transport_config* {.importc: "transport_config".}: SSD130xI2CTransportConfig

  OledDisplaySpiConfig* {.importcpp: "daisy::SSD130x4WireSpi128x64Driver::Config", bycopy.} = object
    transport_config* {.importc: "transport_config".}: SSD130x4WireSpiTransportConfig

  OledDisplay* = OledDisplay128x64I2c | OledDisplay128x32I2c | OledDisplay64x48I2c | OledDisplay64x32I2c |
                 OledDisplay128x64Spi | OledDisplay128x32Spi | OledDisplay64x48Spi | OledDisplay64x32Spi

{.pop.} # header

# =============================================================================
# NeoPixel (dev/neopixel.h)
# =============================================================================
{.push header: "dev/neopixel.h".}

type
  NeoPixelResult* {.importcpp: "daisy::NeoPixel<daisy::NeoPixelI2CTransport>::Result", size: sizeof(cint).} = enum
    NEO_OK = 0
    NEO_ERR = 1

  NeoPixelI2CTransportConfig* {.importcpp: "daisy::NeoPixelI2CTransport::Config", bycopy.} = object
    periph* {.importcpp: "periph".}: I2CPeripheral
    speed* {.importcpp: "speed".}: I2CSpeed
    scl* {.importcpp: "scl".}: Pin
    sda* {.importcpp: "sda".}: Pin
    address* {.importcpp: "address".}: uint8

  NeoPixelI2CConfig* {.importcpp: "daisy::NeoPixel<daisy::NeoPixelI2CTransport>::Config", bycopy.} = object
    transport_config* {.importcpp: "transport_config".}: NeoPixelI2CTransportConfig
    type_flags* {.importcpp: "type".}: uint16
    numLEDs* {.importcpp: "numLEDs".}: uint16
    output_pin* {.importcpp: "output_pin".}: int8

  NeoPixelI2C* {.importcpp: "daisy::NeoPixelI2C", byref.} = object

{.pop.} # header

# =============================================================================
# AK4556 codec (dev/codec_ak4556.h) - referenced by DaisySeed.codec
# =============================================================================
{.push header: "dev/codec_ak4556.h".}
type
  Ak4556* {.importcpp: "daisy::Ak4556".} = object
{.pop.} # header

# =============================================================================
# Unit types (distinct wrappers for cross-module numeric quantities)
# =============================================================================
## Unit types prevent silent mixing of semantically different quantities:
## `hz(48000)` cannot be passed where `ms(...)` is expected (type mismatch at
## compile time). Each unit has an explicit constructor and a conversion back
## to its base numeric type; the underlying representation is unchanged, so
## the values pass through `importcpp`/`importc` bindings transparently.

type
  Hz* = distinct cfloat            ## frequency (hertz)
  Milliseconds* = distinct uint32  ## time span (milliseconds)
  Seconds* = distinct float        ## time span (seconds)
  Baud* = distinct uint32          ## UART baud rate
  DutyCycle* = distinct cfloat     ## PWM duty cycle [0..1]
  Db* = distinct cfloat            ## gain (decibels)

template hz*(v: cfloat): Hz = Hz(v)
template ms*(v: uint32): Milliseconds = Milliseconds(v)
template seconds*(v: float): Seconds = Seconds(v)
template baud*(v: uint32): Baud = Baud(v)
template duty*(v: cfloat): DutyCycle = DutyCycle(v)
template db*(v: cfloat): Db = Db(v)
