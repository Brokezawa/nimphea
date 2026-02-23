## CMSIS-DSP Fast Math Functions
##
## This module provides optimized approximations of standard math functions.
## These functions are typically 10-100x faster than standard library versions
## on Cortex-M7.

import cmsis_types, cmsis_core

useCmsisModules(dsp_fastmath)

# ============================================================================
# Sine and Cosine
# ============================================================================

proc arm_sin_f32*(x: float32_t): float32_t {.importc, header: "arm_math.h".}
  ## Fast sine approximation for f32

proc arm_cos_f32*(x: float32_t): float32_t {.importc, header: "arm_math.h".}
  ## Fast cosine approximation for f32

proc fastSin*(x: float32): float32 {.inline.} =
  ## Optimized sine approximation (f32)
  arm_sin_f32(x.float32_t).float32

proc fastCos*(x: float32): float32 {.inline.} =
  ## Optimized cosine approximation (f32)
  arm_cos_f32(x.float32_t).float32

# ============================================================================
# Square Root
# ============================================================================

proc arm_sqrt_f32*(input: float32_t, pOut: ptr float32_t): ArmStatus {.importc, header: "arm_math.h".}
  ## Optimized square root for f32

proc fastSqrt*(x: float32): float32 {.inline.} =
  ## Optimized square root (f32). Returns 0.0 for negative inputs.
  var res: float32_t
  if arm_sqrt_f32(x.float32_t, addr res) == ARM_MATH_SUCCESS:
    result = res.float32
  else:
    result = 0.0

# ============================================================================
# Common Fixed-Point Fast Math (Q31, Q15)
# ============================================================================

proc arm_sin_q31*(x: q31_t): q31_t {.importc, header: "arm_math.h".}
proc arm_cos_q31*(x: q31_t): q31_t {.importc, header: "arm_math.h".}

proc arm_sin_q15*(x: q15_t): q15_t {.importc, header: "arm_math.h".}
proc arm_cos_q15*(x: q15_t): q15_t {.importc, header: "arm_math.h".}

proc fastSin*(x: q31_t): q31_t {.inline.} = arm_sin_q31(x)
proc fastCos*(x: q31_t): q31_t {.inline.} = arm_cos_q31(x)

proc fastSin*(x: q15_t): q15_t {.inline.} = arm_sin_q15(x)
proc fastCos*(x: q15_t): q15_t {.inline.} = arm_cos_q15(x)
