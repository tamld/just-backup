# CMD Error Handling Patterns -- RoboSync Reference

> **Purpose**: Definitive reference for ERRORLEVEL-driven logic, escape rules,
> and fail-fast patterns in CMD batch. CMD is NOT a normal programming language --
> it has no exceptions, no stdout capture you can trust, and no scope.
> This document codifies how RoboSync handles errors reliably despite these constraints.

---

## 1. The ERRORLEVEL Doctrine

### Why ERRORLEVEL, Not STDOUT

In modern languages, you capture function return values via stdout/stderr.
In CMD, this approach is **fundamentally broken**:

```
REM DANGEROUS -- stdout parsing breaks on special chars
for /f "delims=" %%R in ('some_command') do set "RESULT=%%R"
REM If output contains ! % ^ & > < | ( ) -- this EXPLODES
```

**ERRORLEVEL is the ONLY reliable communication channel** between CMD functions.
It survives special characters, delayed expansion, and pipe redirection.

### The ERRORLEVEL Contract

```
  ┌─────────────────────────────────────────────────────────┐
  │              ERRORLEVEL TRUTH TABLE                     │
  ├────────────┬────────────────────────────────────────────┤
  │ Source     │ Meaning                                    │
  ├────────────┼────────────────────────────────────────────┤
  │ robocopy   │ 0-3=SUCCESS, 4-7=WARNING, 8+=FATAL ERROR  │
  │ ping       │ 0=Reply received, 1=No reply              │
  │ net use    │ 0=Mapped OK, 2=System error (auth/path)   │
  │ cacls.exe  │ 0=Admin, non-0=Not admin                  │
  │ choice     │ 1=First option, 2=Second, 3=Third ...     │
  │ fsutil     │ 0=Success, non-0=Failure                  │
  │ netsh      │ 0=Applied, non-0=Failed                   │
  │ mkdir      │ 0=Created, non-0=Already exists or denied │
  │ exit /b N  │ Sets ERRORLEVEL to N for caller           │
  └────────────┴────────────────────────────────────────────┘
```

### ERRORLEVEL Gotchas

```bat
REM WRONG -- "==" checks exact value, but ERRORLEVEL is "greater than or equal"
if %errorlevel%==1 echo "Is exactly 1"

REM CORRECT -- use LEQ/GEQ/GTR for ranges (robocopy returns 0-16)
if %errorlevel% LEQ 3 ( echo SUCCESS )
if %errorlevel% GEQ 8 ( echo FAILURE )

REM WRONG -- checking errorlevel AFTER another command resets it
set "x=1"
if %errorlevel% neq 0 echo "This checks errorlevel of SET, not previous cmd"

REM CORRECT -- capture immediately
robocopy "!src!" "!dst!" /MIR
set "RC=!errorlevel!"
REM Now RC is safe to check at any point
if !RC! GEQ 8 echo FAILED
```

---

## 2. The Flag Variable Pattern

Since CMD functions cannot return values (only ERRORLEVEL), RoboSync uses
**flag variables** as an explicit contract between caller and callee.

### Pattern

```bat
REM Callee sets a flag
:fn_test_connection
    set "NET_PING_OK=0"
    ping -n 2 -w 1000 "%~1" | find "TTL=" >nul 2>&1
    if !errorlevel! equ 0 set "NET_PING_OK=1"
    goto :eof

REM Caller checks the flag
call "%LIBS%\network.bat" fn_test_connection "!DEST_IP!"
if "!NET_PING_OK!"=="0" (
    call "%LIBS%\ui.bat" fn_pause_msg "Cannot reach !DEST_IP!"
    goto :CleanupAndMenu
)
```

### Flag Variable Registry

```
  ┌──────────────────┬──────────┬──────────────────────────┐
  │ Flag Variable    │ Values   │ Set By                   │
  ├──────────────────┼──────────┼──────────────────────────┤
  │ INPUT_OK         │ 0 / 1    │ fn_input_credentials     │
  │ NET_PING_OK      │ 0 / 1    │ fn_test_connection       │
  │ NET_MAP_OK       │ 0 / 1    │ fn_map_credentials       │
  │ DIRECT_SETUP_OK  │ 0 / 1    │ fn_setup_direct_cable    │
  │ LAST_RC_STATUS   │ SUCCESS  │ fn_run_robocopy          │
  │                  │ WARNING  │                          │
  │                  │ FAILED   │                          │
  │ LAST_RC_CODE     │ 0-16/99  │ fn_run_robocopy          │
  └──────────────────┴──────────┴──────────────────────────┘

  Code 99 = RoboSync internal error (pre-flight validation failed)
  Code 0-16 = Native robocopy exit codes
```

### Decision Chain Pattern

RoboSync chains flag checks in sequence -- each step must pass before the next runs.
This is the CMD equivalent of early-return or exception handling:

```
  fn_input_credentials
         │
    INPUT_OK=1? ──NO──► PAUSE + Return
         │
        YES
         │
  fn_test_connection
         │
  NET_PING_OK=1? ──NO──► PAUSE + Return
         │
        YES
         │
  fn_map_credentials
         │
   NET_MAP_OK=1? ──NO──► PAUSE + Return
         │
        YES
         │
     CONTINUE ──► Backup flow
```

---

## 3. Fail-Fast Validation Patterns

### Pattern A: Empty Parameter Guard

```bat
:fn_run_robocopy
    set "_rc_src=%~1"
    set "_rc_dst=%~2"

    REM Fail-fast: empty source
    if "!_rc_src!"=="" (
        echo  [!!] Source path trong. Huy thao tac.
        set "LAST_RC_STATUS=FAILED"
        set "LAST_RC_CODE=99"
        goto :eof
    )
```

**Rule**: Every function validates ALL inputs before any logic. Empty = abort.

### Pattern B: Path Existence Guard

```bat
    REM Fail-fast: source doesn't exist
    if not exist "!_rc_src!" (
        echo  [!!] Source khong ton tai: !_rc_src!
        set "LAST_RC_STATUS=FAILED"
        set "LAST_RC_CODE=99"
        goto :eof
    )
```

**Rule**: Never pass a non-existent path to robocopy. Validate BEFORE execution.

### Pattern C: Self-Copy Guard

```bat
    REM Fail-fast: source = destination
    if "!_rc_src!"=="!_rc_dst!" (
        echo  [!!] Source and Destination are the same path. Aborting.
        set "LAST_RC_STATUS=FAILED"
        set "LAST_RC_CODE=99"
        goto :eof
    )
```

**Rule**: Prevent self-copy which would cause data loss with `/MIR`.

### Pattern D: Module Existence Guard (Bootstrap)

```bat
    REM At startup -- verify all libs exist
    for %%M in (engine network discover ui) do (
        if not exist "%LIBS%\%%M.bat" (
            echo  [!!] Missing module: lib\%%M.bat
            pause
            exit /b 1
        )
    )
```

**Rule**: If a module is missing, the app CANNOT function. Abort hard at startup.

### Pattern E: Pre-clear Before set /p

```bat
    REM WRONG -- if user presses Enter, _SC keeps its OLD value
    set /p "_SC=  Choose: "

    REM CORRECT -- pre-clear ensures empty on bare Enter
    set "_SC="
    set /p "_SC=  Choose: "
    if "!_SC!"=="" goto :SomeMenu
```

**Rule**: Always `set "VAR="` within 5 lines above `set /p "VAR=..."`.

---

## 4. Escape Rules -- The Complete Reference

### 4.1 The Expansion Order

CMD processes each line in this exact order:
```
  1. % expansion (parse time -- BEFORE execution)
  2. for %%VAR expansion
  3. ! expansion (delayed -- AT execution time, if enabledelayedexpansion)
  4. ^ caret escape processing
  5. Redirection (>, >>, <, |, &)
  6. Command execution
```

**Critical implication**: `%VAR%` is resolved BEFORE the block executes.
Inside `if` or `for` blocks, a `%VAR%` that was set inside the same block
reads the **OLD value** (the value before the block was parsed).

### 4.2 Escape Cheat Sheet

```
  ┌────────────┬──────────────────┬──────────────────────────────┐
  │ Character  │ Context          │ Escape Method                │
  ├────────────┼──────────────────┼──────────────────────────────┤
  │ (  )       │ Inside echo      │ ^( ^)                        │
  │ >  >>      │ Inside echo      │ ^> ^>^>                      │
  │ <          │ Inside echo      │ ^<                           │
  │ |          │ Inside echo      │ ^|                           │
  │ &          │ Inside echo      │ ^&                           │
  │ !          │ Delayed expansion │ ^^! (double-escape)         │
  │            │ active           │ or disable delayed expansion │
  │ %          │ In batch file    │ %% (double percent)          │
  │ %          │ In for /f        │ %%%% (quadruple in nested)   │
  │ "          │ In set           │ Always quote: set "VAR=val"  │
  │ ::         │ Inside if/for    │ Use REM instead              │
  └────────────┴──────────────────┴──────────────────────────────┘
```

### 4.3 Dangerous Patterns and Fixes

**Pattern: `::` comment inside a block**
```bat
REM CRASH -- :: is a hidden label, breaks if/for block parsing
if "!x!"=="1" (
    :: This will crash the parser
    echo hello
)

REM SAFE -- use REM inside blocks
if "!x!"=="1" (
    REM This is safe
    echo hello
)
```

**Pattern: `%VAR%` inside a loop that modifies VAR**
```bat
REM WRONG -- %COUNT% reads the value BEFORE the loop started
set /a COUNT=0
for %%F in (*) do (
    set /a COUNT+=1
    echo Count is %COUNT%
)
REM This prints "Count is 0" for every iteration!

REM CORRECT -- use delayed expansion !COUNT!
setlocal enabledelayedexpansion
set /a COUNT=0
for %%F in (*) do (
    set /a COUNT+=1
    echo Count is !COUNT!
)
```

**Pattern: Echo with parentheses**
```bat
REM CRASH -- unescaped parentheses inside a block
if "!x!"=="1" (
    echo Result: (none found)
)
REM The ) in "found)" closes the if block prematurely!

REM SAFE -- escape with ^
if "!x!"=="1" (
    echo Result: ^(none found^)
)
```

**Pattern: Dynamic array access**
```bat
REM WRONG -- direct variable-in-variable doesn't work
set "item=!ARRAY_!IDX!!"

REM CORRECT -- use call set for double expansion
call set "item=%%ARRAY_!IDX!%%"
REM First pass: !IDX! expands to e.g. "3"
REM Second pass (call): %%ARRAY_3%% expands to the value
```

**Pattern: Redirection inside if/for blocks**
```bat
REM WRONG -- > is parsed as part of the block structure
if "!x!"=="1" (
    echo text > file.txt
)

REM CORRECT -- escape the redirect
if "!x!"=="1" (
    echo text ^> file.txt
)
REM OR redirect the entire block
if "!x!"=="1" (
    echo text
) > file.txt
```

---

## 5. Robocopy Exit Code Reference

Robocopy uses a **bitmask** exit code system:

```
  ┌─────┬──────────────────────────────────────────────────┐
  │ Bit │ Meaning                                          │
  ├─────┼──────────────────────────────────────────────────┤
  │  0  │ (1)  Files were copied successfully              │
  │  1  │ (2)  Extra files or dirs detected at dest        │
  │  2  │ (4)  Mismatched files or dirs detected           │
  │  3  │ (8)  Some files could not be copied (error)      │
  │  4  │ (16) Serious error. No files were copied         │
  └─────┴──────────────────────────────────────────────────┘

  Combined exit codes:
  ┌──────────┬───────────────────────────────────────────────┐
  │ Code     │ RoboSync Interpretation                       │
  ├──────────┼───────────────────────────────────────────────┤
  │ 0        │ SUCCESS -- No changes needed (source=dest)    │
  │ 1        │ SUCCESS -- Files copied OK                    │
  │ 2        │ SUCCESS -- Extra files at dest (info only)    │
  │ 3        │ SUCCESS -- Files copied + extras at dest      │
  │ 4        │ WARNING -- Mismatched files (some skipped)    │
  │ 5        │ WARNING -- Copied + mismatched                │
  │ 6        │ WARNING -- Extras + mismatched                │
  │ 7        │ WARNING -- Copied + extras + mismatched       │
  │ 8        │ FAILED  -- Some files could not be copied     │
  │ 16       │ FAILED  -- Fatal error, nothing copied        │
  │ 99       │ FAILED  -- RoboSync internal (pre-flight)     │
  └──────────┴───────────────────────────────────────────────┘
```

### Decision Logic in engine.bat

```bat
if !LAST_RC_CODE! LEQ 3 (
    set "LAST_RC_STATUS=SUCCESS"
    echo  [OK] Hoan tat. Code=!LAST_RC_CODE!
) else if !LAST_RC_CODE! LEQ 7 (
    set "LAST_RC_STATUS=WARNING"
    echo  [!!] Hoan tat voi canh bao. Code=!LAST_RC_CODE!
) else (
    set "LAST_RC_STATUS=FAILED"
    echo  [!!] LOI NGHIEM TRONG. Code=!LAST_RC_CODE!
)
```

### PAUSE Strategy Applied to Exit Codes

```
  Exit Code ──► 0-3 ──► [OK] No PAUSE, continue silently
             │
             ├─► 4-7 ──► [!!] WARNING + PAUSE
             │           User sees warning, presses key to continue
             │
             └─► 8+  ──► [!!] FAILED + PAUSE
                         User sees error, presses key to continue
                         User should check log file for details
```

---

## 6. Error Loud -- Console Output Contract

Every error MUST be visible. Never silently swallow errors.

```
  ┌───────────┬──────────────────────────────────────────────┐
  │ Prefix    │ When to use                                  │
  ├───────────┼──────────────────────────────────────────────┤
  │ [>>]      │ Section header (entering a new flow)         │
  │ [--]      │ Info output (showing current state)          │
  │ [OK]      │ Success (operation completed normally)       │
  │ [!!]      │ Warning or Error (ALWAYS followed by detail) │
  └───────────┴──────────────────────────────────────────────┘

  Error messages MUST include:
  1. The [!!] prefix (so user's eye catches it)
  2. WHAT failed (e.g., "Source khong ton tai")
  3. The VALUE that caused failure (e.g., ": !_rc_src!")
  4. PAUSE if user needs to read it (see PAUSE Strategy)
```

---

## 7. Anti-Patterns -- What NOT to Do

### Anti-Pattern 1: Silent Failure
```bat
REM WRONG -- error swallowed, user sees nothing
if not exist "!path!" goto :eof

REM CORRECT -- error loud
if not exist "!path!" (
    echo  [!!] Path does not exist: !path!
    set "LAST_RC_STATUS=FAILED"
    goto :eof
)
```

### Anti-Pattern 2: Using `exit` Inside a Module
```bat
REM WRONG -- kills the entire CMD window
:fn_some_function
    if "%~1"=="" exit 1

REM CORRECT -- returns to caller
:fn_some_function
    if "%~1"=="" (
        echo  [!!] Missing parameter.
        goto :eof
    )
```

### Anti-Pattern 3: Stdout Parsing for Logic
```bat
REM FRAGILE -- breaks on special characters in output
for /f "delims=" %%R in ('dir /b "!path!" 2^>nul') do (
    set "FILES=!FILES! %%R"
)

REM SAFER -- use ERRORLEVEL or if exist for decisions
dir /b "!path!" >nul 2>&1
if !errorlevel! neq 0 (
    echo  [!!] No files found.
    goto :eof
)
```

### Anti-Pattern 4: Unquoted set Assignment
```bat
REM WRONG -- trailing space becomes part of the value
set MY_VAR=hello

REM CORRECT -- quotes prevent trailing spaces
set "MY_VAR=hello"
```

### Anti-Pattern 5: Checking ERRORLEVEL After SET
```bat
REM WRONG -- set resets errorlevel
some_command
set "result=done"
if !errorlevel! neq 0 echo "This checks SET's errorlevel, not some_command!"

REM CORRECT -- capture immediately
some_command
set "RC=!errorlevel!"
set "result=done"
if !RC! neq 0 echo "Now we check the right thing"
```
