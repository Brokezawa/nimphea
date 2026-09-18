## Audio callback bridge
## ======================
##
## Single shared audio-start mechanism for every board and the Daisy Seed.
##
## libDaisy's `StartAudio`/`ChangeAudioCallback` take a **C function pointer**,
## while Nim audio callbacks are closures-free `proc`s with a friendly,
## typed signature: real `openArray` parameters (compiler-checked indexing),
## backed by a small value-type view (`AudioBuffer`) for the multi-channel
## case. The C-ABI wrappers construct those openArray values from the raw C
## pointers via `toOpenArray` — zero allocation,
## RT-safe, `size` is absorbed into the container lengths.
##
## This module owns the two `exportc` C ABI shims, the two global callback
## slots, and the opaque `importcpp` bindings to libDaisy's audio callback
## types — no raw `.emit` is used anywhere in the bridge (AGENTS.md raw-emit
## policy). All boards and `nimphea` route audio through here, so no per-board
## callback machinery is needed.
##
## The bridge is type-generic: any board type (DaisySeed, DaisyPod, DaisyField,
## ...) can call `startAudio`/`changeAudioCallback`/`stopAudio` directly. The
## channel count is captured once at registration through a generic
## `audioChannels[T]` accessor (Seed: `audio_handle`, Seed-wrapping boards:
## `seed.audio_handle`, patch_sm: `audio`) and refreshed on `changeAudioCallback`.
##
## Example (multi-channel):
## ```nim
## import nimphea
## import nimphea/nimphea_audio
##
## proc audioCallback(input: openArray[AudioBuffer],
##                    output: var openArray[AudioBuffer]) {.cdecl, raises: [].} =
##   for c in 0..<output.len:
##     for i in 0..<output[c].len:
##       output[c][i] = input[c][i]
##
## var daisy = initDaisy()
## daisy.startAudio(audioCallback)
## ```
##
## Example (interleaved):
## ```nim
## proc interleavedCallback(input, output: var openArray[cfloat]) {.cdecl, raises: [].} =
##   for i in 0..<output.len:
##     output[i] = input[i]
##
## daisy.startAudio(interleavedCallback)
## ```
##
## **Note:** `daisy::DaisyPatch` has no interleaving `StartAudio` overload in
## libDaisy, so `startAudio` with an `InterleavingAudioCallback` will not compile
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

# Channel-count binding (bind-once; reachable from the generic accessor below).
proc getChannels*(this: AudioHandle): csize_t {.importcpp: "#.GetChannels()", header: "hid/audio.h".}
  ## Number of audio channels (2 single SAI, 4 dual SAI, 0 if uninitialized).

template audioChannels*(daisy: typed): int =
  ## Number of audio channels for any board: reaches the board's `AudioHandle`
  ## through each board shape (`audio_handle` / `seed.audio_handle` / `audio`)
  ## and reads `getChannels()`. 0 if the audio handle is uninitialized.
  when compiles(daisy.audio_handle.getChannels()):
    int(daisy.audio_handle.getChannels())
  elif compiles(daisy.seed.audio_handle.getChannels()):
    int(daisy.seed.audio_handle.getChannels())
  elif compiles(daisy.audio.getChannels()):
    int(daisy.audio.getChannels())

var globalNimAudioCallback: AudioCallback = nil
var globalNimInterleavingCallback: InterleavingAudioCallback = nil
var globalAudioChannels = 0

proc audioCallbackWrapper(input: ptr ptr cfloat, output: ptr ptr cfloat, size: csize_t)
  {.exportc: "audioCallbackWrapper", cdecl, raises: [].} =
  if not globalNimAudioCallback.isNil:
    # Build typed view values + real openArray params from the raw C pointers.
    var inViews, outViews: array[MAX_AUDIO_CHANNELS, AudioBuffer]
    let chns = min(globalAudioChannels, MAX_AUDIO_CHANNELS)
    let samples = size.int
    let inChans = cast[ptr UncheckedArray[ptr cfloat]](input)
    let outChans = cast[ptr UncheckedArray[ptr cfloat]](output)
    for c in 0..<chns:
      inViews[c] = newAudioBuffer(cast[ptr UncheckedArray[cfloat]](inChans[c]), samples)
      outViews[c] = newAudioBuffer(cast[ptr UncheckedArray[cfloat]](outChans[c]), samples)
    let inOA = cast[ptr UncheckedArray[AudioBuffer]](addr inViews[0])
    let outOA = cast[ptr UncheckedArray[AudioBuffer]](addr outViews[0])
    globalNimAudioCallback(toOpenArray(inOA, 0, chns - 1),
                           toOpenArray(outOA, 0, chns - 1))

proc interleavingCallbackWrapper(input: ptr cfloat, output: ptr cfloat, size: csize_t)
  {.exportc: "interleavingCallbackWrapper", cdecl, raises: [].} =
  if not globalNimInterleavingCallback.isNil:
    # Interleaved: libDaisy passes the full interleaved length (2 x block for
    # stereo) as `size`; expose exactly that as the openArray length.
    let samples = size.int
    globalNimInterleavingCallback(
      toOpenArray(cast[ptr UncheckedArray[cfloat]](input), 0, samples - 1),
      toOpenArray(cast[ptr UncheckedArray[cfloat]](output), 0, samples - 1))

proc startAudio*[T](daisy: var T, callback: AudioCallback) =
  ## Start audio processing with a multi-channel (non-interleaved) callback.
  ## The C ABI shim forwards every audio callback into `callback`.
  globalNimAudioCallback = callback
  globalAudioChannels = audioChannels(daisy)
  daisy.startAudioCpp(cast[AudioCallbackCpp](audioCallbackWrapper))

proc startAudio*[T](daisy: var T, callback: InterleavingAudioCallback) =
  ## Start audio processing with an interleaved callback.
  ##
  ## **Note:** Not available on the Daisy Patch (no libDaisy overload).
  globalNimInterleavingCallback = callback
  globalAudioChannels = audioChannels(daisy)
  daisy.startInterleavedCpp(cast[InterleavingAudioCallbackCpp](interleavingCallbackWrapper))

proc changeAudioCallback*[T](daisy: var T, callback: AudioCallback) =
  ## Swap the active multi-channel callback while audio is running.
  globalNimAudioCallback = callback
  globalAudioChannels = audioChannels(daisy)
  daisy.changeAudioCpp(cast[AudioCallbackCpp](audioCallbackWrapper))

proc changeAudioCallback*[T](daisy: var T, callback: InterleavingAudioCallback) =
  ## Swap the active interleaved callback while audio is running.
  ##
  ## **Note:** Not available on the Daisy Patch (no libDaisy overload).
  globalNimInterleavingCallback = callback
  globalAudioChannels = audioChannels(daisy)
  daisy.changeInterleavedCpp(cast[InterleavingAudioCallbackCpp](interleavingCallbackWrapper))

proc stopAudio*[T](daisy: var T) =
  ## Stop audio processing and clear the stored callbacks.
  globalNimAudioCallback = nil
  globalNimInterleavingCallback = nil
  globalAudioChannels = 0
  daisy.stopAudioCpp()
