# scripts/docs.nims — generate HTML API documentation for all library modules.
#
# Run with: nim e scripts/docs.nims
#
# Self-contained: paths are derived from this file's location (gorgeEx runs
# child processes from this script's directory, so absolute paths are used),
# and the working directory is never assumed.

import std/os, std/strutils, std/strformat, std/algorithm

const repoRoot = currentSourcePath().parentDir.parentDir
const docsDir = repoRoot / "docs" / "api"
const gitUrl = "https://github.com/Brokezawa/nimphea"
const gitCommit = "main"

var allModules: seq[string] = @[repoRoot / "src" / "nimphea.nim"]
for path in walkDirRec(repoRoot / "src"):
  if path.endsWith(".nim") and path.startsWith(repoRoot / "src" / "nimphea" / ""):
    allModules.add(path)
allModules.sort()

echo "=== Generating API documentation ==="
echo "Found " & $allModules.len & " modules to document"
echo ""

# Clean up any old files
echo "Cleaning old documentation files..."
if dirExists(docsDir):
  rmDir(docsDir)
mkDir(docsDir)

# Stage 1: Generate .idx files for all modules
echo "Stage 1: Generating index files..."
var idxCount = 0
for modulePath in allModules:
  let cmd = "nim doc --index:only --backend:cpp --doccmd:skip" &
            " --path:" & repoRoot / "src" &
            " --path:" & repoRoot / "src" / "nimphea" &
            " --git.url:" & gitUrl & " --git.commit:" & gitCommit &
            " --hints:off --warnings:off" &
            " --outdir:" & docsDir & " " & quoteShell(modulePath)
  let (_, exitCode) = gorgeEx(cmd)
  if exitCode == 0:
    inc idxCount
  else:
    echo "  Warning: failed to generate index for " & modulePath
echo "  Generated " & $idxCount & " index files"
echo ""

# Stage 2: Generate HTML documentation
echo "Stage 2: Generating HTML documentation..."
var htmlCount = 0
var first = true
for modulePath in allModules:
  var cmd = "nim doc --backend:cpp --doccmd:skip"
  if first:
    cmd.add(" --index:on")
  cmd.add(" --path:" & repoRoot / "src")
  cmd.add(" --path:" & repoRoot / "src" / "nimphea")
  cmd.add(" --git.url:" & gitUrl & " --git.commit:" & gitCommit)
  cmd.add(" --hints:off --warnings:off")
  cmd.add(" --outdir:" & docsDir)
  cmd.add(" " & quoteShell(modulePath))
  let (output, exitCode) = gorgeEx(cmd)
  if exitCode == 0:
    inc htmlCount
  else:
    echo "  Warning: failed to generate docs for " & modulePath
    echo output
  first = false
echo "  Generated " & $htmlCount & " HTML files"
echo ""

# Stage 3: Build comprehensive index
echo "Stage 3: Building comprehensive index..."
let (idxOutput, idxExitCode) = gorgeEx("nim buildIndex -o:" & quoteShell(docsDir / "theindex.html") & " " & quoteShell(docsDir))
if idxExitCode == 0:
  echo "  Index built successfully"
else:
  echo "  Warning: failed to build index"
  echo idxOutput

echo ""
echo "Documentation generated successfully"