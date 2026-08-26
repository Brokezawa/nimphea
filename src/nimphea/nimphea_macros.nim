## C++ interop macro system — deprecated compatibility stub
##
## Since the v2.0 interop rework, every C++ binding carries its own
## `{.importcpp.}`/`{.importc.}` pragma with a fully-qualified `daisy::` name
## and a per-binding `header:` pragma (header pragmas propagate into every
## translation unit that uses the symbol). No macro-injected `#include`
## sections, `using namespace daisy;`, or C++ typedefs are generated anymore.
##
## `useNimpheaNamespace()` and `useNimpheaModules(...)` are retained as
## **inert compatibility no-ops**: the ~60 library modules and the example
## programs still call them, and legacy user code keeps compiling unchanged.
##
## Do NOT add new functionality here — add pragma-based bindings instead.

import macros

macro useNimpheaNamespace*(): untyped =
  ## Inert compatibility no-op (see module doc) — kept so legacy call sites
  ## compile unchanged. Bindings are self-contained via header pragmas.
  result = newStmtList()

macro useNimpheaModules*(modules: varargs[untyped]): untyped =
  ## Inert compatibility no-op (see module doc) — kept so legacy call sites
  ## compile unchanged. Bindings are self-contained via header pragmas.
  result = newStmtList()