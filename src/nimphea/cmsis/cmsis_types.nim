## CMSIS-DSP Type Definitions
##
## This module provides Nim mappings for fundamental CMSIS-DSP types
## and status codes used across the library.

type
  # Fundamental floating point types
  float32_t* = cfloat
  float64_t* = cdouble

  # Q format fixed-point types
  q31_t* = int32
  q15_t* = int16
  q7_t* = int8

  # ARM Math Status Codes
  ArmStatus* {.importcpp: "arm_status", size: sizeof(cint).} = enum
    ARM_MATH_SUCCESS = 0                 ## No error
    ARM_MATH_ARGUMENT_ERROR = 1          ## One or more arguments are incorrect
    ARM_MATH_LENGTH_ERROR = 2            ## Length of data buffer is incorrect
    ARM_MATH_SIZE_MISMATCH = 3           ## Size of matrices is bound to mismatch
    ARM_MATH_NANINF = 4                  ## Not-a-number (NaN) or infinity is generated
    ARM_MATH_SINGULAR = 5                ## Generated matrix is singular and cannot be inverted
    ARM_MATH_TEST_FAILURE = 6            ## Test failed
    ARM_MATH_DECOMPOSITION_FAILURE = 7   ## Matrix decomposition failed

# Buffer types for pointer-based operations
type
  CmsisBufferF32* = ptr UncheckedArray[float32_t]
  CmsisBufferQ31* = ptr UncheckedArray[q31_t]
  CmsisBufferQ15* = ptr UncheckedArray[q15_t]
  CmsisBufferQ7* = ptr UncheckedArray[q7_t]
