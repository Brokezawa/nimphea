## Audio callback bridge
## ======================
##
## Single shared audio-start mechanism for every board and the Daisy Seed.
##
## libDaisy's `StartAudio`/`ChangeAudioCallback` take a **C function pointer**,
## while Nim audio callbacks are closures-free `proc`s with a friendly signature.
## This module owns the two `exportc` C ABI shims, the two global callback slots,
## and the one documented `reinterpret_cast` emit (allowed special case, see
## AGENTS.md raw-emit policy). All boards and `nimphea` route audio through here,
## so no per-board callback machinery is needed.
##
## The bridge is type-generic: any board type (DaisySeed, DaisyPod, DaisyField,
## ...) can call `startAudio`/`changeAudioCallback`/`stopAudio` directly.
##
## Example:
## ```nim
## import nimphea
## import nimphea/nimphea_audio
##
## proc audioCallback(input, output: AudioBuffer, size: int) {.cdecl, raises: [].} =
##   for i in 0..<size:
##     output[0][i] = input[0][i]
##
## var daisy = initDaisy()
## daisy.startAudio(audioCallback)
## ```
##
## **Note:** `daisy::DaisyPatch` has no interleaving `StartAudio` overload in
## libDaisy, so `startAudio` with a `InterleavingAudioCallback` will not compile
## for that board (pre-existing limitation).

import nimphea/nimphea_core_types
import nimphea/nimphea_macros

# The bridge's generated C++ names the board parameter by its Nim type name
# (e.g. `DaisySeed&`), so its translation unit needs the daisy namespace.
useNimpheaModules(core)

var globalNimAudioCallback: AudioCallback = nil
var globalNimInterleavingCallback: InterleavingAudioCallback = nil

proc audioCallbackWrapper(input: ptr ptr cfloat, output: ptr ptr cfloat, size: csize_t)
  {.exportc: "audioCallbackWrapper", cdecl, raises: [].} =
  if not globalNimAudioCallback.isNil:
    globalNimAudioCallback(cast[AudioBuffer](input),
                           cast[AudioBuffer](output),
                           size.int)

proc interleavingCallbackWrapper(input: ptr cfloat, output: ptr cfloat, size: csize_t)
  {.exportc: "interleavingCallbackWrapper", cdecl, raises: [].} =
  if not globalNimInterleavingCallback.isNil:
    globalNimInterleavingCallback(cast[InterleavedAudioBuffer](input),
                                  cast[InterleavedAudioBuffer](output),
                                  size.int)

proc startAudio*[T](daisy: var T, callback: AudioCallback) =
  ## Start audio processing with a multi-channel (non-interleaved) callback.
  ## The C ABI shim forwards every audio callback into `callback`.
  globalNimAudioCallback = callback
  {.emit: "`daisy`.StartAudio(reinterpret_cast<daisy::AudioHandle::AudioCallback>(audioCallbackWrapper));".}

proc startAudio*[T](daisy: var T, callback: InterleavingAudioCallback) =
  ## Start audio processing with an interleaved callback.
  ##
  ## **Note:** Not available on the Daisy Patch (no libDaisy overload).
  globalNimInterleavingCallback = callback
  {.emit: "`daisy`.StartAudio(reinterpret_cast<daisy::AudioHandle::InterleavingAudioCallback>(interleavingCallbackWrapper));".}

proc changeAudioCallback*[T](daisy: var T, callback: AudioCallback) =
  ## Swap the active multi-channel callback while audio is running.
  globalNimAudioCallback = callback
  {.emit: "`daisy`.ChangeAudioCallback(reinterpret_cast<daisy::AudioHandle::AudioCallback>(audioCallbackWrapper));".}

proc changeAudioCallback*[T](daisy: var T, callback: InterleavingAudioCallback) =
  ## Swap the active interleaved callback while audio is running.
  ##
  ## **Note:** Not available on the Daisy Patch (no libDaisy overload).
  globalNimInterleavingCallback = callback
  {.emit: "`daisy`.ChangeAudioCallback(reinterpret_cast<daisy::AudioHandle::InterleavingAudioCallback>(interleavingCallbackWrapper));".}

proc stopAudio*[T](daisy: var T) =
  ## Stop audio processing and clear the stored callbacks.
  globalNimAudioCallback = nil
  globalNimInterleavingCallback = nil
  {.emit: "`daisy`.StopAudio();".}