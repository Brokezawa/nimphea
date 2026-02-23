## CMSIS-DSP Interpolation Functions
##
## This module provides optimized interpolation functions (linear, bilinear).

import cmsis_types, cmsis_core

useCmsisModules(dsp_interpolation)

# ============================================================================
# Linear Interpolation
# ============================================================================

type
  LinearInterpolateInstanceF32* {.importcpp: "arm_linear_interp_instance_f32", header: "arm_math.h".} = object
    nValues*: uint32
    x1*: float32_t
    xSpacing*: float32_t
    pYData*: ptr float32_t

proc arm_linear_interp_f32*(S: ptr LinearInterpolateInstanceF32, x: float32_t): float32_t {.importc, header: "arm_math.h".}

proc linearInterp*(S: var LinearInterpolateInstanceF32, x: float32): float32 {.inline.} =
  ## Perform linear interpolation for a given value x.
  arm_linear_interp_f32(addr S, x.float32_t).float32

# ============================================================================
# Bilinear Interpolation
# ============================================================================

type
  BilinearInterpolateInstanceF32* {.importcpp: "arm_bilinear_interp_instance_f32", header: "arm_math.h".} = object
    numRows*: uint16
    numCols*: uint16
    pData*: ptr float32_t

proc arm_bilinear_interp_f32*(S: ptr BilinearInterpolateInstanceF32, X: float32_t, Y: float32_t): float32_t {.importc, header: "arm_math.h".}

proc bilinearInterp*(S: var BilinearInterpolateInstanceF32, x, y: float32): float32 {.inline.} =
  ## Perform bilinear interpolation for given values x, y.
  arm_bilinear_interp_f32(addr S, x.float32_t, y.float32_t).float32
