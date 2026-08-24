## Unit tests for StackString numeric formatting utilities
##
## Verifies `nimphea_stack_strings_utils` `add(int)`/`add(float)`/`set`
## against Nim's `$` output and the truncation contract.

import std/unittest
import nimphea/stack_strings
import nimphea/nimphea_stack_strings_utils

suite "StackString utils - Integer add":
  test "Integers are byte-identical to $":
    for value in [0, 1, -1, 42, -42, 9, 10, -10, 1000, 123456789, int.high, int.low]:
      var s: StackString[32]
      discard s.add(value)
      check $s == $value

  test "Begin-capacity integers fit where declared":
    var s: StackString[20]
    discard s.add(int.low)
    check $s == $int.low

  test "Overflow truncates and returns count appended":
    var s: StackString[4]
    let count = s.add(123456)
    check count == 4
    check $s == "1234"

suite "StackString utils - Float add":
  test "Floats are byte-identical to $ (shortest round-trip)":
    for value in [0.0, 0.07, 0.15, 3.14, 440.0, -12.5, 1e-7, 1e-8, 1234567.0,
                  1e16, 1e17, 1e20, -1e-5, 3.14159265358979]:
      var s: StackString[40]
      discard s.add(value)
      check $s == $value

  test "float32 values format like $":
    for value in [0.5'f32, 3.14'f32, -1.0'f32]:
      var s: StackString[32]
      discard s.add(value)
      check $s == $value

suite "StackString utils - Set":
  test "set replaces contents and returns count":
    var s: StackString[16]
    s.add("old text")
    let count = s.set("Volume: 75%")
    check count == 11
    check $s == "Volume: 75%"

  test "set truncates at capacity":
    var s: StackString[8]
    let count = s.set("123456789")
    check count == 8
    check $s == "12345678"

  test "set after last use can be reused":
    var buffer: StackString[16]
    discard buffer.set("Line 1")
    check $buffer == "Line 1"
    discard buffer.set("Line 2")
    check $buffer == "Line 2"

suite "StackString utils - Practical usage":
  test "Display formatting with parameters":
    var display: StackString[32]
    display.add("Freq: ")
    discard display.add(440)
    display.add(" Hz")
    check $display == "Freq: 440 Hz"

suite "StackString utils - Callback safety":
  test "{.raises: [].} contract compiles":
    proc format(s: var StackString[64], v: int, f: float) {.raises: [].} =
      discard s.add(v)
      discard s.add(f)
    var buf: StackString[64]
    format(buf, 12, 0.5)
    check $buf == "120.5"
