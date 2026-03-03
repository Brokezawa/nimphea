#!/bin/bash

# Script to update all nimphea examples with the new nimble format

EXAMPLES_DIR="/Users/zawa/Projects/nim/nimphea_dev/nimphea/nimphea-examples/examples"
TEMPLATE="$EXAMPLES_DIR/blink/blink.nimble"

# List all examples (excluding blink which is already done)
EXAMPLES=(
  "adc_demo"
  "audio_demo"
  "cmsis_demo"
  "codec_comparison"
  "comm_demo"
  "control_mapping"
  "dac_simple"
  "data_structures"
  "display_gallery"
  "eurorack_basics"
  "fatfs_demo"
  "field_demo"
  "gpio_demo"
  "io_expander_demo"
  "lcd_menu"
  "led_control"
  "led_drivers"
  "legio_demo"
  "looper"
  "menu_dsl_demo"
  "midi_demo"
  "oled_basic"
  "oled_visualizer"
  "panicoverride"
  "patch_demo"
  "patch_sm_demo"
  "peripherals_basic"
  "petal_demo"
  "pod_demo"
  "pwm_demo"
  "sai_demo"
  "sampler"
  "sdram_test"
  "sensor_demo"
  "storage_demo"
  "system_demo"
  "timer_advanced"
  "ui_demo"
  "usb_serial"
  "versio_demo"
  "vu_meter"
  "wav_demo"
  "wavetable_synth"
)

for example in "${EXAMPLES[@]}"; do
  echo "Updating $example..."
  
  nimble_file="$EXAMPLES_DIR/$example/$example.nimble"
  
  # Create the new nimble content by substituting "blink" with the example name
  sed -e "s/blink/$example/g" \
      -e "s/Example: blink/Example: $example/g" \
      "$TEMPLATE" > "$nimble_file"
  
  echo "  ✓ Updated $nimble_file"
done

echo ""
echo "All examples updated!"
