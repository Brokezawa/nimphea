## 2D drawing primitives for OLED and graphics displays
##
## Bresenham line/circle and rectangle drawing helpers shared by every display
## driver. Implemented as templates so the inner `drawPixel` calls resolve in
## the importing module's scope — any display type exposing
## `drawPixel(display, x, y, on)` can use them. Drivers call these with a
## `draw2d.` qualifier from their concrete wrapper procs, keeping the public
## API per-driver while the algorithm lives here once.
##
## Example (typically reached through a display driver, which re-exports this):
## ```nim
## display.drawLine(0, 0, 127, 63)          # Diagonal
## display.drawRect(10, 10, 40, 20)          # Outline
## display.fillRect(12, 12, 36, 16, off)     # Filled (inverted)
## display.drawCircle(64, 32, 12)            # Circle outline
## ```

template drawLine*(display: untyped, x0, y0, x1, y1: untyped, on: untyped = true) =
  ## Draw a line using Bresenham's algorithm.
  ##
  ## **Parameters:**
  ## - `x0`, `y0` - Start point
  ## - `x1`, `y1` - End point
  ## - `on` - true to draw with the current color, false for black/background
  var x0 = x0
  var y0 = y0
  let dx = abs(x1 - x0)
  let dy = abs(y1 - y0)
  let sx = if x0 < x1: 1 else: -1
  let sy = if y0 < y1: 1 else: -1
  var err = dx - dy
  while true:
    display.drawPixel(x0, y0, on)
    if x0 == x1 and y0 == y1:
      break
    let e2 = 2 * err
    if e2 > -dy:
      err -= dy
      x0 += sx
    if e2 < dx:
      err += dx
      y0 += sy

template drawRect*(display: untyped, x, y, w, h: untyped, on: untyped = true) =
  ## Draw a rectangle outline.
  ##
  ## **Parameters:**
  ## - `x`, `y` - Top-left corner
  ## - `w`, `h` - Width and height
  ## - `on` - true to draw with the current color, false for black/background
  for i in 0..<w:
    display.drawPixel(x + i, y, on)
    display.drawPixel(x + i, y + h - 1, on)
  for i in 0..<h:
    display.drawPixel(x, y + i, on)
    display.drawPixel(x + w - 1, y + i, on)

template fillRect*(display: untyped, x, y, w, h: untyped, on: untyped = true) =
  ## Draw a filled rectangle.
  ##
  ## **Parameters:**
  ## - `x`, `y` - Top-left corner
  ## - `w`, `h` - Width and height
  ## - `on` - true to draw with the current color, false for black/background
  for j in 0..<h:
    for i in 0..<w:
      display.drawPixel(x + i, y + j, on)

template drawCircle*(display: untyped, x0, y0, radius: untyped, on: untyped = true) =
  ## Draw a circle outline using the midpoint circle algorithm.
  ##
  ## **Parameters:**
  ## - `x0`, `y0` - Center point
  ## - `radius` - Circle radius in pixels
  ## - `on` - true to draw with the current color, false for black/background
  var x = radius
  var y = 0
  var err = 0
  while x >= y:
    display.drawPixel(x0 + x, y0 + y, on)
    display.drawPixel(x0 + y, y0 + x, on)
    display.drawPixel(x0 - y, y0 + x, on)
    display.drawPixel(x0 - x, y0 + y, on)
    display.drawPixel(x0 - x, y0 - y, on)
    display.drawPixel(x0 - y, y0 - x, on)
    display.drawPixel(x0 + y, y0 - x, on)
    display.drawPixel(x0 + x, y0 - y, on)
    if err <= 0:
      inc y
      err += 2 * y + 1
    if err > 0:
      dec x
      err -= 2 * x + 1