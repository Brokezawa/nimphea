# scripts/test.nims — run the host unit-test suite.
#
# Run with: nim e scripts/test.nims
#
# Self-contained: paths are derived from this file's location, so it works
# from any working directory and needs no package manager.

import std/os

const repoRoot = currentSourcePath().parentDir.parentDir

if not dirExists(repoRoot / "tests"):
  echo "ERROR: tests/ directory not found"
  quit(1)

withDir repoRoot:
  exec "nim c -r tests/all_tests.nim"

echo ""
echo "All unit tests passed!"
