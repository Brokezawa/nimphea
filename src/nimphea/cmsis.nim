## CMSIS-DSP Unified Entry Point
##
## This module re-exports all CMSIS-DSP optimized math functions.
## Usage: import nimphea/cmsis

import nimphea/cmsis/cmsis_types, nimphea/cmsis/dsp_fastmath, nimphea/cmsis/dsp_basic, nimphea/cmsis/dsp_statistics, nimphea/cmsis/dsp_filtering, nimphea/cmsis/dsp_transforms, nimphea/cmsis/dsp_matrix, nimphea/cmsis/dsp_complex, nimphea/cmsis/dsp_support, nimphea/cmsis/dsp_controller, nimphea/cmsis/dsp_fixed, nimphea/cmsis/dsp_interpolation

export cmsis_types, dsp_fastmath, dsp_basic, dsp_statistics, dsp_filtering, dsp_transforms, dsp_matrix, dsp_complex, dsp_support, dsp_controller, dsp_fixed, dsp_interpolation
