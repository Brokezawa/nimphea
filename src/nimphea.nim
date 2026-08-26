## Nimphea - Nim wrapper for the Daisy Audio Platform Hardware Abstraction Library
## 
## This module provides Nim bindings to the Daisy Audio Platform (via libDaisy C++ library)
## by Electro-Smith. It enables easy access to audio, controls, GPIO, MIDI, USB, and more.
##
## Basic Example:
## ```nim
## import nimphea
## 
## proc main() =
##   var daisy = initDaisy()
##   daisy.setLed(true)
##   daisy.delay(500)
##   daisy.setLed(false)
## 
## when isMainModule:
##   main()
## ```
##
## Audio Example:
## ```nim
## import nimphea
## 
## proc audioCallback(input, output: AudioBuffer, size: int) {.cdecl.} =
##   for i in 0..<size:
##     output[0][i] = input[0][i]  # Left channel passthrough
##     output[1][i] = input[1][i]  # Right channel passthrough
## 
## proc main() =
##   var daisy = initDaisy()
##   daisy.startAudio(audioCallback)
##   while true:
##     discard
## 
## when isMainModule:
##   main()
## ```
##
## All bindings carry fully-qualified C++ names and `header:` pragmas, so no
## setup call is needed after importing.


# Compiler configuration: libDaisy include paths, defines, and link flags
# (passC/passL pragmas, paths resolved from this module's location)
import nimphea/build

# Single source of truth for C++-backed types
import nimphea/nimphea_core_types
export nimphea_core_types

# Shared audio callback bridge (startAudio/changeAudioCallback/stopAudio)
import nimphea/nimphea_audio
export nimphea_audio

# Vendored zero-heap stack string (nim-stack-strings) + numeric formatting utils
import nimphea/stack_strings
import nimphea/nimphea_stack_strings_utils
export stack_strings, nimphea_stack_strings_utils

{.push header: "daisy_seed.h".}

type
  # Main DaisySeed class
  DaisySeed* {.importcpp: "daisy::DaisySeed".} = object
    qspi* {.importc: "qspi".}: QSPIHandle
    qspi_config* {.importc: "qspi_config".}: QSPIConfig
    sdram_handle* {.importc: "sdram_handle".}: SdramHandle
    audio_handle* {.importc: "audio_handle".}: AudioHandle
    adc* {.importc: "adc".}: AdcHandle
    dac* {.importc: "dac".}: DacHandle
    usb_handle* {.importc: "usb_handle".}: UsbHandle
    led* {.importc: "led".}: GPIO
    testpoint* {.importc: "testpoint".}: GPIO
    system* {.importc: "system".}: System
    codec* {.importc: "codec".}: Ak4556

{.pop.} # header


# =============================================================================
# Constructors (single bindings)
# =============================================================================
proc newDaisySeed*(): DaisySeed {.importcpp: "daisy::DaisySeed()", constructor, header: "daisy_seed.h".}
proc newGPIO*(): GPIO {.importcpp: "daisy::GPIO()", constructor, header: "daisy_seed.h".}

# =============================================================================
# DaisySeed methods (bind-once)
# =============================================================================
proc init*(this: var DaisySeed, boost: bool = false) {.importcpp: "#.Init(@)", header: "daisy_seed.h".}
  ## Initialize the Daisy Seed hardware
proc deinit*(this: var DaisySeed) {.importcpp: "#.DeInit()", header: "daisy_seed.h".}
  ## Deinitialize the Daisy Seed hardware

proc initDaisy*(boost: bool = false): DaisySeed =
  ## Initialize a Daisy Seed board
  ## 
  ## Parameters:
  ##   boost: Enable clock boost mode for higher performance
  ## 
  ## Example:
  ## ```nim
  ## var daisy = initDaisy()
  ## ```
  result = newDaisySeed()
  result.init(boost)

proc delay*(this: var DaisySeed, milliseconds: Milliseconds) {.importcpp: "#.DelayMs(#)", header: "daisy_seed.h".}
  ## Blocking delay for the given time span
  ##
  ## **Example:**
  ## ```nim
  ## daisy.delay(ms(1000))
  ## ```

proc getPin*(pinIndex: uint8): Pin {.importcpp: "daisy::DaisySeed::GetPin(@)", header: "daisy_seed.h".}
  ## Get a Pin object by its index (0-32)
proc getPin*(pinIndex: int): Pin = ## retained: int -> uint8 ergonomics
  getPin(pinIndex.uint8)

proc setLed*(this: var DaisySeed, state: bool) {.importcpp: "#.SetLed(@)", header: "daisy_seed.h".}
  ## Set the built-in LED state (true = ON, false = OFF)
proc setTestPoint*(this: var DaisySeed, state: bool) {.importcpp: "#.SetTestPoint(@)", header: "daisy_seed.h".}
  ## Set the test point pin state (for oscilloscope debugging)

proc boardVersion*(this: var DaisySeed): BoardVersion {.importcpp: "#.CheckBoardVersion()", header: "daisy_seed.h".}
  ## Check which version of Daisy Seed board is connected
proc now*(this: var DaisySeed): cfloat {.importcpp: "#.system.GetNow()", header: "daisy_seed.h".}
  ## Get current system time in seconds since startup

# Audio configuration (through DaisySeed)
proc setSampleRate*(this: var DaisySeed, samplerate: SampleRate) {.importcpp: "#.SetAudioSampleRate(@)", header: "daisy_seed.h".}
  ## Set the audio sample rate (SAI_8KHZ, SAI_16KHZ, SAI_32KHZ, SAI_48KHZ, SAI_96KHZ)
proc sampleRate*(this: var DaisySeed): cfloat {.importcpp: "#.AudioSampleRate()", header: "daisy_seed.h".}
  ## Get the current audio sample rate in Hz
proc setBlockSize*(this: var DaisySeed, blocksize: csize_t) {.importcpp: "#.SetAudioBlockSize(@)", header: "daisy_seed.h".}
proc setBlockSize*(this: var DaisySeed, blocksize: int) = ## retained: int -> csize_t ergonomics
  this.setBlockSize(blocksize.csize_t)
proc blockSize*(this: var DaisySeed): csize_t {.importcpp: "#.AudioBlockSize()", header: "daisy_seed.h".}
  ## Get the current audio block size (samples per callback)
proc callbackRate*(this: DaisySeed): cfloat {.importcpp: "#.AudioCallbackRate()", header: "daisy_seed.h".}
  ## Get the audio callback rate in Hz
proc audioSaiHandle*(this: DaisySeed): SaiHandle {.importcpp: "#.AudioSaiHandle()", header: "daisy_seed.h".}
  ## Get the SAI handle for the Daisy Seed audio interface (useful for a secondary codec)

# =============================================================================
# GPIO (bind-once)
# =============================================================================
proc init*(this: var GPIO, pin: Pin, mode: GPIOMode,
           pull: GpioPull = PULL_NOPULL, speed: GPIOSpeed = LOW)
  {.importcpp: "#.Init(@)", header: "daisy_seed.h".}
proc deinit*(this: var GPIO) {.importcpp: "#.DeInit()", header: "daisy_seed.h".}
proc write*(this: var GPIO, state: bool) {.importcpp: "#.Write(@)", header: "daisy_seed.h".}
proc read*(this: var GPIO): bool {.importcpp: "#.Read()", header: "daisy_seed.h".}
proc toggle*(this: var GPIO) {.importcpp: "#.Toggle()", header: "daisy_seed.h".}

proc initGpio*(pin: Pin, mode: GPIOMode = OUTPUT,
               pull: GpioPull = PULL_NOPULL, speed: GPIOSpeed = LOW): GPIO =
  ## Initialize a GPIO pin (constructor + config assembly)
  ##
  ## Parameters:
  ##   pin: The pin to configure (use D0(), D1(), A0(), etc.)
  ##   mode: INPUT, OUTPUT, OPEN_DRAIN, or ANALOG
  ##   pull: PULL_NOPULL, PULL_UP, or PULL_DOWN
  ##   speed: LOW, MEDIUM, HIGH, or VERY_HIGH
  ##
  ## Example:
  ## ```nim
  ## var led = initGpio(D7(), OUTPUT)
  ## led.write(true)
  ## ```
  result = newGPIO()
  result.init(pin, mode, pull, speed)

# =============================================================================
# AudioHandle direct API (bind-once; advanced users)
# =============================================================================
proc init*(this: var AudioHandle, config: AudioConfig, sai: SaiHandle): AudioResult
  {.importcpp: "#.Init(@)", header: "hid/audio.h".}
  ## Initialize AudioHandle with a single SAI configured in stereo I2S mode.
proc init*(this: var AudioHandle, config: AudioConfig, sai1, sai2: SaiHandle): AudioResult
  {.importcpp: "#.Init(@)", header: "hid/audio.h".}
  ## Initialize AudioHandle with two SAI, each configured in stereo I2S mode.
proc deinit*(this: var AudioHandle): AudioResult {.importcpp: "#.DeInit()", header: "hid/audio.h".}
  ## Stop and deinitialize audio.
proc getConfig*(this: AudioHandle): AudioConfig {.importcpp: "#.GetConfig()", header: "hid/audio.h".}
  ## Get the current AudioHandle configuration.
proc getChannels*(this: AudioHandle): csize_t {.importcpp: "#.GetChannels()", header: "hid/audio.h".}
  ## Get the number of audio channels (2 single SAI, 4 dual SAI, 0 if uninitialized).
proc getSampleRate*(this: var AudioHandle): cfloat {.importcpp: "#.GetSampleRate()", header: "hid/audio.h".}
  ## Get the sample rate as a float.
proc setSampleRate*(this: var AudioHandle, samplerate: SampleRate): AudioResult {.importcpp: "#.SetSampleRate(@)", header: "hid/audio.h".}
  ## Set the sample rate and reinitialize the SAI as needed.
proc setBlockSize*(this: var AudioHandle, size: csize_t): AudioResult {.importcpp: "#.SetBlockSize(@)", header: "hid/audio.h".}
  ## Set the block size after initialization.
proc setPostGain*(this: var AudioHandle, val: cfloat): AudioResult {.importcpp: "#.SetPostGain(@)", header: "hid/audio.h".}
  ## Set the amount of gain adjustment to perform before and after callback.
proc setOutputCompensation*(this: var AudioHandle, val: cfloat): AudioResult {.importcpp: "#.SetOutputCompensation(@)", header: "hid/audio.h".}
  ## Set an additional amount of gain compensation at the end of the callback.
proc start*(this: var AudioHandle, callback: AudioCallbackC): AudioResult {.importcpp: "#.Start(@)", header: "hid/audio.h".}
proc start*(this: var AudioHandle, callback: InterleavingAudioCallbackC): AudioResult {.importcpp: "#.Start(@)", header: "hid/audio.h".}
proc stop*(this: var AudioHandle): AudioResult {.importcpp: "#.Stop()", header: "hid/audio.h".}
proc changeCallback*(this: var AudioHandle, callback: AudioCallbackC): AudioResult {.importcpp: "#.ChangeCallback(@)", header: "hid/audio.h".}
proc changeCallback*(this: var AudioHandle, callback: InterleavingAudioCallbackC): AudioResult {.importcpp: "#.ChangeCallback(@)", header: "hid/audio.h".}

# Convenience helpers routed through the DaisySeed's audio handle (retained value wrappers)
proc setPostGain*(daisy: var DaisySeed, gain: float): AudioResult =
  daisy.audio_handle.setPostGain(gain.cfloat)
proc setOutputCompensation*(daisy: var DaisySeed, compensation: float): AudioResult =
  daisy.audio_handle.setOutputCompensation(compensation.cfloat)
proc toggleLed*(daisy: var DaisySeed) =
  ## Toggle the built-in LED (uses GPIO toggle internally)
  daisy.led.toggle()

# =============================================================================
# Pin constants for Daisy Seed
# =============================================================================
template D0*(): Pin = newPin(PORTB, 12)
template D1*(): Pin = newPin(PORTC, 11)
template D2*(): Pin = newPin(PORTC, 10)
template D3*(): Pin = newPin(PORTC, 9)
template D4*(): Pin = newPin(PORTC, 8)
template D5*(): Pin = newPin(PORTD, 2)
template D6*(): Pin = newPin(PORTC, 12)
template D7*(): Pin = newPin(PORTG, 10)
template D8*(): Pin = newPin(PORTG, 11)
template D9*(): Pin = newPin(PORTB, 4)
template D10*(): Pin = newPin(PORTB, 5)
template D11*(): Pin = newPin(PORTB, 8)
template D12*(): Pin = newPin(PORTB, 9)
template D13*(): Pin = newPin(PORTB, 6)
template D14*(): Pin = newPin(PORTB, 7)
template D15*(): Pin = newPin(PORTC, 0)
template D16*(): Pin = newPin(PORTA, 3)
template D17*(): Pin = newPin(PORTB, 1)
template D18*(): Pin = newPin(PORTA, 7)
template D19*(): Pin = newPin(PORTA, 6)
template D20*(): Pin = newPin(PORTC, 1)
template D21*(): Pin = newPin(PORTC, 4)
template D22*(): Pin = newPin(PORTA, 5)
template D23*(): Pin = newPin(PORTA, 4)
template D24*(): Pin = newPin(PORTA, 1)
template D25*(): Pin = newPin(PORTA, 0)
template D26*(): Pin = newPin(PORTD, 11)
template D27*(): Pin = newPin(PORTG, 9)
template D28*(): Pin = newPin(PORTA, 2)
template D29*(): Pin = newPin(PORTB, 14)
template D30*(): Pin = newPin(PORTB, 15)
template D31*(): Pin = newPin(PORTC, 2)
template D32*(): Pin = newPin(PORTC, 3)

# Analog pin aliases
template A0*(): Pin = D15()
template A1*(): Pin = D16()
template A2*(): Pin = D17()
template A3*(): Pin = D18()
template A4*(): Pin = D19()
template A5*(): Pin = D20()
template A6*(): Pin = D21()
template A7*(): Pin = D22()
template A8*(): Pin = D23()
template A9*(): Pin = D24()
template A10*(): Pin = D25()
template A11*(): Pin = D28()
template A12*(): Pin = D31()
template A13*(): Pin = D32()

# =============================================================================
# Audio sample conversion helpers
# =============================================================================
proc s16ToFloat*(x: int16): float32 {.inline.} =
  result = float32(x) * 3.0517578125e-05'f32

proc floatToS16*(x: float32): int16 {.inline.} =
  var val = x
  val = if val <= -0.999985'f32: -0.999985'f32 else: val
  val = if val >= 0.999985'f32: 0.999985'f32 else: val
  result = int16(val * 32767.0'f32)

proc s24ToFloat*(x: int32): float32 {.inline.} =
  let extended = (x xor 0x800000) - 0x800000
  result = float32(extended) * 1.192092896e-07'f32

proc floatToS24*(x: float32): int32 {.inline.} =
  var val = x
  val = if val <= -0.999985'f32: -0.999985'f32 else: val
  val = if val >= 0.999985'f32: 0.999985'f32 else: val
  result = int32(val * 8388608.0'f32)

# =============================================================================
# Logging API (wraps Logger)
# =============================================================================
proc print*(text: cstring) {.importcpp: "daisy::DaisySeed::Print(@)", header: "daisy_seed.h", varargs.}
  ## Print a formatted debug log message (C-style printf formatting).
  ## Requires StartLog() to be called first.
proc printLine*(text: cstring) {.importcpp: "daisy::DaisySeed::PrintLine(@)", header: "daisy_seed.h", varargs.}
  ## Print a formatted debug log message with automatic line termination.
proc printLine*() {.inline.} =
  printLine("")
proc startLog*(waitForPC: bool = false) {.importcpp: "daisy::DaisySeed::StartLog(@)", header: "daisy_seed.h".}

# Nim-friendly logging overloads (retained value wrappers)
proc print*(i: int) {.inline.} =
  print("%d", i.cint)
proc print*(f: float) {.inline.} =
  print("%f", f.cfloat)
proc printLine*(i: int) {.inline.} =
  printLine("%d", i.cint)
proc printLine*(f: float) {.inline.} =
  printLine("%f", f.cfloat)

# =============================================================================
# Audio callback bridge (nimphea_audio)
# =============================================================================
#
# startAudio, changeAudioCallback, and stopAudio come from the shared
# nimphea_audio module (exported below), so daisy.startAudio(cb) works
# exactly as before.

when isMainModule:
  echo "Nimphea - Nim wrapper for libDaisy"
  echo "To use: import nimphea"
