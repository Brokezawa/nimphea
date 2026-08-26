## DMA Cache Management
## ====================
##
## Cache coherency helpers for DMA on the STM32H750 (D-cache vs SRAM).
##
## When the CPU writes a buffer, the data may sit in cache and not in SRAM, so
## DMA reading SRAM sees stale data; after a DMA write, the CPU may read stale
## cache. Use:
##
## - `dmaClearCache()` before a DMA transmit (flush CPU writes to SRAM).
## - `dmaInvalidateCache()` after a DMA receive (reload cache from SRAM).
##
## **Note:** The cleanest solution is to place DMA buffers in the D2 memory
## domain (`{.section: ".sram1_bss".}`), which needs no manual cache management.

import nimphea


{.push header: "sys/dma.h".}

proc dsy_dma_init*() {.importc: "dsy_dma_init".}
  ## Initialize the DMA peripheral (low-level).
  ## Called automatically by `System.init()`, so rarely needed.
proc dsy_dma_deinit*() {.importc: "dsy_dma_deinit".}
  ## Deinitialize the DMA peripheral (low-level).
  ## Called automatically by `System.deInit()`, so rarely needed.

proc dsy_dma_clear_cache_for_buffer*(buffer: ptr uint8, size: csize_t) {.
  importc: "dsy_dma_clear_cache_for_buffer".}
  ## Clear (flush) CPU cache to SRAM for a buffer (low-level).
  ## Prefer the type-safe `dmaClearCache` template.
proc dsy_dma_invalidate_cache_for_buffer*(buffer: ptr uint8, size: csize_t) {.
  importc: "dsy_dma_invalidate_cache_for_buffer".}
  ## Invalidate CPU cache for a buffer, reloading from SRAM (low-level).
  ## Prefer the type-safe `dmaInvalidateCache` template.

{.pop.} # header

# ============================================================================
# Type-safe helpers
# ============================================================================

template dmaClearCache*[T](buffer: var openArray[T]) =
  ## Clear (flush) CPU cache to SRAM before a DMA transmit.
  ##
  ## **Example:**
  ## ```nim
  ## var txData: array[256, uint8]
  ## for i in 0..<256: txData[i] = uint8(i)
  ## dmaClearCache(txData)  # Flush before DMA reads
  ## ```
  when buffer.len > 0:
    dsy_dma_clear_cache_for_buffer(
      cast[ptr uint8](buffer[0].addr),
      csize_t(buffer.len * sizeof(T))
    )

template dmaInvalidateCache*[T](buffer: var openArray[T]) =
  ## Invalidate CPU cache after a DMA receive, reloading from SRAM.
  ##
  ## **Example:**
  ## ```nim
  ## var rxData: array[256, uint8]
  ## spi.dmaReceive(rxData.addr, 256)
  ## while spi.isBusy(): discard
  ## dmaInvalidateCache(rxData)  # Reload from SRAM
  ## ```
  when buffer.len > 0:
    dsy_dma_invalidate_cache_for_buffer(
      cast[ptr uint8](buffer[0].addr),
      csize_t(buffer.len * sizeof(T))
    )

proc dmaClearCacheFor*(p: pointer, size: int) =
  ## Clear (flush) the cache for an arbitrary memory region.
  ##
  ## **Example:**
  ## ```nim
  ## type MyStruct = object
  ##   field1: uint32
  ##   field2: array[16, uint8]
  ## var data: MyStruct
  ## dmaClearCacheFor(data.addr, sizeof(MyStruct))
  ## ```
  if size > 0:
    dsy_dma_clear_cache_for_buffer(cast[ptr uint8](p), csize_t(size))

proc dmaInvalidateCacheFor*(p: pointer, size: int) =
  ## Invalidate the cache for an arbitrary memory region.
  ##
  ## **Example:**
  ## ```nim
  ## type MyStruct = object
  ##   field1: uint32
  ##   field2: array[16, uint8]
  ## var data: MyStruct
  ## # After DMA receive
  ## dmaInvalidateCacheFor(data.addr, sizeof(MyStruct))
  ## ```
  if size > 0:
    dsy_dma_invalidate_cache_for_buffer(cast[ptr uint8](p), csize_t(size))

# ============================================================================
# Usage examples (compile-time only, no hardware required)
# ============================================================================

when isMainModule:
  block:
    var txBuffer: array[128, uint8]
    for i in 0..<128:
      txBuffer[i] = uint8(i)
    dmaClearCache(txBuffer)

  block:
    var rxBuffer: array[128, uint8]
    dmaInvalidateCache(rxBuffer)

  block:
    var floatData: array[32, float32]
    var wordData: array[64, uint16]
    dmaClearCache(floatData)
    dmaInvalidateCache(wordData)
