# scripts/check_duplicate_types.nims — verify no C++-backed type is declared twice.
#
# Run with: nim e scripts/check_duplicate_types.nims
#
# Runs the duplicate-type guard over src/; exits non-zero if any duplicates are
# found so it can gate CI.

import std/os

const repoRoot = currentSourcePath().parentDir.parentDir

withDir repoRoot:
  exec "nim c -r --hints:off tools/check_duplicate_types.nim"

echo ""
echo "No duplicate C++-backed types found."
