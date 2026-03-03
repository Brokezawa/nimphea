# Nimphea v1.1.0 Codebase Audit

## Scope
Core Nim wrapper only: `src/` and `nimphea.nim`.  
Excluded: `libDaisy/`, `examples/`, `tests/`, `templates/`, `docs/`.

## Methodology
- Static scan for risky patterns (`{.emit.}`, unsafe casts/pointer math, RT callbacks without `raises:[]`).
- Manual review of critical modules: CMSIS wrappers, macro system, and low‑level `sys/` & `per/` components.
- Findings grouped by five focus areas: code quality/Nim best practices, bugs/edge cases, performance, readability/maintainability, and memory safety.

## Summary
**High:** 0  
**Medium:** 2  
**Low:** 3  
**Info:** 2  

## Findings (by focus area)

### 1) Code Quality & Nim Best Practices
**[Medium] Missing `#.Method` in `importcpp` (this pointer binding)**  
**Files:** `src/nimphea/per/uart.nim`  
**Details:** `init`, `getConfig`, and `checkError` use `importcpp: "Init"` / `"GetConfig"` / `"CheckError"` instead of `"#.Init()"`, `"#.GetConfig()"`, `"#.CheckError()"`.  
**Impact:** Can bind as static or free functions instead of instance methods, leading to wrong calls or compile errors depending on C++ overload resolution.  
**Recommendation:** Use the `#.` pattern for instance methods.

**[Low] Raw `{.emit.}` used outside macro system**  
**Files:** `src/nimphea.nim`, `src/nimphea/boards/daisy_*.nim`, `src/nimphea/nimphea_ui_core.nim`  
**Details:** `{.emit.}` is used to cast callback wrappers and to set function pointers / initializer_list helpers.  
**Impact:** Deviates from macro-only header policy; may be necessary but should be documented as an approved exception.  
**Recommendation:** Confirm each emit is required; add/maintain rationale inline (as already done in `nimphea_ui_core.nim`).

### 2) Potential Bugs / Edge Cases
**[Medium] RT callback wrappers lack `raises:[]`**  
**Files:** `src/nimphea.nim` (`audioCallbackWrapper`, `interleavingCallbackWrapper`), board wrappers in `src/nimphea/boards/`  
**Details:** RT callbacks are `cdecl` but not marked `raises:[]`.  
**Impact:** Exceptions in a real‑time callback can crash or destabilize audio.  
**Recommendation:** Annotate RT wrapper procs with `{.raises: [].}`.

### 3) Performance Optimizations
**[Info] No dynamic allocation in RT callbacks found**  
**Files:** core callbacks, boards, and UI wrappers  
**Details:** Static scan found no `newSeq` or dynamic allocations inside RT callbacks.  
**Impact:** RT performance appears safe in this area.  

**[Low] `clearSdramBss` can be slow on large BSS**  
**File:** `src/nimphea/sys/sdram.nim`  
**Details:** Zeroing SDRAM BSS is linear in SDRAM size.  
**Impact:** Can add several milliseconds at startup.  
**Recommendation:** Use only when needed and document expected cost.

### 4) Readability & Maintainability
**[Low] Emit‑based helpers reduce traceability**  
**Files:** `src/nimphea/nimphea_ui_core.nim`, `src/nimphea.nim`  
**Details:** Emit for initializer_list and function pointers is necessary but opaque.  
**Impact:** Harder to audit and maintain; changes require C++ knowledge.  
**Recommendation:** Keep emit blocks minimal and well‑commented (current comments are good; keep them up‑to‑date).

### 5) Memory Leaks & Memory Safety
**[Low] Pointer arithmetic relies on linker invariants**  
**File:** `src/nimphea/sys/sdram.nim`  
**Details:** `clearSdramBss` uses pointer arithmetic with `_ssdram_bss`/`_esdram_bss`.  
**Impact:** Safe only if linker symbols are valid and aligned; misconfiguration could corrupt memory.  
**Recommendation:** Add optional debug assertions or document linker requirements prominently.

**[Info] No heap allocation/leak patterns detected**  
**Scope:** `src/`, `nimphea.nim`  
**Details:** No explicit heap allocations in RT paths; no ownership leaks observed in wrappers.

## Notes
- CMSIS include macros (`src/nimphea/cmsis/cmsis_core.nim`) intentionally use `{.emit.}` and are documented as exceptions.  
- Findings marked **Low** or **Info** are primarily maintainability/safety notes; confirm before changes.  
