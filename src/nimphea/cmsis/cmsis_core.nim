## CMSIS Core Macro System
##
## This module provides the infrastructure for including CMSIS-DSP headers
## and setting up the C++ environment.
##
# ============================================================================
# C++ Header Includes for CMSIS
# ============================================================================

proc getCmsisHeaders*(moduleName: string): string =
  ## Returns the C++ header includes needed for a specific CMSIS module
  ## (kept for documentation/tooling; the bindings carry `header:` pragmas)
  case moduleName
  of "dsp_basic": "#include \"dsp/basic_math_functions.h\"\n"
  of "dsp_filtering": "#include \"dsp/filtering_functions.h\"\n"
  of "dsp_transforms": "#include \"dsp/transform_functions.h\"\n"
  of "dsp_statistics": "#include \"dsp/statistics_functions.h\"\n"
  of "dsp_fastmath": "#include \"dsp/fast_math_functions.h\"\n"
  of "dsp_support": "#include \"dsp/support_functions.h\"\n"
  of "dsp_complex": "#include \"dsp/complex_math_functions.h\"\n"
  of "dsp_matrix": "#include \"dsp/matrix_functions.h\"\n"
  of "dsp_controller": "#include \"dsp/controller_functions.h\"\n"
  of "dsp_interpolation": "#include \"dsp/interpolation_functions.h\"\n"
  else: ""
