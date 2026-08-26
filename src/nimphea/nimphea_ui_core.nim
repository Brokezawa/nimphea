## UI Core System
## ===============
##
## This module wraps libDaisy's UI core system which manages page stacks,
## event routing, and display management for complex user interfaces.
##
## **Features:**
## - Page stack management (up to 32 pages)
## - Event routing from UiEventQueue to pages
## - Multiple canvas support (up to 8 displays)
## - Special control ID mapping (OK, Cancel, arrows, encoders, pots)
## - Automatic refresh rate management per canvas
## - Page visibility and focus management
## - Input muting with optional event queuing
##
## **Wrapped Header:** `ui/UI.h`
##
## Example - Simple UI with one page:
## ```nim
## import nimphea_ui_core
## import nimphea_ui_events
## import nimphea_menu
## 
## # Create event queue
## var eventQueue = initUiEventQueue()
## 
## # Configure special controls
## var controlIds = initUiSpecialControlIds()
## controlIds.okBttnId = 0
## controlIds.cancelBttnId = 1
## controlIds.upBttnId = 2
## controlIds.downBttnId = 3
## 
## # Create canvas descriptor
## var canvas = createCanvasDescriptor(0, displayPtr, 50)
## 
## # Initialize UI
## var ui = initUI()
## ui.init(eventQueue, controlIds, [canvas], 0)
## 
## # Add page
## ui.openPage(myPage)
## 
## # Main loop
## while true:
##   ui.process()  # Handle events and redraw
##   hw.delay(ms(10))
## ```
##
## Example - Multi-page menu system:
## ```nim
## # Create menu pages
## var mainMenu: FullScreenItemMenu
## var settingsMenu: FullScreenItemMenu
## # ... configure menus ...
## 
## # Add main menu
## ui.openPage(cast[ptr UiPage](addr mainMenu))
## 
## # Later, open settings (adds to stack)
## ui.openPage(cast[ptr UiPage](addr settingsMenu))
## 
## # Close settings (returns to main)
## ui.closePage(cast[ptr UiPage](addr settingsMenu))
## ```

import std/os
import nimphea
import nimphea_ui_events
import nimphea_menu  # For UiPage type

# Include UI core headers and typedefs

# Compiled C++ bridge for UI::Init's std::initializer_list parameter
# (see ui_init_helper.h in this directory)
{.compile: currentSourcePath().parentDir / "ui_init_helper.cpp".}

{.push header: "ui/UI.h".}

# ============================================================================
# Constants
# ============================================================================

## Maximum number of pages in the UI stack
const UI_MAX_PAGES* = 32

## Maximum number of canvases (displays) supported
const UI_MAX_CANVASES* = 8

## Invalid canvas ID constant
const INVALID_CANVAS_ID* = uint16.high

# ============================================================================
# Special Control IDs Configuration
# ============================================================================

## Configuration for special button/encoder/pot IDs
## Set to INVALID_*_ID constants if control is not available
type
  UiSpecialControlIds* {.importcpp: "daisy::UI::SpecialControlIds",
                          bycopy.} = object
    ## Function button ID (for coarse stepping)
    funcBttnId* {.importc.}: uint16
    ## OK/Enter button ID
    okBttnId* {.importc.}: uint16
    ## Cancel/Back button ID
    cancelBttnId* {.importc.}: uint16
    ## Up arrow button ID
    upBttnId* {.importc.}: uint16
    ## Down arrow button ID
    downBttnId* {.importc.}: uint16
    ## Left arrow button ID
    leftBttnId* {.importc.}: uint16
    ## Right arrow button ID
    rightBttnId* {.importc.}: uint16
    ## Menu navigation encoder ID
    menuEncoderId* {.importc.}: uint16
    ## Value editing encoder ID
    valueEncoderId* {.importc.}: uint16
    ## Value potentiometer/slider ID
    valuePotId* {.importc.}: uint16

# Constructor for SpecialControlIds
proc initUiSpecialControlIds*(): UiSpecialControlIds {.
  importcpp: "daisy::UI::SpecialControlIds()".}
  ## Create SpecialControlIds with all IDs set to invalid

# ============================================================================
# UI Core Class
# ============================================================================

## Main UI coordinator class
type
  UI* {.importcpp: "daisy::UI", header: "ui/UI.h".} = object

# UI constructor/destructor
proc initUI*(): UI {.importcpp: "daisy::UI()", header: "ui/UI.h".}
  ## Create new UI instance

{.pop.}  # header pragma (type block only — wrappers and methods carry inline headers)

# UI initialization - needs special handling for initializer_list
#
# daisy::UI::Init() takes a std::initializer_list<UiCanvasDescriptor>.
# Nim has no native equivalent, so the bridge lives in a small compiled
# C++ helper (ui_init_helper.cpp, included via {.compile.}) that builds
# the initializer_list from an array + count.
proc cppUiInitHelper*(ui: ptr UI,
                     eventQueue: var UiEventQueue,
                     controlIds: UiSpecialControlIds,
                     canvases: ptr UiCanvasDescriptor,
                     numCanvases: csize_t,
                     primaryDisplayId: uint16) {.
  importcpp: "UI_Init_Helper(@)", header: "ui_init_helper.h".}

proc init*(this: var UI,
          eventQueue: var UiEventQueue,
          controlIds: UiSpecialControlIds,
          canvases: openArray[UiCanvasDescriptor],
          primaryDisplayId: uint16 = INVALID_CANVAS_ID) {.inline.} =
  ## Initialize UI system
  ##
  ## **Parameters:**
  ## - `eventQueue` - UiEventQueue to read input events from
  ## - `controlIds` - Special control ID configuration
  ## - `canvases` - Array of canvas descriptors for displays
  ## - `primaryDisplayId` - Canvas ID for primary display (menus, etc.)
  if canvases.len > 0:
    cppUiInitHelper(addr this, eventQueue, controlIds,
                   addr canvases[0], canvases.len.csize_t,
                   primaryDisplayId)

# UI core methods
proc process*(this: var UI) {.importcpp: "#.Process()", header: "ui/UI.h".}
  ## Process events and update displays
  ## Call this regularly from main loop (low priority context)

proc mute*(this: var UI, shouldBeMuted: bool, queueEvents: bool = false) {.
  importcpp: "#.Mute(@)", header: "ui/UI.h".}
  ## Mute/unmute user input processing
  ##
  ## **Parameters:**
  ## - `shouldBeMuted` - true to mute, false to unmute
  ## - `queueEvents` - If true, queue events while muted; if false, discard them

proc openPage*(this: var UI, page: var UiPage) {.importcpp: "#.OpenPage(@)", header: "ui/UI.h".}
  ## Add page to top of page stack
  ## Page must remain alive until removed from UI

proc closePage*(this: var UI, page: var UiPage) {.importcpp: "#.ClosePage(@)", header: "ui/UI.h".}
  ## Remove page from stack

proc getPrimaryOneBitGraphicsDisplayId*(this: var UI): uint16 {.
  importcpp: "#.GetPrimaryOneBitGraphicsDisplayId()", header: "ui/UI.h".}
  ## Get canvas ID of primary graphics display
  ## Returns INVALID_CANVAS_ID if none configured

proc getSpecialControlIds*(this: var UI): UiSpecialControlIds {.
  importcpp: "#.GetSpecialControlIds()", header: "ui/UI.h".}
  ## Get special control ID configuration

# ============================================================================
# Canvas Descriptor Helpers
# ============================================================================

# Forward declare clear/flush function types
type
  CanvasClearFunc* = proc(canvas: var UiCanvasDescriptor) {.cdecl.}
  CanvasFlushFunc* = proc(canvas: var UiCanvasDescriptor) {.cdecl.}

proc createCanvasDescriptor*(id: uint8,
                             handle: pointer,
                             updateRateMs: uint32,
                             clearFunc: CanvasClearFunc = nil,
                             flushFunc: CanvasFlushFunc = nil,
                             screenSaverTimeout: uint32 = 0): UiCanvasDescriptor =
  ## Create a canvas descriptor
  ##
  ## **Parameters:**
  ## - `id` - Unique canvas ID
  ## - `handle` - Pointer to display object (cast to specific type in Draw)
  ## - `updateRateMs` - Refresh rate in milliseconds
  ## - `clearFunc` - Optional function to clear display before drawing
  ## - `flushFunc` - Optional function to flush/update display after drawing
  ## - `screenSaverTimeout` - Timeout in ms before screensaver (0=disabled)
  result.id = id
  result.handle = handle
  result.updateRateMs = updateRateMs
  result.screenSaverTimeOut = screenSaverTimeout
  result.screenSaverOn = false
  # clearFunction_ and flushFunction_ are declared as importc fields on
  # UiCanvasDescriptor (daisy::UiCanvasDescriptor members), so the plain
  # Nim assignments below map directly to the C++ function pointers.
  result.clearFn = clearFunc
  result.flushFn = flushFunc

# ============================================================================
# Helper Procs for Common Patterns
# ============================================================================

proc initUiWithDefaults*(eventQueue: var UiEventQueue,
                        okButton: uint16 = INVALID_BUTTON_ID,
                        cancelButton: uint16 = INVALID_BUTTON_ID,
                        upButton: uint16 = INVALID_BUTTON_ID,
                        downButton: uint16 = INVALID_BUTTON_ID): UI =
  ## Create and initialize UI with common button configuration
  ##
  ## Sets up a basic UI with optional OK, Cancel, Up, Down buttons.
  ## Other controls default to invalid IDs.
  result = initUI()
  
  var controlIds = initUiSpecialControlIds()
  controlIds.okBttnId = okButton
  controlIds.cancelBttnId = cancelButton
  controlIds.upBttnId = upButton
  controlIds.downBttnId = downButton
  
  # No canvases yet - add via init() call
  # This is just a helper to pre-configure controls

proc addButtonEvent*(eventQueue: var UiEventQueue,
                    ui: var UI,
                    buttonId: uint16,
                    isPressed: bool,
                    numPresses: uint16 = 1,
                    isRetriggering: bool = false) =
  ## Helper to add button event to queue
  ## Automatically uses correct event type based on state
  if isPressed:
    eventQueue.addButtonPressed(buttonId, numPresses, isRetriggering)
  else:
    eventQueue.addButtonReleased(buttonId)

proc addEncoderEvent*(eventQueue: var UiEventQueue,
                     encoderId: uint16,
                     increments: int16,
                     stepsPerRev: uint16 = 24) =
  ## Helper to add encoder rotation event
  eventQueue.addEncoderTurned(encoderId, increments, stepsPerRev)

proc addPotEvent*(eventQueue: var UiEventQueue,
                 potId: uint16,
                 position: cfloat) =
  ## Helper to add potentiometer movement event
  ## Position should be 0.0-1.0
  eventQueue.addPotMoved(potId, position)
