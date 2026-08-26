## Audio callback bridge
## ======================
##
## Single shared audio-start mechanism for every board and the Daisy Seed.
##
## libDaisy's `StartAudio`/`ChangeAudioCallback` take a **C function pointer**,
## while Nim audio callbacks are closures-free `proc`s with a friendly signature.
## This module owns the two `exportc` C ABI shims, the two global callback slots,
## and the opaque `importcpp` bindings to libDaisy's audio callback types — no
## raw `.emit` is used anywhere in the bridge (AGENTS.md raw-emit policy).
## All boards and `nimphea` route audio through here, so no per-board callback
## machinery is needed.
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

# The bridge's generated C++ names the board parameter by its Nim type name
# (e.g. `DaisySeed&`), so its translation unit needs the daisy namespace.

# Opaque C++ callback types (daisy::AudioHandle::AudioCallback and its
# interleaving sibling) — a C function pointer with the same shape as the
# exportc wrappers below, so the cast between them is a plain C cast.
type
  AudioCallbackCpp {.importcpp: "daisy::AudioHandle::AudioCallback", bycopy.} = object
  InterleavingAudioCallbackCpp {.importcpp: "daisy::AudioHandle::InterleavingAudioCallback", bycopy.} = object

# Generic bindings: Nim resolves `#` against the call-site board type, so one
# binding covers every board; `daisy_seed.h` is a harmless include everywhere
# (the board's own header still arrives via the board module / macro lists).
proc startAudioCpp[T](daisy: var T, cb: AudioCallbackCpp) {.importcpp: "#.StartAudio(#)", header: "daisy_seed.h".}
proc startInterleavedCpp[T](daisy: var T, cb: InterleavingAudioCallbackCpp) {.importcpp: "#.StartAudio(#)", header: "daisy_seed.h".}
proc changeAudioCpp[T](daisy: var T, cb: AudioCallbackCpp) {.importcpp: "#.ChangeAudioCallback(#)", header: "daisy_seed.h".}
proc changeInterleavedCpp[T](daisy: var T, cb: InterleavingAudioCallbackCpp) {.importcpp: "#.ChangeAudioCallback(#)", header: "daisy_seed.h".}
proc stopAudioCpp[T](daisy: var T) {.importcpp: "#.StopAudio()", header: "daisy_seed.h".}

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
  daisy.startAudioCpp(cast[AudioCallbackCpp](audioCallbackWrapper))

proc startAudio*[T](daisy: var T, callback: InterleavingAudioCallback) =
  ## Start audio processing with an interleaved callback.
  ##
  ## **Note:** Not available on the Daisy Patch (no libDaisy overload).
  globalNimInterleavingCallback = callback
  daisy.startInterleavedCpp(cast[InterleavingAudioCallbackCpp](interleavingCallbackWrapper))

proc changeAudioCallback*[T](daisy: var T, callback: AudioCallback) =
  ## Swap the active multi-channel callback while audio is running.
  globalNimAudioCallback = callback
  daisy.changeAudioCpp(cast[AudioCallbackCpp](audioCallbackWrapper))

proc changeAudioCallback*[T](daisy: var T, callback: InterleavingAudioCallback) =
  ## Swap the active interleaved callback while audio is running.
  ##
  ## **Note:** Not available on the Daisy Patch (no libDaisy overload).
  globalNimInterleavingCallback = callback
  daisy.changeInterleavedCpp(cast[InterleavingAudioCallbackCpp](interleavingCallbackWrapper))

proc stopAudio*[T](daisy: var T) =
  ## Stop audio processing and clear the stored callbacks.
  globalNimAudioCallback = nil
  globalNimInterleavingCallback = nil
  daisy.stopAudioCpp()
