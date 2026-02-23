## CMSIS-DSP Controller Functions
##
## This module provides optimized control functions like PID and coordinate transforms.

import cmsis_types, cmsis_core

useCmsisModules(dsp_controller)

# ============================================================================
# PID Control
# ============================================================================

type
  PidInstanceF32* {.importcpp: "arm_pid_instance_f32", header: "arm_math.h".} = object
    A0*: float32_t
    A1*: float32_t
    A2*: float32_t
    state*: array[3, float32_t]
    Kp*: float32_t
    Ki*: float32_t
    Kd*: float32_t

proc arm_pid_init_f32*(S: ptr PidInstanceF32, resetStateFlag: int32) {.importc, header: "arm_math.h".}
proc arm_pid_f32*(S: ptr PidInstanceF32, in_val: float32_t): float32_t {.importc, header: "arm_math.h".}

type
  PidController* = object
    ## A PID controller.
    instance*: PidInstanceF32

proc init*(pid: var PidController, kp, ki, kd: float32) =
  ## Initialize PID controller with gains.
  pid.instance.Kp = kp.float32_t
  pid.instance.Ki = ki.float32_t
  pid.instance.Kd = kd.float32_t
  arm_pid_init_f32(addr pid.instance, 1) # Reset state

proc process*(pid: var PidController, error: float32): float32 {.inline.} =
  ## Process one step of the PID controller.
  arm_pid_f32(addr pid.instance, error.float32_t).float32

# ============================================================================
# Coordinate Transforms
# ============================================================================

proc arm_sin_cos_f32*(theta: float32_t, pSinVal: ptr float32_t, pCosVal: ptr float32_t) {.importc, header: "arm_math.h".}

proc sinCos*(theta: float32): tuple[sinVal, cosVal: float32] {.inline.} =
  ## Simultaneously calculate sine and cosine.
  var s, c: float32_t
  arm_sin_cos_f32(theta.float32_t, addr s, addr c)
  return (s.float32, c.float32)
