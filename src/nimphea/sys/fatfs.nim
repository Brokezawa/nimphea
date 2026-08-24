## FatFS support for libDaisy Nim wrapper
##
## This module provides FatFS filesystem support for SD cards and USB storage
## on the Daisy Audio Platform.
##
## **Important**: The relevant hardware peripheral (SD card or USB) must be
## initialized separately before using FatFS. This module only handles the
## FatFS layer that sits on top of the hardware.
##
## Example - SD Card filesystem access:
## ```nim
## import nimphea, sys/fatfs
## 
## var daisy = initDaisy()
## var sd: SdmmcHandler
## var sdConfig = newSdmmcConfig()
## 
## # Initialize SD card hardware
## let sdResult = sd.init(sdConfig)
## if sdResult != SDMMC_OK:
##   # Handle SD card error
##   discard
## 
## # Initialize FatFS on SD card
## var fatfs: FatFSInterface
## let fsResult = fatfs.init(MEDIA_SD)
## if fsResult != FATFS_OK:
##   # Handle FatFS error
##   discard
## 
## # Now you can use standard FatFS API
## # Mount filesystem
## var fs: FATFS
## let mountResult = f_mount(fs.addr, fatfs.getSDPath(), 1)
## 
## # Open and read a file
## var file: FIL
## if f_open(file.addr, "0:/test.txt", FA_READ) == FR_OK:
##   var buffer: array[128, char]
##   var bytesRead: UINT
##   discard f_read(file.addr, buffer[0].addr, 128, bytesRead.addr)
##   discard f_close(file.addr)
## 
## # Unmount when done
## discard f_mount(nil, fatfs.getSDPath(), 0)
## ```
##
## Example - Multiple volumes (SD + USB):
## ```nim
## import nimphea, sys/fatfs
## 
## var fatfs: FatFSInterface
## 
## # Mount both SD and USB (requires _VOLUMES=2 in ffconf.h)
## let result = fatfs.init(MEDIA_SD or MEDIA_USB)
## 
## # SD card will be at "0:/"
## # USB will be at "1:/"
## 
## # Access SD card
## var sdFile: FIL
## discard f_open(sdFile.addr, "0:/file.txt", FA_READ)
## 
## # Access USB drive
## var usbFile: FIL
## discard f_open(usbFile.addr, "1:/file.txt", FA_READ)
## ```

import nimphea
export nimphea_core_types

# Use the macro system for this module's compilation unit
useNimpheaModules(fatfs)

{.push header: "sys/fatfs.h".}

type
  FatFSInterface* {.importcpp: "daisy::FatFSInterface", bycopy.} = object
  
  FatFSConfig* {.importcpp: "daisy::FatFSInterface::Config", bycopy.} = object
    media* {.importcpp: "media".}: uint8
  
  FatFSMedia* {.importcpp: "daisy::FatFSInterface::Config::Media", size: sizeof(uint8).} = enum
    MEDIA_SD = 0x01
    MEDIA_USB = 0x02
  
  FatFSResult* {.importcpp: "daisy::FatFSInterface::Result", size: sizeof(cint).} = enum
    FATFS_OK = 0
    FATFS_ERR_TOO_MANY_VOLUMES
    FATFS_ERR_NO_MEDIA_SELECTED
    FATFS_ERR_GENERIC

# FatFS C types (from ff.h) - single source of truth for the whole library
{.push header: "ff.h".}

type
  FRESULT* {.importc: "FRESULT", size: sizeof(cint).} = enum
    FR_OK = 0                ## Succeeded
    FR_DISK_ERR              ## A hard error occurred in the low level disk I/O layer
    FR_INT_ERR               ## Assertion failed
    FR_NOT_READY             ## The physical drive cannot work
    FR_NO_FILE               ## Could not find the file
    FR_NO_PATH               ## Could not find the path
    FR_INVALID_NAME          ## The path name format is invalid
    FR_DENIED                ## Access denied due to prohibited access or directory full
    FR_EXIST                 ## Access denied due to prohibited access
    FR_INVALID_OBJECT        ## The file/directory object is invalid
    FR_WRITE_PROTECTED       ## The physical drive is write protected
    FR_INVALID_DRIVE         ## The logical drive number is invalid
    FR_NOT_ENABLED           ## The volume has no work area
    FR_NO_FILESYSTEM         ## There is no valid FAT volume
    FR_MKFS_ABORTED          ## The f_mkfs() aborted due to any problem
    FR_TIMEOUT               ## Could not get a grant to access the volume within defined period
    FR_LOCKED                ## The operation is rejected according to the file sharing policy
    FR_NOT_ENOUGH_CORE       ## LFN working buffer could not be allocated
    FR_TOO_MANY_OPEN_FILES   ## Number of open files > FF_FS_LOCK
    FR_INVALID_PARAMETER     ## Given parameter is invalid

  # File object
  FIL* {.importc: "FIL", bycopy.} = object

  # Directory object
  DIR* {.importc: "DIR", bycopy.} = object

  # File information
  FILINFO* {.importc: "FILINFO", bycopy.} = object
    fsize* {.importc: "fsize".}: uint32     ## File size
    fdate* {.importc: "fdate".}: uint16     ## Modified date
    ftime* {.importc: "ftime".}: uint16     ## Modified time
    fattrib* {.importc: "fattrib".}: uint8  ## File attributes
    fname* {.importc: "fname".}: array[256, char]  ## File name

  # Filesystem object
  FATFS* {.importc: "FATFS", bycopy.} = object

  # FatFS scalar aliases
  FSIZE_t* = uint32
  UINT* = cuint
  BYTE* = uint8
  DWORD* = culong

# File access mode flags
const
  FA_READ* = 0x01'u8           ## Read access
  FA_WRITE* = 0x02'u8          ## Write access
  FA_OPEN_EXISTING* = 0x00'u8  ## Open existing file
  FA_CREATE_NEW* = 0x04'u8     ## Create new file
  FA_CREATE_ALWAYS* = 0x08'u8  ## Create new file, overwrite existing
  FA_OPEN_ALWAYS* = 0x10'u8    ## Open existing or create new
  FA_OPEN_APPEND* = 0x30'u8    ## Open existing and seek to end

# FatFS C API (from ff.h)
proc f_mount*(fs: ptr FATFS, path: cstring, opt: BYTE): FRESULT {.importc: "f_mount".}
proc f_open*(fp: ptr FIL, path: cstring, mode: uint8): FRESULT {.importc: "f_open".}
proc f_close*(fp: ptr FIL): FRESULT {.importc: "f_close".}
proc f_read*(fp: ptr FIL, buff: pointer, btr: UINT, br: ptr UINT): FRESULT {.importc: "f_read".}
proc f_write*(fp: ptr FIL, buff: pointer, btw: UINT, bw: ptr UINT): FRESULT {.importc: "f_write".}
proc f_lseek*(fp: ptr FIL, ofs: FSIZE_t): FRESULT {.importc: "f_lseek".}
proc f_sync*(fp: ptr FIL): FRESULT {.importc: "f_sync".}
proc f_tell*(fp: ptr FIL): FSIZE_t {.importc: "f_tell".}
proc f_size*(fp: ptr FIL): FSIZE_t {.importc: "f_size".}
proc f_eof*(fp: ptr FIL): cint {.importc: "f_eof".}
proc f_opendir*(dp: ptr DIR, path: cstring): FRESULT {.importc: "f_opendir".}
proc f_closedir*(dp: ptr DIR): FRESULT {.importc: "f_closedir".}
proc f_readdir*(dp: ptr DIR, fno: ptr FILINFO): FRESULT {.importc: "f_readdir".}
proc f_mkdir*(path: cstring): FRESULT {.importc: "f_mkdir".}
proc f_unlink*(path: cstring): FRESULT {.importc: "f_unlink".}
proc f_rename*(oldname: cstring, newname: cstring): FRESULT {.importc: "f_rename".}
proc f_stat*(path: cstring, fno: ptr FILINFO): FRESULT {.importc: "f_stat".}
proc f_chmod*(path: cstring, attr: BYTE, mask: BYTE): FRESULT {.importc: "f_chmod".}
proc f_getfree*(path: cstring, nclst: ptr DWORD, fatfs: ptr ptr FATFS): FRESULT {.importc: "f_getfree".}
proc f_unmount*(path: cstring): FRESULT {.importc: "f_unmount".}

{.pop.} # header

# FatFSInterface (bind-once) - low-level C++ interface
proc init*(fatfs: var FatFSInterface, config: FatFSConfig): FatFSResult {.importcpp: "#.Init(@)", header: "sys/fatfs.h".}
proc init*(fatfs: var FatFSInterface, media: uint8): FatFSResult {.importcpp: "#.Init(@)", header: "sys/fatfs.h".}
proc deinit*(fatfs: var FatFSInterface): FatFSResult {.importcpp: "#.DeInit()", header: "sys/fatfs.h".}
proc isInitialized*(fatfs: FatFSInterface): bool {.importcpp: "#.Initialized()", header: "sys/fatfs.h".}
proc getConfig*(fatfs: FatFSInterface): FatFSConfig {.importcpp: "#.GetConfig()", header: "sys/fatfs.h".}
proc getSDPath*(fatfs: FatFSInterface): cstring {.importcpp: "#.GetSDPath()", header: "sys/fatfs.h".}
proc getUSBPath*(fatfs: FatFSInterface): cstring {.importcpp: "#.GetUSBPath()", header: "sys/fatfs.h".}
proc getSDFileSystem*(fatfs: var FatFSInterface): var FATFS {.importcpp: "#.GetSDFileSystem()", header: "sys/fatfs.h".}
proc getUSBFileSystem*(fatfs: var FatFSInterface): var FATFS {.importcpp: "#.GetUSBFileSystem()", header: "sys/fatfs.h".}

# Constructors
proc newFatFSConfig*(): FatFSConfig {.importcpp: "daisy::FatFSInterface::Config()", constructor.}
proc newFatFSInterface*(): FatFSInterface {.importcpp: "daisy::FatFSInterface()", constructor, header: "sys/fatfs.h".}

{.pop.} # header

# =============================================================================
# Helper Procedures
# =============================================================================

proc mount*(fatfs: var FatFSInterface, media: FatFSMedia): FRESULT =
  ## Mount a filesystem on the specified media.
  ##
  ## This is a convenience wrapper around f_mount.
  ##
  ## Parameters:
  ##   fatfs: Initialized FatFS interface
  ##   media: Media to mount (MEDIA_SD or MEDIA_USB)
  ##
  ## Returns:
  ##   FR_OK on success, FatFS error code on failure
  ##
  ## Example:
  ## ```nim
  ## var fatfs: FatFSInterface
  ## discard fatfs.init(MEDIA_SD)
  ## let result = fatfs.mount(MEDIA_SD)
  ## ```
  case media
  of MEDIA_SD:
    result = f_mount(fatfs.getSDFileSystem().addr, fatfs.getSDPath(), 1)
  of MEDIA_USB:
    result = f_mount(fatfs.getUSBFileSystem().addr, fatfs.getUSBPath(), 1)

proc unmount*(fatfs: FatFSInterface, media: FatFSMedia): FRESULT =
  ## Unmount a filesystem from the specified media.
  ##
  ## Note: FatFS unmounts by calling f_mount with NULL filesystem pointer.
  ##
  ## Parameters:
  ##   fatfs: Initialized FatFS interface
  ##   media: Media to unmount (MEDIA_SD or MEDIA_USB)
  ##
  ## Returns:
  ##   FR_OK on success, FatFS error code on failure
  case media
  of MEDIA_SD:
    result = f_mount(nil, fatfs.getSDPath(), 0)
  of MEDIA_USB:
    result = f_mount(nil, fatfs.getUSBPath(), 0)

when isMainModule:
  echo "libDaisy FatFS wrapper - Filesystem support for SD card and USB"
