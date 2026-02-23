## CMSIS-DSP Demonstration
##
## This example demonstrates various CMSIS-DSP functions in Nim:
## - Fast math (sin, sqrt)
## - Vector operations (add, scale)
## - Statistics (mean, max)
## - Filtering (FIR)
## - Complex math (magnitude)

import std/math
import nimphea
import nimphea/cmsis

useNimpheaNamespace()

proc main() =
  var daisy = initDaisy()
  startLog()
  printLine("CMSIS-DSP Demo Started")

  # 1. Fast Math
  let s = fastSin(PI / 2.0)
  let root = fastSqrt(16.0)
  print("Sin(PI/2): ")
  printLine(s)
  print("Sqrt(16): ")
  printLine(root)

  # 2. Vector Operations
  var v1 = [1.0'f32, 2.0, 3.0, 4.0]
  var v2 = [10.0'f32, 20.0, 30.0, 40.0]
  var v3: array[4, float32]
  
  add(v3, v1, v2)
  print("Vector Add [1,2,3,4] + [10,20,30,40] = ")
  for i in 0..3:
    print(v3[i])
    print(" ")
  printLine()

  # 3. Statistics
  let m = mean(v3)
  let (val, idx) = max(v3)
  print("Mean: ")
  printLine(m)
  print("Max: ")
  print(val)
  print(" at index ")
  printLine(idx)

  # 4. Filtering (FIR)
  const coeffs: array[3, float32] = [0.5'f32, 0.5, 0.5]
  var filter: FirFilter[3, 4]
  filter.init(addr coeffs[0])
  
  var input = [1.0'f32, 0.0, 0.0, 0.0]
  var output: array[4, float32]
  filter.process(input, output)
  
  print("FIR Impulse Response: ")
  for i in 0..3:
    print(output[i])
    print(" ")
  printLine()

  # 5. Complex Math
  var c1 = [3.0'f32, 4.0] # 3 + 4i
  var magRes: array[1, float32]
  mag(magRes, c1)
  print("Complex Mag [3+4i]: ")
  printLine(magRes[0])

  printLine("Demo Complete!")

  while true:
    daisy.toggleLed()
    daisy.delay(500)

when isMainModule:
  main()
