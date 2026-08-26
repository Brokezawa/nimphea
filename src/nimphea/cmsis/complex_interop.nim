## Complex interop layer — std/complex views over CMSIS-DSP buffers
##
## This module bridges the Nim standard library's `Complex[float32]` type to
## the interleaved `float32[2]` buffers used by the CMSIS-DSP `arm_cmplx_*`
## functions (and by `Cfft`/`RfftFast` in dsp_transforms).
##
## **Type layer = std/complex.** The scalar operations (`+`, `*`, `abs`,
## `sqrt`, ...) come from the standard library: they compile to inline FMA/
## VSQRT sequences with no function-call overhead or allocations, and there
## is nothing to re-implement. A manually-written complex type would be
## byte-identical (8 bytes, two floats) and buy nothing.
##
## **Bulk layer = CMSIS.** The functions here route whole-buffer operations
## (magnitude, multiply, ...) through the `arm_cmplx_*` functions. Per-scalar
## arithmetic deliberately stays on std/complex — routing single samples
## through CMSIS would only add call overhead.
##
## **Measured costs (Daisy Seed, gcc 10.3.1, opt:size):**
##
## - Referencing std/complex math costs ≈ 2.3 KB of flash over equivalent
##   raw-float code (dominated by dispatch and the referenced math paths;
##   the type itself is free). The ≈ 11 KB dev-mode "checks" tax of indexed
##   DSP loops is separate and comes from runtime index checks — use
##   `-d:danger` (or `-d:release` + explicit checks) to remove it.
## - Trigonometry: libm `cosf` ≈ 444 B vs the CMSIS `sinTable_f32` ≈ 2 KB
##   table; a table is faster, libm is smaller — pick per workload.
## - `$` formatting of complex values pulls float-formatting machinery only
##   when it is actually used.
## - `sqrtf` stays an out-of-line libm call at `opt:size` (≈ 68 B); bulk
##   square roots can use `arm_sqrt_f32` (`vsqrt` hardware instruction)
##   where the lookup-free speed matters. No `-ffast-math` is applied by
##   nimphea.
##
## The layout below is pinned by a compile-time assert: if `Complex[float32]`
## ever diverged from the CMSIS interleaved representation, this module stops
## compiling instead of silently mis-reading buffers.

import std/complex
import nimphea/cmsis/cmsis_types
import nimphea/cmsis/dsp_complex

export complex
export Complex

type
  ComplexF32* = Complex[float32]

static:
  doAssert sizeof(ComplexF32) == 8, "Complex[float32] must match CMSIS interleaved float32[2]"
  doAssert alignof(ComplexF32) == 4, "Complex[float32] must be 4-byte aligned"

{.push raises: [].}

proc complexView*(buf: ptr float32, n: int): ptr UncheckedArray[ComplexF32] {.inline.} =
  ## View `n` interleaved complex samples starting at `buf` as
  ## `Complex[float32]` — zero-copy, layout asserted at compile time.
  cast[ptr UncheckedArray[ComplexF32]](buf)

proc complexView*[N: static int](buf: var array[2 * N, float32]): ptr UncheckedArray[ComplexF32] {.inline.} =
  ## View a `array[2*N, float32]` FFT buffer as `N` complex samples.
  cast[ptr UncheckedArray[ComplexF32]](addr buf[0])

proc floatView*(samples: ptr UncheckedArray[ComplexF32], n: int): ptr float32 {.inline.} =
  ## View `n` complex samples back as interleaved floats (inverse of `complexView`).
  cast[ptr float32](samples)

proc mag*(src: ptr ComplexF32, dst: ptr float32, n: int) {.inline.} =
  ## Bulk magnitude of `n` complex samples (`arm_cmplx_mag_f32`).
  ## Zero samples produce no writes.
  if n > 0:
    arm_cmplx_mag_f32(cast[ptr float32_t](src), cast[ptr float32_t](dst), n.uint32)

proc magSquared*(src: ptr ComplexF32, dst: ptr float32, n: int) {.inline.} =
  ## Bulk magnitude-squared of `n` complex samples (`arm_cmplx_mag_squared_f32`).
  ## Zero samples produce no writes.
  if n > 0:
    arm_cmplx_mag_squared_f32(cast[ptr float32_t](src), cast[ptr float32_t](dst), n.uint32)

proc mult*(srcA, srcB, dst: ptr ComplexF32, n: int) {.inline.} =
  ## Bulk complex-by-complex multiply (`arm_cmplx_mult_cmplx_f32`).
  ## Zero samples produce no writes.
  if n > 0:
    arm_cmplx_mult_cmplx_f32(cast[ptr float32_t](srcA), cast[ptr float32_t](srcB),
                             cast[ptr float32_t](dst), n.uint32)

proc multReal*(src: ptr ComplexF32, real: ptr float32, dst: ptr ComplexF32, n: int) {.inline.} =
  ## Bulk complex-by-real multiply (`arm_cmplx_mult_real_f32`).
  ## Zero samples produce no writes.
  if n > 0:
    arm_cmplx_mult_real_f32(cast[ptr float32_t](src), cast[ptr float32_t](real),
                            cast[ptr float32_t](dst), n.uint32)


proc mag*(src: ptr UncheckedArray[ComplexF32], dst: ptr float32, n: int) {.inline.} =
  ## Bulk magnitude over a `complexView` result (see `mag`).
  if n > 0:
    arm_cmplx_mag_f32(cast[ptr float32_t](src), cast[ptr float32_t](dst), n.uint32)

proc magSquared*(src: ptr UncheckedArray[ComplexF32], dst: ptr float32, n: int) {.inline.} =
  ## Bulk magnitude-squared over a `complexView` result (see `magSquared`).
  if n > 0:
    arm_cmplx_mag_squared_f32(cast[ptr float32_t](src), cast[ptr float32_t](dst), n.uint32)

proc mult*(srcA, srcB: ptr UncheckedArray[ComplexF32], dst: ptr ComplexF32, n: int) {.inline.} =
  ## Bulk multiply over `complexView` results (see `mult`).
  if n > 0:
    arm_cmplx_mult_cmplx_f32(cast[ptr float32_t](srcA), cast[ptr float32_t](srcB),
                             cast[ptr float32_t](dst), n.uint32)

proc multReal*(src: ptr UncheckedArray[ComplexF32], real: ptr float32,
               dst: ptr ComplexF32, n: int) {.inline.} =
  ## Bulk complex-by-real multiply over `complexView` results (see `multReal`).
  if n > 0:
    arm_cmplx_mult_real_f32(cast[ptr float32_t](src), cast[ptr float32_t](real),
                            cast[ptr float32_t](dst), n.uint32)

{.pop.} # raises