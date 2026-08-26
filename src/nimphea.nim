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
proc audioSaiHandle*(this: DaisySeed): SaiHandleRaw {.importcpp: "#.AudioSaiHandle()", header: "daisy_seed.h".}
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
proc init*(this: var AudioHandle, config: AudioConfig, sai: SaiHandleRaw): AudioResult
  {.importcpp: "#.Init(@)", header: "hid/audio.h".}
  ## Initialize AudioHandle with a single SAI configured in stereo I2S mode.
proc init*(this: var AudioHandle, config: AudioConfig, sai1, sai2: SaiHandleRaw): AudioResult
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
# ============
## Static-pin constants for the Daisy Seed labelled pins (D0-D32 and the
## analog aliases A0-A13), matching libDaisy's constexpr table exactly.
## Each constant carries its port+pin in the type (`StaticPin[PORTB, 12]`),
## so mixing pins from different ports is a compile-time error. Use the
## runtime `newPin(port, pinNo)` constructor for pins chosen at runtime.
const D0* = staticPinConst[PORTB, 12]()
const D1* = staticPinConst[PORTC, 11]()
const D2* = staticPinConst[PORTC, 10]()
const D3* = staticPinConst[PORTC, 9]()
const D4* = staticPinConst[PORTC, 8]()
const D5* = staticPinConst[PORTD, 2]()
const D6* = staticPinConst[PORTC, 12]()
const D7* = staticPinConst[PORTG, 10]()
const D8* = staticPinConst[PORTG, 11]()
const D9* = staticPinConst[PORTB, 4]()
const D10* = staticPinConst[PORTB, 5]()
const D11* = staticPinConst[PORTB, 8]()
const D12* = staticPinConst[PORTB, 9]()
const D13* = staticPinConst[PORTB, 6]()
const D14* = staticPinConst[PORTB, 7]()
const D15* = staticPinConst[PORTC, 0]()
const D16* = staticPinConst[PORTA, 3]()
const D17* = staticPinConst[PORTB, 1]()
const D18* = staticPinConst[PORTA, 7]()
const D19* = staticPinConst[PORTA, 6]()
const D20* = staticPinConst[PORTC, 1]()
const D21* = staticPinConst[PORTC, 4]()
const D22* = staticPinConst[PORTA, 5]()
const D23* = staticPinConst[PORTA, 4]()
const D24* = staticPinConst[PORTA, 1]()
const D25* = staticPinConst[PORTA, 0]()
const D26* = staticPinConst[PORTD, 11]()
const D27* = staticPinConst[PORTG, 9]()
const D28* = staticPinConst[PORTA, 2]()
const D29* = staticPinConst[PORTB, 14]()
const D30* = staticPinConst[PORTB, 15]()
const D31* = staticPinConst[PORTC, 2]()
const D32* = staticPinConst[PORTC, 3]()
const A0* = D15
const A1* = D16
const A2* = D17
const A3* = D18
const A4* = D19
const A5* = D20
const A6* = D21
const A7* = D22
const A8* = D23
const A9* = D24
const A10* = D25
const A11* = D28
const A12* = D31
const A13* = D32
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
