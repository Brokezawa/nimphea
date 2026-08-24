## Random Number Generator (RNG)
## ===============================
##
## Hardware True Random Number Generator wrapper for Daisy Seed.
##
## The Daisy Seed's STM32H750 includes a hardware True Random Number Generator (TRNG)
## that uses analog noise to generate cryptographically secure random numbers.
##
## **Features:**
## - Hardware-based true random number generation
## - 32-bit random values
## - Floating-point random values with custom range
## - Non-blocking ready check
##
## **Usage:**
## ```nim
## import nimphea/per/rng
##
## # RNG is automatically initialized by System::Init
## # Generate random values
## let value = randomGetValue()        # 0 to 2^32-1
## let normalized = randomGetFloat()   # 0.0 to 1.0
## let scaled = randomGetFloat(10.0, 20.0)  # 10.0 to 20.0
##
## # Check if ready (non-blocking)
## if randomIsReady():
##   let val = randomGetValue()
## ```
##
## **Note:** The RNG is initialized automatically when you call `hw.init()` on your
## DaisySeed object, so you don't need to manually initialize it.

import nimphea/nimphea_macros

useNimpheaModules(rng)

# Static methods - called on the class itself
proc randomInit*() {.importcpp: "daisy::Random::Init()".}
  ## Initialize the Random Number Generator peripheral.
  ##
  ## **Note:** Called automatically by System::Init (hw.init()), so you
  ## typically don't need to call this manually.
proc randomDeInit*() {.importcpp: "daisy::Random::DeInit()".}
  ## Deinitialize the Random Number Generator peripheral

proc randomGetValue*(): uint32 {.importcpp: "daisy::Random::GetValue()".}
  ## Returns a randomly generated 32-bit number.
  ##
  ## This function polls the peripheral and can block for up to 100ms.
  ## To avoid blocking, use `randomIsReady()` first to check if a value is ready.
  ## Returns 0 if there's an issue with the peripheral or a timeout occurs.
  ##
  ## **Example:**
  ## ```nim
  ## let randomNum = randomGetValue()
  ## echo "Random: ", randomNum
  ## ```
proc randomGetFloat*(min: cfloat = 0.0, max: cfloat = 1.0): cfloat {.importcpp: "daisy::Random::GetFloat(#, #)".}
  ## Returns a random floating point value between min and max.
  ##
  ## Internally calls `randomGetValue()` and scales the result.
  ##
  ## **Example:**
  ## ```nim
  ## let normalized = randomGetFloat()          # 0.0 to 1.0
  ## let pitch = randomGetFloat(-12.0, 12.0)    # -12.0 to +12.0 semitones
  ## let freq = randomGetFloat(20.0, 20000.0)   # Audio frequency range
  ## ```
proc randomIsReady*(): bool {.importcpp: "daisy::Random::IsReady()".}
  ## Check if the RNG peripheral has a new value ready (non-blocking).
  ##
  ## **Example:**
  ## ```nim
  ## if randomIsReady():
  ##   let value = randomGetValue()  # Won't block
  ## ```
