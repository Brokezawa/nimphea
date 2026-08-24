## check_duplicate_types - verify no C++-backed type is declared twice across src/
##
## Usage: nim c -r --path:src --path:src/nimphea tools/check_duplicate_types.nim
## Exits nonzero if duplicates are found, so it can gate CI.

import std/[os, strutils, tables, algorithm]
import std/sequtils

proc extractQuoted(line: string, marker: string): string =
  ## Returns the contents of the first adjacent quoted string following marker, or "".
  let i = line.find(marker)
  if i < 0: return ""
  var j = i + marker.len
  if j >= line.len or line[j] != '"': return ""
  inc j
  var name = ""
  while j < line.len and line[j] != '"':
    name.add(line[j])
    inc j
  name

let root = currentSourcePath().parentDir.parentDir
var seen = initTable[string, seq[string]]()
for path in walkDirRec(root / "src"):
  if not path.endsWith(".nim"): continue
  let content = readFile(path)
  for line in content.splitLines():
    let trimmed = line.strip
    if trimmed.startsWith("#"): continue
    let cppName = extractQuoted(line, "importcpp: ")
    if cppName.len > 0 and not cppName.endsWith("()") and
       (cppName.startsWith("daisy::") or cppName.startsWith("Sdram") or
        cppName.startsWith("SH1106") or cppName.startsWith("SSD130x") or
        cppName.startsWith("USBH_") or cppName.startsWith("WavPlayer") or
        cppName.startsWith("WavWriter") or cppName.startsWith("NeoPixel") or
        cppName.startsWith("Midi") or cppName.startsWith("daisy_") or
        cppName.startsWith("LedDriver") or
        cppName.startsWith("LcdHD44780") or cppName.startsWith("Icm2094") or
        cppName.startsWith("Dps310") or cppName.startsWith("Mpr121") or
        cppName.startsWith("NeoTrellis") or cppName.startsWith("Apds9960") or
        cppName.startsWith("Tlv493d")):
      seen.mgetOrPut(cppName, @[]).add(path)
    let cName = extractQuoted(line, "importc: ")
    if cName.len > 0 and cName[0].isUpperAscii():
      seen.mgetOrPut(cName, @[]).add(path)

var duplicates: seq[(string, int, seq[string])] = @[]
for name, files in seen:
  let unique = files.deduplicate
  if unique.len > 1:
    duplicates.add((name, unique.len, unique))

if duplicates.len == 0:
  echo "OK: no C++-backed type is declared in more than one module."
else:
  duplicates.sort(proc(a, b: (string, int, seq[string])): int = cmp(b[1], a[1]))
  for (name, count, files) in duplicates:
    echo name, " appears in ", count, " modules:"
    for f in files: echo "  - ", f
  echo ""
  echo "FAILED: ", duplicates.len, " C++-backed type(s) declared in multiple modules."
  quit(1)