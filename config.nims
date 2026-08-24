# config.nims — library build configuration for the nimphea source tree.
#
# This file only adds this repository's own source directories to the Nim
# search path. All paths are derived from this file's location, so the
# repository can be rebuilt from a relocated or renamed checkout without any
# package-manager involvement.

import std/os

let repoRoot = currentSourcePath().parentDir

switch("path", repoRoot & "/src")
switch("path", repoRoot & "/src/nimphea")
