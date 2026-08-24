# scripts/clear.nims — remove all build and test artifacts.
#
# Run with: nim e scripts/clear.nims
#
# Removes the repository build/ directory and the host-test artifacts
# (compiled test binary, its dSYM, and the test nimcache).

import std/os

const repoRoot = currentSourcePath().parentDir.parentDir

echo "Cleaning build artifacts..."

if dirExists(repoRoot / "build"):
  rmDir(repoRoot / "build")
  echo "  removed build/"

for rel in ["tests/.nimcache", "tests/all_tests.dSYM"]:
  if dirExists(repoRoot / rel):
    rmDir(repoRoot / rel)
    echo "  removed " & rel

for rel in ["tests/all_tests"]:
  if fileExists(repoRoot / rel):
    rmFile(repoRoot / rel)
    echo "  removed " & rel

echo "Done."
