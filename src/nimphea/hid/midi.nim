## MIDI support for libDaisy Nim wrapper
##
## This module provides MIDI functionality for the Daisy Audio Platform.
##
## Example - USB MIDI input:
## ```nim
## import nimphea, hid/midi, per/uart
##
## var daisy = initDaisy()
## var midi: MidiUsbHandler
## initMidiUsb(midi)
##
## startLog()
## printLine("MIDI Input Started")
##
## while true:
##   midi.listen()
##
##   while midi.hasEvents:
##     let event = midi.popEvent()
##
##     case event.messageType
##     of NoteOn:
##       let note = event.note
##       print("Note On: ")
##       print(note.number)
##       print(" Vel: ")
##       printLine(note.velocity)
##
##     of NoteOff:
##       let note = event.note
##       print("Note Off: ")
##       printLine(note.number)
##
##     of ControlChange:
##       let cc = event.controlChange
##       print("CC ")
##       print(cc.number)
##       print(": ")
##       printLine(cc.value)
##
##     else: discard
##
##   daisy.delay(1)
## ```
##
## Example - UART MIDI with output (TRS/DIN MIDI):
## ```nim
## import nimphea, hid/midi
##
## var daisy = initDaisy()
## var midi: MidiUartHandler
## var config = newMidiUartConfig()
## config.transport_config.periph = USART_1
## config.transport_config.rx = newPin(PORTB, 7)
## config.transport_config.tx = newPin(PORTB, 6)
## initMidiUart(midi, config)
##
## # Send a note on message
## var noteOn = [0x90'u8, 60, 100]  # Channel 1, note C4, velocity 100
## midi.sendMessage(noteOn[0].addr, 3)
##
## # Receive and echo messages
## while true:
##   midi.listen()
##   while midi.hasEvents:
##     let event = midi.popEvent()
##     # Process or echo the event
## ```

# Import libdaisy which provides the macro system
import nimphea
export nimphea_core_types

# Use the macro system for this module's compilation unit

{.push header: "hid/midi.h".}

# =============================================================================
# MidiUsbHandler (bind-once)
# =============================================================================
proc init*(midi: var MidiUsbHandler, config: MidiUsbHandlerConfig) {.importcpp: "#.Init(@)".}
proc listen*(midi: var MidiUsbHandler) {.importcpp: "#.Listen()".}
  ## Process incoming USB MIDI data (call this regularly in your loop)
proc hasEvents*(midi: var MidiUsbHandler): bool {.importcpp: "#.HasEvents()".}
  ## Check if there are any USB MIDI events waiting
proc popEvent*(midi: var MidiUsbHandler): MidiEvent {.importcpp: "#.PopEvent()".}
  ## Get the next USB MIDI event from the queue
proc startReceive*(midi: var MidiUsbHandler) {.importcpp: "#.StartReceive()".}
proc sendMessage*(midi: var MidiUsbHandler, bytes: ptr uint8, size: csize_t) {.importcpp: "#.SendMessage(@)".}

# =============================================================================
# MidiUartHandler (bind-once)
# =============================================================================
proc init*(midi: var MidiUartHandler, config: MidiUartHandlerConfig) {.importcpp: "#.Init(@)".}
proc listen*(midi: var MidiUartHandler) {.importcpp: "#.Listen()".}
  ## Process incoming UART MIDI data (call this regularly in your loop)
  ##
  ## Note: This also handles UART error recovery.
proc hasEvents*(midi: var MidiUartHandler): bool {.importcpp: "#.HasEvents()".}
  ## Check if there are any UART MIDI events waiting
proc popEvent*(midi: var MidiUartHandler): MidiEvent {.importcpp: "#.PopEvent()".}
  ## Get the next UART MIDI event from the queue
proc startReceive*(midi: var MidiUartHandler) {.importcpp: "#.StartReceive()".}
proc sendMessage*(midi: var MidiUartHandler, bytes: ptr uint8, size: csize_t) {.importcpp: "#.SendMessage(@)".}

# C++ constructors
proc newMidiUsbConfig*(): MidiUsbHandlerConfig {.importcpp: "daisy::MidiHandler<daisy::MidiUsbTransport>::Config()", constructor.}
proc newMidiUartConfig*(): MidiUartHandlerConfig {.importcpp: "daisy::MidiUartHandler::Config()", constructor.}
proc newMidiUartTransportConfig*(): MidiUartTransportConfig {.importcpp: "daisy::MidiUartTransport::Config()", constructor.}

{.pop.} # header

# =============================================================================
# Retained ergonomics overloads (int -> csize_t conversion, see design D1)
# =============================================================================
proc sendMessage*(midi: var MidiUsbHandler, bytes: ptr uint8, size: int) {.inline.} =
  ## Send raw MIDI bytes over USB.
  ##
  ## **Example:**
  ## ```nim
  ## var noteOn = [0x90'u8, 60, 100]
  ## midi.sendMessage(noteOn[0].addr, 3)
  ## ```
  midi.sendMessage(bytes, size.csize_t)
proc sendMessage*(midi: var MidiUartHandler, bytes: ptr uint8, size: int) {.inline.} =
  ## Send raw MIDI bytes over UART (TRS/DIN MIDI).
  ##
  ## **Example:**
  ## ```nim
  ## var noteOn = [0x90'u8, 60, 100]
  ## midi.sendMessage(noteOn[0].addr, 3)
  ## ```
  midi.sendMessage(bytes, size.csize_t)

# =============================================================================
# Init helpers (constructor + config + start, value-adding)
# =============================================================================
proc initMidiUsb*(midi: var MidiUsbHandler) =
  ## Initialize a MIDI handler for USB MIDI (retained: config + start assembly).
  ##
  ## **Usage:**
  ## ```nim
  ## var midi: MidiUsbHandler
  ## initMidiUsb(midi)
  ## ```
  var cfg: MidiUsbHandlerConfig
  midi.init(cfg)
  midi.startReceive()

proc initMidiUart*[P: static UartPeripheral](midi: var MidiUartHandler, config: MidiUartHandlerConfig) =
  ## Initialize a MIDI handler for UART (TRS/DIN) MIDI.
  ## The UART is encoded in the static parameter `P` (USART_1..6); the
  ## config's own periph field is set from it, so the bus cannot be mistyped.
  ##
  ## **Usage:**
  ## ```nim
  ## var midi: MidiUartHandler
  ## var config = newMidiUartConfig()
  ## config.transport_config.rx = newPin(PORTB, 7)
  ## config.transport_config.tx = newPin(PORTB, 6)
  ## initMidiUart[USART_1](midi, config)
  ## ```
  var cfg = config
  cfg.transport_config.periph = P
  midi.init(cfg)
  midi.startReceive()

# =============================================================================
# Common Helper Functions (work with both USB and UART)
# =============================================================================

type
  NoteEvent* = object
    number*: uint8
    velocity*: uint8

  ControlChangeEvent* = object
    number*: uint8
    value*: uint8

# MidiEvent helper properties - access the C++ fields directly
proc messageType*(event: MidiEvent): MidiMessageType {.importcpp: "#.type", nodecl.}
proc channel*(event: MidiEvent): cint {.importcpp: "#.channel", nodecl.}

proc note*(event: MidiEvent): NoteEvent {.inline.} =
  ## Parse as a note event (for NoteOn/NoteOff messages)
  result.number = event.data[0]
  result.velocity = event.data[1]

proc controlChange*(event: MidiEvent): ControlChangeEvent {.inline.} =
  ## Parse as a control change event
  result.number = event.data[0]
  result.value = event.data[1]

proc pitchBend*(event: MidiEvent): int16 {.inline.} =
  ## Parse as a pitch bend (-8192 to +8191)
  let lsb = event.data[0]
  let msb = event.data[1]
  result = ((msb.int16 shl 7) or lsb.int16) - 8192

proc programChange*(event: MidiEvent): uint8 {.inline.} =
  ## Parse as a program change (0-127)
  result = event.data[0]

proc channelPressure*(event: MidiEvent): uint8 {.inline.} =
  ## Parse as channel pressure (0-127)
  result = event.data[0]

# =============================================================================
# MIDI Message Builder Helpers
# =============================================================================

proc makeMidiNoteOn*(channel: uint8, note: uint8, velocity: uint8): array[3, uint8] {.inline.} =
  ## Create a MIDI Note On message.
  ##
  ## Parameters:
  ##   channel: MIDI channel (0-15, where 0 = channel 1)
  ##   note: Note number (0-127, where 60 = C4)
  ##   velocity: Note velocity (1-127, 0 is treated as note off)
  ##
  ## **Example:**
  ## ```nim
  ## let noteOn = makeMidiNoteOn(0, 60, 100)  # Channel 1, C4, velocity 100
  ## midi.sendMessage(noteOn[0].addr, 3)
  ## ```
  result[0] = 0x90 or (channel and 0x0F)
  result[1] = note and 0x7F
  result[2] = velocity and 0x7F

proc makeMidiNoteOff*(channel: uint8, note: uint8, velocity: uint8 = 0): array[3, uint8] {.inline.} =
  ## Create a MIDI Note Off message.
  result[0] = 0x80 or (channel and 0x0F)
  result[1] = note and 0x7F
  result[2] = velocity and 0x7F

proc makeMidiControlChange*(channel: uint8, ccNumber: uint8, value: uint8): array[3, uint8] {.inline.} =
  ## Create a MIDI Control Change message.
  result[0] = 0xB0 or (channel and 0x0F)
  result[1] = ccNumber and 0x7F
  result[2] = value and 0x7F

proc makeMidiProgramChange*(channel: uint8, program: uint8): array[2, uint8] {.inline.} =
  ## Create a MIDI Program Change message.
  result[0] = 0xC0 or (channel and 0x0F)
  result[1] = program and 0x7F

proc makeMidiPitchBend*(channel: uint8, value: int16): array[3, uint8] {.inline.} =
  ## Create a MIDI Pitch Bend message.
  ##
  ## value: Pitch bend value (-8192 to +8191, where 0 is center)
  let unsigned = (value + 8192).uint16  # Convert to 0-16383 range
  result[0] = 0xE0 or (channel and 0x0F)
  result[1] = (unsigned and 0x7F).uint8  # LSB
  result[2] = ((unsigned shr 7) and 0x7F).uint8  # MSB

when isMainModule:
  echo "libDaisy MIDI wrapper - USB and UART MIDI with output support"
