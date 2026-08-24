## Event Helpers
## =============
##
## Nim-friendly event handling utilities providing closure-based APIs
## over the low-level UiEventQueue system.
##
## This module provides a higher-level way to handle UI events using
## callbacks instead of polling the event queue.
##
## **Zero-allocation:** the dispatcher stores handlers in fixed-size slot
## arrays; registration and dispatch never allocate on the heap. Up to
## `MAX_HANDLERS` handlers per event type are supported; further
## registrations are ignored (documented limit).

import nimphea_ui_events

type
  ButtonHandler* = proc(id: uint16, presses: uint16) {.closure.}
    ## Closure type for button press events
  
  ButtonReleaseHandler* = proc(id: uint16) {.closure.}
    ## Closure type for button release events
  
  EncoderHandler* = proc(id: uint16, increment: int32, velocity: int32) {.closure.}
    ## Closure type for encoder turn events
  
  PotHandler* = proc(id: uint16, value: float32) {.closure.}
    ## Closure type for potentiometer change events

const
  MAX_HANDLERS* = 8
    ## Maximum number of handlers per event type (fixed slot capacity)

type
  EventDispatcher* = object
    ## Event dispatcher that manages closure-based event handlers.
    ## Handlers are stored in fixed-size slot arrays (no heap allocation).
    queue: ptr UiEventQueue
    buttonHandlers: array[MAX_HANDLERS, ButtonHandler]
    buttonCount: int
    buttonReleaseHandlers: array[MAX_HANDLERS, ButtonReleaseHandler]
    buttonReleaseCount: int
    encoderHandlers: array[MAX_HANDLERS, EncoderHandler]
    encoderCount: int
    potHandlers: array[MAX_HANDLERS, PotHandler]
    potCount: int

proc createEventDispatcher*(queue: var UiEventQueue): EventDispatcher =
  ## Create a new event dispatcher for the given event queue
  result.queue = addr queue

proc onButtonPress*(dispatcher: var EventDispatcher, handler: ButtonHandler) =
  ## Register a handler for button press events
  ## 
  ## **Example**:
  ## ```nim
  ## dispatcher.onButtonPress proc(id: uint16, presses: uint16) =
  ##   echo "Button ", id, " pressed ", presses, " times"
  ## ```
  if dispatcher.buttonCount < MAX_HANDLERS:
    dispatcher.buttonHandlers[dispatcher.buttonCount] = handler
    inc dispatcher.buttonCount

proc onButtonRelease*(dispatcher: var EventDispatcher, handler: ButtonReleaseHandler) =
  ## Register a handler for button release events
  if dispatcher.buttonReleaseCount < MAX_HANDLERS:
    dispatcher.buttonReleaseHandlers[dispatcher.buttonReleaseCount] = handler
    inc dispatcher.buttonReleaseCount

proc onEncoder*(dispatcher: var EventDispatcher, handler: EncoderHandler) =
  ## Register a handler for encoder turn events
  ## 
  ## **Example**:
  ## ```nim
  ## dispatcher.onEncoder proc(id: uint16, increment: int32, velocity: int32) =
  ##   volume += increment
  ##   if volume < 0: volume = 0
  ##   if volume > 100: volume = 100
  ## ```
  if dispatcher.encoderCount < MAX_HANDLERS:
    dispatcher.encoderHandlers[dispatcher.encoderCount] = handler
    inc dispatcher.encoderCount

proc onPot*(dispatcher: var EventDispatcher, handler: PotHandler) =
  ## Register a handler for potentiometer change events
  if dispatcher.potCount < MAX_HANDLERS:
    dispatcher.potHandlers[dispatcher.potCount] = handler
    inc dispatcher.potCount

proc process*(dispatcher: var EventDispatcher) =
  ## Process all events in the queue and call registered handlers.
  ## Call this in your main loop.
  while not dispatcher.queue[].isQueueEmpty():
    let event = dispatcher.queue[].getAndRemoveNextEvent()
    case event.eventType
    of buttonPressed:
      for i in 0..<dispatcher.buttonCount:
        dispatcher.buttonHandlers[i](event.asButtonPressed.id, event.asButtonPressed.numSuccessivePresses)
    of buttonReleased:
      for i in 0..<dispatcher.buttonReleaseCount:
        dispatcher.buttonReleaseHandlers[i](event.asButtonReleased.id)
    of encoderTurned:
      for i in 0..<dispatcher.encoderCount:
        dispatcher.encoderHandlers[i](event.asEncoderTurned.id, event.asEncoderTurned.increments.int32, 0)
    of potMoved:
      for i in 0..<dispatcher.potCount:
        dispatcher.potHandlers[i](event.asPotMoved.id, event.asPotMoved.newPosition)
    else:
      discard

# Convenience template for event handling in main loop
template processEvents*(dispatcher: var EventDispatcher, body: untyped) =
  ## Process events and execute custom code
  ## 
  ## **Example**:
  ## ```nim
  ## dispatcher.processEvents:
  ##   # Custom per-frame logic here
  ##   updateDisplay()
  ## ```
  dispatcher.process()
  body

# Chain multiple handlers together (allocation-free: the registered handlers
# are simply invoked in registration order at dispatch time)
template chain*(dispatcher: var EventDispatcher, handlers: varargs[ButtonHandler]) =
  ## Register multiple button handlers to fire in sequence, in order.
  ## 
  ## **Example**:
  ## ```nim
  ## dispatcher.chain(
  ##   proc(id: uint16, presses: uint16) = echo "Handler 1",
  ##   proc(id: uint16, presses: uint16) = echo "Handler 2"
  ## )
  ## ```
  for h in handlers:
    dispatcher.onButtonPress(h)

# Specific button ID handlers for common patterns
type
  SpecificButtonHandlers* = object
    ## Handlers for specific button IDs
    handlers: array[16, ButtonHandler]  # Support up to 16 buttons

proc createSpecificButtonHandlers*(): SpecificButtonHandlers =
  ## Create handlers for specific button IDs
  discard

proc onButton*(handlers: var SpecificButtonHandlers, buttonId: uint16, 
               handler: ButtonHandler) =
  ## Register handler for a specific button ID
  ## 
  ## **Example**:
  ## ```nim
  ## var buttons = createSpecificButtonHandlers()
  ## buttons.onButton(0, proc(id: uint16, presses: uint16) =
  ##   echo "OK button pressed"
  ## )
  ## ```
  if buttonId < 16:
    handlers.handlers[buttonId] = handler

proc dispatch*(handlers: var SpecificButtonHandlers, id: uint16, presses: uint16) =
  ## Dispatch button event to registered handler
  if id < 16 and handlers.handlers[id] != nil:
    handlers.handlers[id](id, presses)