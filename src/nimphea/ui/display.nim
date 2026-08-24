## Display Concepts
## =================
##
## Nim-friendly display abstraction layer providing concepts and generic
## programming patterns for working with displays.
##
## This module provides higher-level abstractions over the low-level
## display drivers (SH1106, SSD1327, SSD1351).

type
  DisplayConcept* = concept d
    ## Generic display concept - any type that implements these methods
    ## can be used with generic display functions
    d.fill(bool)           ## Fill display with color
    d.update()             ## Send buffer to hardware
    d.width() is int       ## Get display width
    d.height() is int      ## Get display height

# Helper templates for working with displays

template withDisplay*(display: var auto, body: untyped) =
  ## Execute drawing operations and automatically update display
  ## 
  ## **Example**:
  ## ```nim
  ## display.withDisplay:
  ##   display.fill(false)
  ##   display.drawRect(10, 10, 50, 20, true)
  ## # display.update() called automatically
  ## ```
  body
  display.update()

template clearAndDraw*(display: var auto, body: untyped) =
  ## Clear display and execute drawing operations
  ## 
  ## **Example**:
  ## ```nim
  ## display.clearAndDraw:
  ##   display.drawCircle(64, 32, 20, true)
  ## ```
  display.fill(false)
  body
  display.update()
