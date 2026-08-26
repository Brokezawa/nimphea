## WAV File Recording Module
## =========================
##
## This module provides WAV file recording functionality for the Daisy platform.
## It supports real-time recording to SD card with 16-bit and 32-bit formats.
##
## Features:
## - Real-time audio recording to WAV files
## - 16-bit and 32-bit signed integer formats
## - Float input with automatic conversion
## - Double-buffered streaming for uninterrupted recording
## - Automatic WAV header generation and finalization
##
## Memory Usage:
## - (2 * transfer_size) bytes
## - Default 32KB transfer = 64KB total memory
## - 16KB transfer = 32KB total (lower latency, more disk I/O)
##
## Usage Example:
## ```nim
## import nimphea/nimphea_wavwriter
##
## var writer: WavWriter32K
##
## # Initialize (config size must match the writer size)
## writer.init(createConfig[32768](48000.0, 2, 16))
##
## # Open file for recording
## writer.openFile("recording.wav")
##
## # In audio callback
## proc audioCallback(input, output: AudioBuffer, size: int) =
##   for i in 0..<size:
##     writer.sample(addr input[0][i])  # Record input
##
## # In main loop
## while recording:
##   writer.write()  # Write to SD card
##   delay(1)
##
## # When done
## writer.saveFile()  # Finalize and close
## ```



# Forward declarations
type
  # Generic config over the C++ WavWriter<N>::Config type. Bind a config to the
  # same size as its writer — no casts across sizes.
  WavWriterConfig*[N: static int] {.importcpp: "daisy::WavWriter<'0>::Config", bycopy.} = object
    samplerate* {.importcpp: "samplerate".}: cfloat
    channels* {.importcpp: "channels".}: int32
    bitspersample* {.importcpp: "bitspersample".}: int32

  # Generic streaming writer over the C++ WavWriter<transfer_size> template.
  # Only instantiated sizes are linked.
  WavWriter*[N: static int] {.importcpp: "daisy::WavWriter<'0>", byref.} = object

# Convenience aliases for common transfer sizes
type
  WavWriter16K* = WavWriter[16384] ## 16KB transfer (lower latency, more frequent disk writes)
  WavWriter32K* = WavWriter[32768] ## 32KB transfer (balanced performance)
  WavWriter64K* = WavWriter[65536] ## 64KB transfer (maximum throughput, higher latency)

# ============================================================================
# Core Methods
# ============================================================================

proc init*[N](writer: var WavWriter[N], config: WavWriterConfig[N]) {.
  importcpp: "#.Init(@)", cdecl.}
  ## Initialize the WAV writer with the given configuration.
  ## This prepares the WAV header and internal buffers.
  ## Must be called before `openFile`.
  ##
  ## Example:
  ## ```nim
  ## var config = createConfig[32768](48000.0, 2, 16)
  ## writer.init(config)
  ## ```

proc openFile*[N](writer: var WavWriter[N], name: cstring) {.
  importcpp: "#.OpenFile(@)", cdecl.}
  ## Open a new file for recording.
  ## This will create the file (overwriting if it exists) and write the
  ## initial WAV header. After calling this, use `sample` in the audio
  ## callback to record audio.

proc sample*[N](writer: var WavWriter[N], input: ptr cfloat) {.
  importcpp: "#.Sample(@)", cdecl.}
  ## Record a single audio frame (all channels).
  ## **Call this from your audio callback** for each sample frame.
  ##
  ## The input should point to an array of floats with as many elements as
  ## the configured number of channels. Float values are automatically
  ## converted to the configured bit depth.
  ##
  ## Example:
  ## ```nim
  ## # In audio callback
  ## var frame = [input[0][i], input[1][i]]  # Stereo
  ## writer.sample(frame[0].addr)
  ## ```

proc write*[N](writer: var WavWriter[N]) {.importcpp: "#.Write()", cdecl.}
  ## Write buffered audio data to the SD card.
  ## **Must be called regularly in the main loop** (not in audio callback)
  ## to prevent buffer overflow.
  ##
  ## Example:
  ## ```nim
  ## # In main loop
  ## while recording:
  ##   writer.write()
  ##   delay(1)
  ## ```

proc saveFile*[N](writer: var WavWriter[N]) {.importcpp: "#.SaveFile()", cdecl.}
  ## Finalize and close the recording: flush remaining data, update the WAV
  ## header with the final file size, and close the file.
  ## **Must be called** when recording is complete to ensure a valid WAV file.

# ============================================================================
# State Query Methods
# ============================================================================

proc isRecording*[N](writer: WavWriter[N]): bool {.importcpp: "#.IsRecording()", cdecl.}
  ## Check if recording is currently active (true after `openFile` and
  ## before `saveFile`).

proc getLengthSamps*[N](writer: var WavWriter[N]): uint32 {.importcpp: "#.GetLengthSamps()", cdecl.}
  ## Get the current length of the recording in sample frames
  ## (not the total number of individual channel samples).

proc getLengthSeconds*[N](writer: var WavWriter[N]): cfloat {.importcpp: "#.GetLengthSeconds()", cdecl.}
  ## Get the current length of the recording in seconds.

# ============================================================================
# Helper Functions
# ============================================================================

proc createConfig*[N](samplerate: float, channels: int, bitspersample: int): WavWriterConfig[N] {.inline.} =
  ## Create a WavWriterConfig for a specific writer size (use the same N as
  ## your writer, e.g. `createConfig[32768]` for `WavWriter32K`).
  ##
  ## Parameters:
  ## - samplerate: Sample rate in Hz (e.g., 48000.0)
  ## - channels: Number of audio channels (1=mono, 2=stereo)
  ## - bitspersample: Bit depth (16 or 32)
  ##
  ## Example:
  ## ```nim
  ## var config = createConfig[32768](48000.0, 2, 16)
  ## writer.init(config)
  ## ```
  result.samplerate = cfloat(samplerate)
  result.channels = int32(channels)
  result.bitspersample = int32(bitspersample)
