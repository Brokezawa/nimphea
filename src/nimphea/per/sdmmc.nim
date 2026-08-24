## SD Card (SDIO/SDMMC) support for libDaisy Nim wrapper
##
## This module provides SD card access via SDMMC peripheral with FatFS filesystem.
## It enables reading and writing files on SD cards connected to the Daisy Seed.
##
## Basic Usage:
## ```nim
## import nimphea
## import nimphea/per/sdmmc
## 
## var hw = newDaisySeed()
## var sd = newSdmmcHandler()
## var fatfs = newFatFSInterface()
## 
## proc main() =
##   hw.init()
##   
##   # Configure SDMMC
##   var sdConfig = newSdmmcConfig()
##   sdConfig.speed = SD_FAST
##   sdConfig.width = SD_BITS_4
##   
##   # Initialize SD card
##   if sd.init(sdConfig) != SD_OK:
##     return
##   
##   # Mount filesystem
##   if fatfs.init(MEDIA_SD) != FATFS_OK:
##     return
##   
##   # Now you can use FatFS functions
##   var file: FIL
##   if f_open(addr file, "test.txt", FA_READ) == FR_OK:
##     # Read file...
##     discard f_close(addr file)
##   
##   while true:
##     hw.delay(100)
## ```
##
## Pin Configuration (Fixed):
## - PC12: SDMMC1 Clock
## - PD2:  SDMMC1 Command
## - PC8:  SDMMC1 D0 (always required)
## - PC9:  SDMMC1 D1 (4-bit mode only)
## - PC10: SDMMC1 D2 (4-bit mode only)
## - PC11: SDMMC1 D3 (4-bit mode only)

# Import libdaisy which provides the macro system
import nimphea
export nimphea_core_types
# FatFS types and C API are canonical in sys/fatfs
import nimphea/sys/fatfs
export fatfs

# Use the macro system for this module's compilation unit
useNimpheaModules(sdmmc, fatfs)

{.push header: "daisy_seed.h".}
{.push importcpp.}

type
  # SDMMC Handler types
  SdmmcResult* {.importcpp: "daisy::SdmmcHandler::Result", size: sizeof(cint).} = enum
    SD_OK = 0
    SD_ERROR

  SdmmcBusWidth* {.importcpp: "daisy::SdmmcHandler::BusWidth", size: sizeof(cint).} = enum
    SD_BITS_1 = 0  ## 1-bit mode (only D0 used)
    SD_BITS_4      ## 4-bit mode (D0-D3 used, faster)

  SdmmcSpeed* {.importcpp: "daisy::SdmmcHandler::Speed", size: sizeof(cint).} = enum
    SD_SLOW = 0         ## 400kHz - initialization speed
    SD_MEDIUM_SLOW      ## 12.5MHz - half of standard
    SD_STANDARD         ## 25MHz - default speed
    SD_FAST             ## 50MHz - high speed
    SD_VERY_FAST        ## 100MHz - overclocked (SDR50)

  SdmmcConfig* {.importcpp: "daisy::SdmmcHandler::Config", bycopy.} = object
    speed* {.importc: "speed".}: SdmmcSpeed
    width* {.importc: "width".}: SdmmcBusWidth
    clock_powersave* {.importc: "clock_powersave".}: bool

  # SdmmcHandler is defined in nimphea_core_types.

{.pop.} # importcpp
{.pop.} # header

# Bind-once low-level interface for SdmmcHandler.
# FatFSInterface methods and the FatFS C API are canonical in sys/fatfs.
proc init*(sdmmc: var SdmmcHandler, cfg: SdmmcConfig): SdmmcResult
  {.importcpp: "#.Init(@)", header: "daisy_seed.h".}
  ## Initialize SDMMC handler with configuration

# Nim-friendly constructors
proc newSdmmcHandler*(): SdmmcHandler {.importcpp: "daisy::SdmmcHandler()", constructor, header: "daisy_seed.h".}

proc newSdmmcConfig*(): SdmmcConfig =
  ## Creates a new SDMMC configuration with default values
  result.speed = SD_FAST
  result.width = SD_BITS_4
  result.clock_powersave = false

# =============================================================================
# High-Level Nim-Friendly API
# =============================================================================

# FatFSInterface wrappers and the FatFS C API are exported from sys/fatfs.

# Higher-level convenience functions

proc readFile*(path: cstring, buffer: var openArray[uint8], 
               bytesRead: var int): FRESULT =
  ## Read file into provided buffer (safe for embedded)
  ## Returns number of bytes actually read in bytesRead parameter
  var file: FIL
  result = f_open(addr file, path, FA_READ)
  
  if result != FR_OK:
    bytesRead = 0
    return
  
  let fileSize = f_size(addr file)
  let toRead = min(fileSize, FSIZE_t(buffer.len))
  
  var br: UINT = 0
  result = f_read(addr file, addr buffer[0], UINT(toRead), addr br)
  bytesRead = int(br)
  
  discard f_close(addr file)
  
  if br != toRead:
    result = FR_DISK_ERR

proc writeFile*(path: cstring, data: openArray[uint8]): FRESULT =
  ## Write data to file (creates or overwrites)
  var file: FIL
  result = f_open(addr file, path, FA_WRITE or FA_CREATE_ALWAYS)
  
  if result != FR_OK:
    return
  
  var bytesWritten: UINT = 0
  result = f_write(addr file, addr data[0], UINT(len(data)), addr bytesWritten)
  
  discard f_sync(addr file)
  discard f_close(addr file)
  
  if bytesWritten != UINT(len(data)):
    result = FR_DISK_ERR

proc appendFile*(path: cstring, data: openArray[uint8]): FRESULT =
  ## Append data to file (creates if doesn't exist)
  var file: FIL
  result = f_open(addr file, path, FA_WRITE or FA_OPEN_APPEND)
  
  if result != FR_OK:
    return
  
  var bytesWritten: UINT = 0
  result = f_write(addr file, addr data[0], UINT(len(data)), addr bytesWritten)
  
  discard f_sync(addr file)
  discard f_close(addr file)

proc fileExists*(path: cstring): bool =
  ## Check if file exists
  var info: FILINFO
  result = f_stat(path, addr info) == FR_OK

proc getFileSize*(path: cstring): int =
  ## Get file size in bytes, returns -1 on error
  var info: FILINFO
  if f_stat(path, addr info) == FR_OK:
    result = int(info.fsize)
  else:
    result = -1

proc listDirectory*(path: cstring, filenames: var openArray[array[256, char]], 
                    maxFiles: int): tuple[result: FRESULT, count: int] =
  ## List files in directory into provided buffer
  ## filenames: buffer for storing filenames (each up to 256 chars)
  ## maxFiles: maximum number of files to read (should be <= filenames.len)
  ## Returns: result code and number of files found
  var dir: DIR
  result.result = f_opendir(addr dir, path)
  result.count = 0
  
  if result.result != FR_OK:
    return
  
  let limit = min(maxFiles, filenames.len)
  
  while result.count < limit:
    var info: FILINFO
    let res = f_readdir(addr dir, addr info)
    
    if res != FR_OK or info.fname[0] == '\0':
      break
    
    # Copy filename to buffer
    var i = 0
    while i < 255 and info.fname[i] != '\0':
      filenames[result.count][i] = info.fname[i]
      inc i
    filenames[result.count][i] = '\0'
    inc result.count
  
  discard f_closedir(addr dir)

when isMainModule:
  echo "libDaisy SD Card (SDMMC) wrapper"
  echo "Supports SD card access via SDMMC with FatFS"
