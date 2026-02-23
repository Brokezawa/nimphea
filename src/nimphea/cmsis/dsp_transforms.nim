## CMSIS-DSP Transform Functions
##
## This module provides optimized Fast Fourier Transforms (FFT).
## FFT instances are designed to be static-allocated with compile-time 
## known sizes. Zero heap allocation is used.

import cmsis_types, cmsis_core

useCmsisModules(dsp_transforms)

# ============================================================================
# Complex FFT (CFFT)
# ============================================================================

type
  CfftInstanceF32* {.importcpp: "arm_cfft_instance_f32", header: "arm_math.h".} = object
    fftLen*: uint16
    pTwiddle*: ptr float32_t
    pBitRevTable*: ptr uint16
    bitRevLength*: uint16

proc arm_cfft_init_f32*(S: ptr CfftInstanceF32, fftLen: uint16): ArmStatus {.importc, header: "arm_math.h".}
proc arm_cfft_f32*(S: ptr CfftInstanceF32, p1: ptr float32_t, ifftFlag: uint8, bitReverseFlag: uint8) {.importc, header: "arm_math.h".}

type
  FftInstance*[N: static int] = object
    ## A compile-time sized Complex FFT instance.
    ## N must be a power of 2: 16, 32, 64, ..., 4096.
    instance*: CfftInstanceF32

proc init*[N: static int](fft: var FftInstance[N]) =
  ## Initialize FFT instance for size N.
  static: assert (N and (N - 1)) == 0, "FFT size must be a power of 2"
  discard arm_cfft_init_f32(addr fft.instance, N.uint16)

proc forward*[N: static int](fft: var FftInstance[N], data: var openArray[float32]) {.inline.} =
  ## Perform forward FFT in-place.
  ## data must contain 2*N floats (interleaved real and imaginary).
  assert data.len >= 2 * N
  arm_cfft_f32(addr fft.instance, cast[ptr float32_t](addr data[0]), 0, 1)

proc inverse*[N: static int](fft: var FftInstance[N], data: var openArray[float32]) {.inline.} =
  ## Perform inverse FFT in-place.
  ## data must contain 2*N floats (interleaved real and imaginary).
  assert data.len >= 2 * N
  arm_cfft_f32(addr fft.instance, cast[ptr float32_t](addr data[0]), 1, 1)

# ============================================================================
# Real FFT (RFFT) - Fast
# ============================================================================

type
  RfftFastInstanceF32* {.importcpp: "arm_rfft_fast_instance_f32", header: "arm_math.h".} = object
    Sint*: CfftInstanceF32
    fftLenRFFT*: uint16
    pTwiddleRFFT*: ptr float32_t

proc arm_rfft_fast_init_f32*(S: ptr RfftFastInstanceF32, fftLen: uint16): ArmStatus {.importc, header: "arm_math.h".}
proc arm_rfft_fast_f32*(S: ptr RfftFastInstanceF32, pIn: ptr float32_t, pOut: ptr float32_t, ifftFlag: uint8) {.importc, header: "arm_math.h".}

type
  RealFftInstance*[N: static int] = object
    ## A compile-time sized Real FFT instance.
    ## N must be a power of 2: 32, 64, 128, ..., 4096.
    instance*: RfftFastInstanceF32

proc init*[N: static int](fft: var RealFftInstance[N]) =
  ## Initialize Real FFT instance for size N.
  static: assert (N and (N - 1)) == 0, "RFFT size must be a power of 2"
  discard arm_rfft_fast_init_f32(addr fft.instance, N.uint16)

proc forward*[N: static int](fft: var RealFftInstance[N], input: openArray[float32], output: var openArray[float32]) {.inline.} =
  ## Perform forward Real FFT.
  ## input must contain N real samples.
  ## output must contain N floats (complex result in specific format).
  assert input.len >= N
  assert output.len >= N
  arm_rfft_fast_f32(addr fft.instance, cast[ptr float32_t](addr input[0]), cast[ptr float32_t](addr output[0]), 0)

proc inverse*[N: static int](fft: var RealFftInstance[N], input: openArray[float32], output: var openArray[float32]) {.inline.} =
  ## Perform inverse Real FFT.
  ## input contains frequency data (N floats).
  ## output will contain N real samples.
  assert input.len >= N
  assert output.len >= N
  arm_rfft_fast_f32(addr fft.instance, cast[ptr float32_t](addr input[0]), cast[ptr float32_t](addr output[0]), 1)
