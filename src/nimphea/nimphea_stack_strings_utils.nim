## StackString numeric formatting utilities
##
## Allocation-free `add`/`set` overloads for the vendored `StackString` type.
## Integer and float rendering is byte-identical to Nim's `$`, but writes
## directly into the stack buffer — no heap allocation. All procs are
## `{.raises: [].}`, truncate to the remaining capacity, and return the number
## of characters appended, so they are safe inside `{.cdecl, raises: [].}`
## audio/display callbacks.

import std/formatfloat
import nimphea/stack_strings

const maxIntDigits = 20

proc add*(ss: var StackString, value: int): int {.raises: [].} =
  ## Append the decimal representation of `value`, byte-identical to `$value`.
  ## Truncates if it does not fit the remaining capacity and returns the number
  ## of characters appended.
  ##
  ## **Example:**
  ## ```nim
  ## var s: StackString[16]
  ## discard s.add(-42)
  ## assert s == "-42"
  ## ```
  var buf: array[maxIntDigits, char]
  var u = if value >= 0: uint64(value) else: uint64(-(value + 1)) + 1
  var i = maxIntDigits
  while u >= 10:
    dec i
    buf[i] = char(ord('0') + int(u mod 10))
    u = u div 10
  dec i
  buf[i] = char(ord('0') + int(u))
  if value < 0:
    dec i
    buf[i] = '-'
  for j in i ..< maxIntDigits:
    if not ss.tryAdd(buf[j]):
      break
    inc result

proc addFloat(ss: var StackString, value: SomeFloat): int {.raises: [].} =
  var buf {.noinit.}: array[65, char]
  let count = writeFloatToBufferRoundtrip(buf, value)
  for i in 0 ..< count:
    if not ss.tryAdd(buf[i]):
      break
    inc result

proc add*(ss: var StackString, value: float): int {.raises: [].} =
  ## Append `value` in shortest-round-trip form, byte-identical to `$value`.
  ## Truncates if it does not fit the remaining capacity and returns the number
  ## of characters appended.
  ##
  ## **Example:**
  ## ```nim
  ## var s: StackString[16]
  ## discard s.add(0.5)
  ## assert s == "0.5"
  ## ```
  addFloat(ss, value)

proc add*(ss: var StackString, value: float32): int {.raises: [].} =
  ## Append a 32-bit float in shortest-round-trip form, byte-identical to
  ## `$value`. Truncates if it does not fit the remaining capacity and returns
  ## the number of characters appended.
  ##
  ## **Example:**
  ## ```nim
  ## var s: StackString[16]
  ## discard s.add(0.5'f32)
  ## assert s == "0.5"
  ## ```
  addFloat(ss, value)

proc set*(ss: var StackString, text: string): int {.raises: [].} =
  ## Replace the contents with `text`, truncating if it does not fit, and
  ## return the number of characters placed. Never raises.
  ##
  ## **Example:**
  ## ```nim
  ## var s: StackString[16]
  ## discard s.set("Volume: 75%")
  ## assert s == "Volume: 75%"
  ## ```
  ss.unsafeSetLen(0)
  for c in text:
    if not ss.tryAdd(c):
      break
    inc result
