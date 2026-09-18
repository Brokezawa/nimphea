## WAV File Streaming Playback Module
## ====================================
##
## This module provides WAV file streaming playback functionality for the Daisy platform.
## It supports 16-bit WAV files with float output, variable playback speed, and looping.
##
## Features:
## - Streaming playback from SD card (no full file loading required)
## - Variable playback speed with linear interpolation
## - Looping support
## - Low-latency buffered streaming using FIFO
## - Pitch shifting via semitone offset
##
## Memory Usage:
## - Approximately 2 * workspace_bytes
## - Default 4KB workspace = ~8KB total memory
##
## Limitations:
## - 16-bit WAV files only at this time
## - No reverse playback support
## - Forward playback only
##
## Usage Example:
## ```nim
## import nimphea/nimphea_wavplayer
##
## var player: WavPlayer4K
##
## # Initialize with file
## if player.init("sample.wav") == WavPlayerResult.Ok:
##   player.setLooping(true)
##   player.play()
##
## # In audio callback
## proc audioCallback(input: openArray[AudioBuffer],
##                    output: var openArray[AudioBuffer]) {.cdecl, raises: [].} =
##   for i in 0..<output[0].len:
##     let res = player.stream(output[0][i].addr, 2)  # 2 channels
##
## # In main loop
## while true:
##   discard player.prepare()  # Refill buffer
##   delay(1)
## ```



# Forward declarations
type
  WavPlayerResult* {.size: sizeof(cint).} = enum
    Ok = 0
    FileNotFoundError = 1
    PlaybackUnderrun = 2
    PrepareOverrun = 3
    NewSamplesRequested = 4
    DiskError = 5

  WavPlayerFileInfo*[N: static int] {.importcpp: "daisy::WavPlayer<'0>::FileInfo", bycopy.} = object
    channels* {.importcpp: "channels".}: csize_t
    length* {.importcpp: "length".}: csize_t
    samplerate* {.importcpp: "samplerate".}: csize_t
    data_start* {.importcpp: "data_start".}: csize_t
    data_size_bytes* {.importcpp: "data_size_bytes".}: csize_t

  # Generic streaming player over the C++ WavPlayer<workspace_size> template.
  # Only instantiated sizes are linked.
  WavPlayer*[N: static int] {.importcpp: "daisy::WavPlayer<'0>", byref.} = object

# Convenience aliases for common workspace sizes
type
  WavPlayer4K* = WavPlayer[4096]   ## 4KB workspace (sufficient for most use cases)
  WavPlayer8K* = WavPlayer[8192]   ## 8KB workspace (higher performance)
  WavPlayer16K* = WavPlayer[16384] ## 16KB workspace (maximum performance)

# ============================================================================
# Core Methods
# ============================================================================

proc init*[N](player: var WavPlayer[N], name: cstring): WavPlayerResult {.
  importcpp: "static_cast<int>(#.Init(@))", cdecl.}
  ## Initialize and open a WAV file for playback.
  ## This will open the file, parse the header, and prepare audio for streaming.
  ##
  ## Returns:
  ## - WavPlayerResult.Ok on success
  ## - WavPlayerResult.FileNotFoundError if file doesn't exist
  ## - WavPlayerResult.DiskError on disk I/O errors

proc open*[N](player: var WavPlayer[N], name: cstring): WavPlayerResult {.
  importcpp: "static_cast<int>(#.Open(@))", cdecl.}
  ## Open a WAV file and prepare for streaming.
  ## Similar to `init` but doesn't reset playback state.

proc close*[N](player: var WavPlayer[N]): WavPlayerResult {.
  importcpp: "static_cast<int>(#.Close())", cdecl.}
  ## Close the currently open file and clear all data.

proc prepare*[N](player: var WavPlayer[N]): WavPlayerResult {.
  importcpp: "static_cast<int>(#.Prepare())", cdecl.}
  ## Refill the playback buffer with new samples from disk.
  ## **Must be called regularly in the main loop** (not in audio callback).
  ##
  ## Returns:
  ## - WavPlayerResult.Ok on success
  ## - WavPlayerResult.DiskError on disk I/O errors
  ## - WavPlayerResult.PrepareOverrun if buffer is already full

proc stream*[N](player: var WavPlayer[N], samples: ptr cfloat, numChannels: csize_t): WavPlayerResult {.
  importcpp: "static_cast<int>(#.Stream(@))", cdecl.}
  ## Stream audio samples from the file.
  ## **Call this from your audio callback.**
  ##
  ## The function fills the samples buffer with audio data, handling:
  ## - Variable playback speed with linear interpolation
  ## - Looping behavior
  ## - Automatic buffer refill requests
  ##
  ## Parameters:
  ## - samples: Buffer to fill with audio samples
  ## - numChannels: Number of channels to fill (can differ from file channels)
  ##
  ## Returns:
  ## - WavPlayerResult.Ok on success
  ## - WavPlayerResult.NewSamplesRequested when buffer needs refilling (call prepare())
  ## - WavPlayerResult.PlaybackUnderrun if buffer is empty during playback

# ============================================================================
# Playback Control
# ============================================================================

proc restart*[N](player: var WavPlayer[N]) {.importcpp: "#.Restart()", cdecl.}
  ## Clear all playback samples and return to the beginning of the file.

proc setPlaying*[N](player: var WavPlayer[N], state: bool) {.importcpp: "#.SetPlaying(@)", cdecl.}
  ## Start (true) or stop (false) playback.

proc setLooping*[N](player: var WavPlayer[N], state: bool) {.importcpp: "#.SetLooping(@)", cdecl.}
  ## Enable or disable looping playback.

# ============================================================================
# Playback Speed Control
# ============================================================================

proc setPlaybackSpeedRatio*[N](player: var WavPlayer[N], speed: cfloat) {.
  importcpp: "#.SetPlaybackSpeedRatio(@)", cdecl.}
  ## Set playback speed as a ratio of the original speed
  ## (1.0 = normal, 0.5 = half speed, 2.0 = double speed, 0.0 = paused).

proc setPlaybackSpeedSemitones*[N](player: var WavPlayer[N], semitones: cfloat) {.
  importcpp: "#.SetPlaybackSpeedSemitones(@)", cdecl.}
  ## Set playback speed as a semitone offset from the original pitch.
  ## The speed ratio is calculated as 2^(semitones/12).

# ============================================================================
# State Query Methods
# ============================================================================

proc getDurationInSamples*[N](player: WavPlayer[N]): csize_t {.
  importcpp: "#.GetDurationInSamples()", cdecl.}
  ## Get the total number of samples in the audio file.
proc getChannels*[N](player: WavPlayer[N]): csize_t {.
  importcpp: "#.GetChannels()", cdecl.}
  ## Get the number of audio channels in the file.
proc getPosition*[N](player: WavPlayer[N]): uint32 {.
  importcpp: "#.GetPosition()", cdecl.}
  ## Get the current playhead position in samples from the start of the file.
proc getNormalizedPosition*[N](player: WavPlayer[N]): cfloat {.
  importcpp: "#.GetNormalizedPosition()", cdecl.}
  ## Get the playhead position as a 0.0-1.0 value within the file.
proc getLooping*[N](player: WavPlayer[N]): bool {.importcpp: "#.GetLooping()", cdecl.}
  ## Check if looping is enabled.
proc getPlaying*[N](player: WavPlayer[N]): bool {.importcpp: "#.GetPlaying()", cdecl.}
  ## Check if playback is currently active.

# ============================================================================
# Helper Functions
# ============================================================================

proc play*[N](player: var WavPlayer[N]) {.inline.} =
  ## Start playback (convenience for `setPlaying(true)`)
  player.setPlaying(true)

proc stop*[N](player: var WavPlayer[N]) {.inline.} =
  ## Stop playback (convenience for `setPlaying(false)`)
  player.setPlaying(false)

proc durationSeconds*[N](player: WavPlayer[N]): float {.inline.} =
  ## Get the total duration of the file in seconds.
  ##
  ## Note: WAV files are resampled to the Daisy audio system's default
  ## sample rate of 48kHz during playback.
  result = float(player.getDurationInSamples()) / 48000.0

proc isEof*[N](player: WavPlayer[N]): bool {.inline.} =
  ## Check if playback has reached the end of file.
  ## Only returns true when not looping and playback stopped at end.
  result = not player.getPlaying() and player.getPosition() >= player.getDurationInSamples()
