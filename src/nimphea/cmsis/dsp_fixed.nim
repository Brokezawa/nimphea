## CMSIS-DSP Fixed-Point Math Functions
##
## This module provides optimized operations for Q31, Q15, and Q7 fixed-point types.

import cmsis_types, cmsis_core

useCmsisModules(dsp_basic, dsp_support)

# ============================================================================
# Q31 Operations
# ============================================================================

proc arm_add_q31*(pSrcA, pSrcB, pDst: ptr q31_t, blockSize: uint32) {.importc, header: "arm_math.h".}
proc arm_sub_q31*(pSrcA, pSrcB, pDst: ptr q31_t, blockSize: uint32) {.importc, header: "arm_math.h".}
proc arm_mult_q31*(pSrcA, pSrcB, pDst: ptr q31_t, blockSize: uint32) {.importc, header: "arm_math.h".}

proc add*(dst: var openArray[q31_t], a, b: openArray[q31_t]) {.inline.} =
  let n = min([dst.len, a.len, b.len])
  if n > 0: arm_add_q31(addr a[0], addr b[0], addr dst[0], n.uint32)

proc sub*(dst: var openArray[q31_t], a, b: openArray[q31_t]) {.inline.} =
  let n = min([dst.len, a.len, b.len])
  if n > 0: arm_sub_q31(addr a[0], addr b[0], addr dst[0], n.uint32)

proc mult*(dst: var openArray[q31_t], a, b: openArray[q31_t]) {.inline.} =
  let n = min([dst.len, a.len, b.len])
  if n > 0: arm_mult_q31(addr a[0], addr b[0], addr dst[0], n.uint32)

# ============================================================================
# Q15 Operations
# ============================================================================

proc arm_add_q15*(pSrcA, pSrcB, pDst: ptr q15_t, blockSize: uint32) {.importc, header: "arm_math.h".}
proc arm_sub_q15*(pSrcA, pSrcB, pDst: ptr q15_t, blockSize: uint32) {.importc, header: "arm_math.h".}
proc arm_mult_q15*(pSrcA, pSrcB, pDst: ptr q15_t, blockSize: uint32) {.importc, header: "arm_math.h".}

proc add*(dst: var openArray[q15_t], a, b: openArray[q15_t]) {.inline.} =
  let n = min([dst.len, a.len, b.len])
  if n > 0: arm_add_q15(addr a[0], addr b[0], addr dst[0], n.uint32)

proc sub*(dst: var openArray[q15_t], a, b: openArray[q15_t]) {.inline.} =
  let n = min([dst.len, a.len, b.len])
  if n > 0: arm_sub_q15(addr a[0], addr b[0], addr dst[0], n.uint32)

proc mult*(dst: var openArray[q15_t], a, b: openArray[q15_t]) {.inline.} =
  let n = min([dst.len, a.len, b.len])
  if n > 0: arm_mult_q15(addr a[0], addr b[0], addr dst[0], n.uint32)

# ============================================================================
# Saturation Helpers
# ============================================================================

proc arm_clip_q31*(pSrc: ptr q31_t, pDst: ptr q31_t, low, high: q31_t, numSamples: uint32) {.importc, header: "arm_math.h".}
proc arm_clip_q15*(pSrc: ptr q15_t, pDst: ptr q15_t, low, high: q15_t, numSamples: uint32) {.importc, header: "arm_math.h".}

proc clip*(dst: var openArray[q31_t], src: openArray[q31_t], low, high: q31_t) {.inline.} =
  let n = min(dst.len, src.len)
  if n > 0: arm_clip_q31(addr src[0], addr dst[0], low, high, n.uint32)

proc clip*(dst: var openArray[q15_t], src: openArray[q15_t], low, high: q15_t) {.inline.} =
  let n = min(dst.len, src.len)
  if n > 0: arm_clip_q15(addr src[0], addr dst[0], low, high, n.uint32)
