# scripts/check_examples.nims — syntax-check every example in nimphea-examples.
#
# Run with: nim e scripts/check_examples.nims
#
# Locates the sibling nimphea-examples checkout (../nimphea-examples next to
# this repository) and `nim check`s each example's main source with the
# nimphea source directories on the search path. Exits non-zero if any example
# fails, so it can gate CI.

import std/os, std/strutils, std/algorithm

const repoRoot = currentSourcePath().parentDir.parentDir
const srcDir = repoRoot / "src"

proc fail(msg: string) =
  echo "ERROR: " & msg
  quit(1)

# 1. Locate the examples checkout (sibling directory preferred).
const candidates = [
  repoRoot.parentDir / "nimphea-examples",
  repoRoot / "nimphea-examples",
  repoRoot / "examples",
]
var examplesRoot = ""
for candidate in candidates:
  if dirExists(candidate):
    examplesRoot = candidate
    break
if examplesRoot == "":
  echo "No nimphea-examples checkout found."
  echo "Clone it next to this repository:"
  echo "  git clone https://github.com/Brokezawa/nimphea-examples " & repoRoot.parentDir / "nimphea-examples"
  quit(1)

# 2. Collect each example's main source. Examples live in
#    <examplesRoot>/examples/<name>/src/<name>.nim (a couple of examples keep
#    their sources directly under <examplesRoot>/<name>/src/<name>.nim).
var sources: seq[string] = @[]
for base in [examplesRoot / "examples", examplesRoot]:
  if not dirExists(base): continue
  for kind, path in walkDir(base):
    if kind != pcDir: continue
    let name = path.splitFile.name
    for srcBase in [path / "src", path]:
      if not dirExists(srcBase): continue
      let candidate = srcBase / (name & ".nim")
      if fileExists(candidate):
        sources.add(candidate)
        break

if sources.len == 0:
  echo "No example sources found under " & examplesRoot
  quit(1)

sources.sort()

# 3. Syntax-check each example. Export NIMPHEA so the examples' self-contained
#    config.nims files (which resolve nimphea from the NIMPHEA env var, then a
#    sibling checkout, then nimble) can always find this repository.
putEnv("NIMPHEA", repoRoot)

# 3. Syntax-check each example.
echo "=== Syntax-checking " & $sources.len & " examples in " & examplesRoot & " ==="
var failures: seq[string] = @[]
for source in sources:
  let rel = source.relativePath(examplesRoot)
  let (_, exitCode) = gorgeEx("nim check --path:" & srcDir & " --path:" & srcDir / "nimphea" &
                              " " & quoteShell(source))
  if exitCode == 0:
    echo "  [OK] " & rel
  else:
    echo "  [FAIL] " & rel
    failures.add(rel)

if failures.len > 0:
  echo ""
  echo "Failing examples (" & $failures.len & "):"
  for f in failures:
    echo "  - " & f
  fail($failures.len & " example(s) failed syntax check")

echo ""
echo "All " & $sources.len & " examples passed syntax check!"
