## CMSIS-DSP Support Functions
##
## This module provides optimized memory operations and type conversions.
## All operations are in-place or write to user-provided buffers.

import cmsis_types, cmsis_core

useCmsisModules(dsp_support)

# ============================================================================
## Memory Operations
# ============================================================================

proc arm_copy_f32*(pSrc: ptr float32_t, pDst: ptr float32_t, blockSize: uint32) {.importc, header: "arm_math.h".}
proc arm_fill_f32*(value: float32_t, pDst: ptr float32_t, blockSize: uint32) {.importc, header: "arm_math.h".}

proc copy*(dst: var openArray[float32], src: openArray[float32]) {.inline.} =
  ## Optimized vector copy: dst = src
  let n = min(dst.len, src.len)
  if n > 0:
    arm_copy_f32(cast[ptr float32_t](addr src[0]), cast[ptr float32_t](addr dst[0]), n.uint32)

proc fill*(dst: var openArray[float32], value: float32) {.inline.} =
  ## Optimized vector fill: dst[i] = value
  if dst.len > 0:
    arm_fill_f32(value.float32_t, cast[ptr float32_t](addr dst[0]), dst.len.uint32)

# ============================================================================
## Type Conversions
# ============================================================================

proc arm_float_to_q31*(pSrc: ptr float32_t, pDst: ptr q31_t, blockSize: uint32) {.importc, header: "arm_math.h".}
proc arm_float_to_q15*(pSrc: ptr float32_t, pDst: ptr q15_t, blockSize: uint32) {.importc, header: "arm_math.h".}
proc arm_float_to_q7*(pSrc: ptr float32_t, pDst: ptr q7_t, blockSize: uint32) {.importc, header: "arm_math.h".}

proc arm_q31_to_float*(pSrc: ptr q31_t, pDst: ptr float32_t, blockSize: uint32) {.importc, header: "arm_math.h".}
proc arm_q15_to_float*(pSrc: ptr q15_t, pDst: ptr float32_t, blockSize: uint32) {.importc, header: "arm_math.h".}
proc arm_q7_to_float*(pSrc: ptr q7_t, pDst: ptr float32_t, blockSize: uint32) {.importc, header: "arm_math.h".}

proc toQ31*(dst: var openArray[q31_t], src: openArray[float32]) {.inline.} =
  let n = min(dst.len, src.len)
  if n > 0: arm_float_to_q31(cast[ptr float32_t](addr src[0]), cast[ptr q31_t](addr dst[0]), n.uint32)

proc toQ15*(dst: var openArray[q15_t], src: openArray[float32]) {.inline.} =
  let n = min(dst.len, src.len)
  if n > 0: arm_float_to_q15(cast[ptr float32_t](addr src[0]), cast[ptr q15_t](addr dst[0]), n.uint32)

proc toFloat*(dst: var openArray[float32], src: openArray[q31_t]) {.inline.} =
  let n = min(dst.len, src.len)
  if n > 0: arm_q31_to_float(cast[ptr q31_t](addr src[0]), cast[ptr float32_t](addr dst[0]), n.uint32)

proc toFloat*(dst: var openArray[float32], src: openArray[q15_t]) {.inline.} =
  let n = min(dst.len, src.len)
  if n > 0: arm_q15_to_float(cast[ptr q15_t](addr src[0]), cast[ptr float32_t](addr dst[0]), n.uint32)
