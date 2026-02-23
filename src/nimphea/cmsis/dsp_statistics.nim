## CMSIS-DSP Statistics Functions
##
## This module provides optimized reduction operations on vectors.
## All functions return scalar values and use zero heap allocation.

import cmsis_types, cmsis_core

useCmsisModules(dsp_statistics)

# ============================================================================
# Maximum and Minimum
# ============================================================================

proc arm_max_f32*(pSrc: ptr float32_t, blockSize: uint32, pResult: ptr float32_t, pIndex: ptr uint32) {.importc, header: "arm_math.h".}
proc arm_min_f32*(pSrc: ptr float32_t, blockSize: uint32, pResult: ptr float32_t, pIndex: ptr uint32) {.importc, header: "arm_math.h".}

proc max*(data: openArray[float32]): tuple[value: float32, index: int] =
  ## Find maximum value and its index in a vector
  if data.len == 0: return (0.0, -1)
  var idx: uint32
  var res: float32_t
  arm_max_f32(addr data[0], data.len.uint32, addr res, addr idx)
  result = (res.float32, idx.int)

proc min*(data: openArray[float32]): tuple[value: float32, index: int] =
  ## Find minimum value and its index in a vector
  if data.len == 0: return (0.0, -1)
  var idx: uint32
  var res: float32_t
  arm_min_f32(addr data[0], data.len.uint32, addr res, addr idx)
  result = (res.float32, idx.int)

# ============================================================================
# Mean and Power
# ============================================================================

proc arm_mean_f32*(pSrc: ptr float32_t, blockSize: uint32, pResult: ptr float32_t) {.importc, header: "arm_math.h".}
proc arm_power_f32*(pSrc: ptr float32_t, blockSize: uint32, pResult: ptr float32_t) {.importc, header: "arm_math.h".}

proc mean*(data: openArray[float32]): float32 =
  ## Calculate arithmetic mean of a vector
  if data.len == 0: return 0.0
  var res: float32_t
  arm_mean_f32(addr data[0], data.len.uint32, addr res)
  return res.float32

proc power*(data: openArray[float32]): float32 =
  ## Calculate sum of squares (signal power) of a vector
  if data.len == 0: return 0.0
  var res: float32_t
  arm_power_f32(addr data[0], data.len.uint32, addr res)
  return res.float32

# ============================================================================
# RMS and Variance
# ============================================================================

proc arm_rms_f32*(pSrc: ptr float32_t, blockSize: uint32, pResult: ptr float32_t) {.importc, header: "arm_math.h".}
proc arm_var_f32*(pSrc: ptr float32_t, blockSize: uint32, pResult: ptr float32_t) {.importc, header: "arm_math.h".}
proc arm_std_f32*(pSrc: ptr float32_t, blockSize: uint32, pResult: ptr float32_t) {.importc, header: "arm_math.h".}

proc rms*(data: openArray[float32]): float32 =
  ## Calculate Root Mean Square of a vector
  if data.len == 0: return 0.0
  var res: float32_t
  arm_rms_f32(addr data[0], data.len.uint32, addr res)
  return res.float32

proc variance*(data: openArray[float32]): float32 =
  ## Calculate variance of a vector
  if data.len == 0: return 0.0
  var res: float32_t
  arm_var_f32(addr data[0], data.len.uint32, addr res)
  return res.float32

proc std*(data: openArray[float32]): float32 =
  ## Calculate standard deviation of a vector
  if data.len == 0: return 0.0
  var res: float32_t
  arm_std_f32(addr data[0], data.len.uint32, addr res)
  return res.float32
