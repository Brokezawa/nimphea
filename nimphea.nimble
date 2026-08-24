# Package metadata only. All build/test/documentation logic lives in the
# standalone NimScripts under scripts/ (run with `nim e scripts/<name>.nims`),
# so this package works without any package manager. The tasks below are thin
# aliases for convenience when nimble is present.

version       = "2.0.0"
author        = "Brokezawa"
description   = "Nimphea - Elegant Nim bindings for libDaisy Hardware Abstraction Library (Daisy Audio Platform: Seed, Patch, Pod, Field, Petal, Versio)"
license       = "MIT"
srcDir        = "src"
installDirs   = @["templates"]
installFiles  = @[]
skipDirs      = @["tests", "docs", "nimphea-examples", "cmake", "ci", "resources", ".github", "libDaisy"]
skipFiles     = @[]

requires "nim >= 2.0.0"

task init_libdaisy, "Obtain and build the libDaisy dependency":
  exec "nim e scripts/init_libdaisy.nims"

task test, "Run all tests (see test_unit)":
  exec "nim e scripts/test.nims"

task test_unit, "Run unit tests on host computer":
  exec "nim e scripts/test.nims"

task clear, "Remove all build artifacts":
  exec "nim e scripts/clear.nims"

task docs, "Generate API documentation":
  exec "nim e scripts/docs.nims"

task check_examples, "Syntax-check all example programs (host, no ARM)":
  exec "nim e scripts/check_examples.nims"

task check_duplicate_types, "Verify no C++-backed type is declared twice":
  exec "nim e scripts/check_duplicate_types.nims"