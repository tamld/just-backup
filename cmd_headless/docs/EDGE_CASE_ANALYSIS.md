# Edge Case Analysis -- BA Design Document

> **Stage**: BA Design (Step 1 of 4)
> **Process**: BA Design --> Pipeline Design --> Draft Plan --> Edit Code
> **Scope**: RoboSync CMD Headless v2.0.0 -- Uncovered Edge Cases

---

## Method

Systematic code review of all 4 modules + router against the following checklist:
- Input validation gaps
- State machine inconsistencies
- ERRORLEVEL handling gaps
- Race conditions / timing issues
- Path handling edge cases
- Variable scoping leaks
- Cleanup gaps
- User experience dead-ends

---

## Category 1: Input Validation Gaps

### EC-1.1: Destination path not validated for existence in LOCAL mode

**File**: `RoboSync.bat:324-331` (`:ModeLocal`)
**Current behavior**: User enters dest path. If empty --> abort. If not empty --> proceed.
**Missing**: No check if dest path is a valid writable location before proceeding to source selection.
**Risk**: User types invalid path (e.g., `Z:\NonExistent`). Robocopy engine will auto-mkdir, but if the drive doesn't exist, `mkdir` fails silently (stderr suppressed) and robocopy will fail with exit code 16.
**Severity**: Medium

```
CURRENT:
  set /p "BACKUP_DEST=  Destination path: "
  if empty --> abort
  goto :SelectSource   <-- no validation

PROPOSED:
  set /p "BACKUP_DEST=  Destination path: "
  if empty --> abort
  Extract drive letter from BACKUP_DEST
  if drive doesn't exist --> [!!] Drive X: not found. PAUSE. goto :MainMenu
  if not exist dest --> mkdir (try) --> if fail --> [!!] PAUSE
  goto :SelectSource
```

**Acceptance Criteria**:
- [ ] EC-1.1.1: Drive letter extracted and validated
- [ ] EC-1.1.2: Non-existent drive shows `[!!]` with drive letter
- [ ] EC-1.1.3: Existing drive but non-existent folder auto-creates
- [ ] EC-1.1.4: Failed mkdir (read-only, permission) shows `[!!]`

---

### EC-1.2: PULL mode dest path not validated for drive existence

**File**: `RoboSync.bat:302-308` (`:ModePull`)
**Current behavior**: Same as EC-1.1 -- empty check only.
**Risk**: Same as EC-1.1.
**Severity**: Medium

---

### EC-1.3: Custom source path in SelectSource not validated

**File**: `RoboSync.bat:430-437`
**Current behavior**: User enters custom path. If empty --> go back. If not empty --> proceed to confirm.
**Missing**: No `if not exist` check on user-entered custom path.
**Risk**: Robocopy engine has `if not exist` check, but user sees confusing engine-level error instead of friendly validation.
**Severity**: Low (engine catches it, but UX is poor)

```
CURRENT:
  set /p "SELECTED_SRC=  Source path: "
  if empty --> goto :SelectSource
  goto :ConfirmAndRun   <-- no existence check

PROPOSED:
  set /p "SELECTED_SRC=  Source path: "
  if empty --> goto :SelectSource
  if not exist "!SELECTED_SRC!" (
      echo  [!!] Path does not exist: !SELECTED_SRC!
      call fn_pause_msg
      goto :SelectSource
  )
  goto :ConfirmAndRun
```

**Acceptance Criteria**:
- [ ] EC-1.3.1: Non-existent custom path shows `[!!]` at selection level
- [ ] EC-1.3.2: User returns to source selection (not engine abort)

---

### EC-1.4: Custom remote path in SelectRemoteSource not validated

**File**: `RoboSync.bat:496-503`
**Current behavior**: User enters custom remote path. If empty --> go back. If not empty --> robocopy immediately.
**Missing**: No check if remote path is reachable.
**Risk**: Robocopy fails with exit code 16, user sees confusing error.
**Severity**: Low (robocopy reports error, but UX is poor)

---

### EC-1.5: Restore backup path validation incomplete

**File**: `RoboSync.bat:563-577` (`:RestoreFromLocal`)
**Current behavior**: Checks empty and `if not exist`. Good.
**Missing**: No check if the path contains backup folders (user might enter wrong path).
**Risk**: User enters a valid path that has no backup data --> empty folder list --> confusing.
**Severity**: Low (handled gracefully -- shows "No folders found")

---

## Category 2: State Machine Inconsistencies

### EC-2.1: PUSH/PULL bypass NetworkMenu session persistence

**File**: `RoboSync.bat:276-286` (`:ModePush`) and `RoboSync.bat:291-311` (`:ModePull`)
**Current behavior**: PUSH and PULL call `:NetworkSetup` which runs a fresh network setup.
If user already connected via [5] Network Setup, PUSH/PULL still asks for network again.
**Missing**: Check if `NET_STATUS==CONNECTED` and offer to reuse existing connection.
**Risk**: User does Network Setup first (best practice per UC6), then starts PUSH/PULL, has to re-enter everything.
**Severity**: High (UX friction, contradicts UC6 purpose)

```
PROPOSED (for ModePush and ModePull):
  if "!NET_STATUS!"=="CONNECTED" (
      echo  [OK] Using existing connection: !NETWORK_PATH!
      choice /n /c YN /m "  Continue with this? [Y/N]: "
      if !errorlevel! equ 1 goto :skip_network_setup
  )
  call :NetworkSetup
  :skip_network_setup
```

**Acceptance Criteria**:
- [ ] EC-2.1.1: If already connected, show current connection and offer reuse
- [ ] EC-2.1.2: User can decline and re-setup (different IP/share)
- [ ] EC-2.1.3: Network session vars (Tier 2a) preserved across modes

---

### EC-2.2: RESTORE_BASE not cleared at MainMenu

**File**: `RoboSync.bat:94-103` (`:MainMenu`)
**Current behavior**: Tier 2b/3 vars cleared, but `RESTORE_BASE` is not in the clear list.
**Risk**: If user does Restore, then goes back to MainMenu, `RESTORE_BASE` persists. Not harmful but inconsistent with scoping contract.
**Severity**: Low (no functional impact, but violates contract)

```
PROPOSED (add to MainMenu cleanup):
  set "RESTORE_BASE="
```

---

### EC-2.3: REMOTE_SOURCE not cleared at MainMenu

**File**: `RoboSync.bat:310` (set in ModePull)
**Current behavior**: `REMOTE_SOURCE` is set in ModePull but not cleared at MainMenu.
**Risk**: Same as EC-2.2 -- stale variable.
**Severity**: Low

---

## Category 3: ERRORLEVEL Handling Gaps

### EC-3.1: netsh ERRORLEVEL not captured to flag variable

**File**: `network.bat:115-119` (`:fn_setup_direct_cable`)
**Current behavior**:
```bat
netsh interface ip set address "!NET_IFACE!" static !NET_LOCAL_IP! !_sub! >nul 2>&1
if !errorlevel! neq 0 (
```
**Issue**: `errorlevel` checked correctly but not captured to `RC` variable first.
Per AGENTS.md Section 4B Rule 1: "Capture immediately: `set "RC=!errorlevel!"` right after command."
**Risk**: If any command runs between `netsh` and `if !errorlevel!`, the value changes.
Currently safe (nothing between them), but fragile.
**Severity**: Low (defensive improvement)

**Acceptance Criteria**:
- [ ] EC-3.1.1: `set "RC=!errorlevel!"` added after netsh
- [ ] EC-3.1.2: `if !RC! neq 0` used instead of `if !errorlevel!`

---

### EC-3.2: DHCP restore errorlevel not checked

**File**: `network.bat:141-148` (`:fn_restore_dhcp`)
**Current behavior**: `netsh ... dhcp >nul 2>&1` -- no error check.
**Risk**: DHCP restore fails silently. User's interface stuck on static IP.
**Severity**: Medium (can leave network in bad state)

```
PROPOSED:
  netsh interface ip set address "!NET_IFACE!" dhcp >nul 2>&1
  set "RC=!errorlevel!"
  netsh interface ip set dns "!NET_IFACE!" dhcp >nul 2>&1
  if !RC! neq 0 (
      echo  [!!] Failed to restore DHCP on "!NET_IFACE!". Check manually.
  ) else (
      echo  [OK] DHCP restored.
  )
```

**Acceptance Criteria**:
- [ ] EC-3.2.1: netsh address DHCP errorlevel captured
- [ ] EC-3.2.2: Failure shows `[!!]` with interface name
- [ ] EC-3.2.3: Success shows `[OK]`

---

### EC-3.3: mkdir errorlevel not checked in multiple locations

**Files**: `RoboSync.bat:308,411,423,534,721` and `engine.bat:66-72`
**Current behavior**: Some `mkdir` calls have `2>nul` but no error check.
Engine.bat has proper check (line 67-72). Router does not.
**Risk**: If dest drive is read-only or full, mkdir fails, robocopy gets invalid dest.
**Severity**: Medium

**Locations needing fix**:
- `RoboSync.bat:308`: `if not exist "!BACKUP_DEST!" mkdir "!BACKUP_DEST!" 2>nul` (PULL mode)
- `RoboSync.bat:411`: `if not exist "!FINAL_DEST!" mkdir "!FINAL_DEST!" 2>nul` (ALL Profiles loop)
- `RoboSync.bat:423`: `if not exist "!FINAL_DEST!" mkdir "!FINAL_DEST!" 2>nul` (ALL Partitions loop)
- `RoboSync.bat:534`: `if not exist "!FINAL_DEST!" mkdir "!FINAL_DEST!" 2>nul` (ConfirmAndRun)
- `RoboSync.bat:721`: `if not exist "!_d!" mkdir "!_d!" 2>nul` (RestoreIntoProfile loop)

**Note**: Engine.bat already has proper check -- the router should match.

---

## Category 4: Path Handling Edge Cases

### EC-4.1: Trailing backslash inconsistency

**File**: Multiple locations
**Current behavior**: Some paths end with `\`, some don't. When concatenated:
- `E:\Backup` + `\` + `Profile_Admin` = `E:\Backup\Profile_Admin` (correct)
- `E:\Backup\` + `\` + `Profile_Admin` = `E:\Backup\\Profile_Admin` (double backslash)
**Risk**: Double backslash is usually tolerated by Windows, but can cause string comparison failures in source=dest guard.
**Severity**: Low (Windows tolerates `\\`, but inconsistent)

**Acceptance Criteria**:
- [ ] EC-4.1.1: Test that double backslash in path doesn't break source=dest guard
- [ ] EC-4.1.2: Document that Windows normalizes `\\` in paths

---

### EC-4.2: Paths with spaces not tested

**File**: All modules
**Current behavior**: All paths use `"!VAR!"` quoting (correct).
**Missing**: No test case for paths with spaces (e.g., `C:\Users\John Doe`).
**Risk**: If any location misses quotes, path with spaces breaks.
**Severity**: Medium (should be covered by static lint, but no explicit test)

**Acceptance Criteria**:
- [ ] EC-4.2.1: Test harness includes path-with-spaces scenario
- [ ] EC-4.2.2: Robocopy sandbox test uses folder with spaces

---

### EC-4.3: Paths with special characters

**File**: All modules
**Current behavior**: `chcp 65001` for Unicode. Paths quoted.
**Missing**: No test for paths containing `&`, `()`, `!`, `%`.
These chars are dangerous in CMD even inside quotes.
**Risk**:
- `&` in path: `echo  [--] Source : C:\Users\Tom & Jerry\` --> executes `Jerry\` as command
- `!` in path: Delayed expansion eats `!`
- `%` in path: Variable expansion
**Severity**: High (known CMD limitation, but not documented as known issue)

**Decision (BA)**: These are **known CMD limitations** that cannot be fully fixed without breaking delayed expansion. The correct action is:
1. Document as known limitation in OPERATION_GUIDE.md
2. Add test to verify quoting works for common special chars
3. Accept that `!` and `%` in paths are unsupported (document this)

---

## Category 5: Cleanup Gaps

### EC-5.1: Log directory never cleaned up

**File**: `engine.bat:77`
**Current behavior**: Every robocopy run creates a new log file. No cleanup ever.
**Risk**: After many runs, hundreds of log files accumulate.
**Severity**: Low (not a bug, but a UX consideration for future)
**Decision (BA)**: Defer to v2.x. Add log rotation or max-age cleanup.

---

### EC-5.2: Stale SRC_ array variables from previous SelectSource

**File**: `RoboSync.bat:336-381` (`:SelectSource`)
**Current behavior**: Each time `:SelectSource` runs, it re-detects and sets `SRC_n_PATH`, `SRC_n_NAME`, `SRC_n_TYPE`. But it doesn't clear old values first.
**Risk**: If first detection finds 5 sources, sets SRC_1 through SRC_5. If user goes back and re-enters SelectSource with a different dest, second detection finds 3 sources but SRC_4 and SRC_5 still exist from before.
**However**: The `_TOTAL` counter is reset to 0, and selection validation uses `call set` which returns empty for indices beyond current count. So this is safe.
**Severity**: Very Low (no functional impact due to index-based access, but hygiene issue)

---

### EC-5.3: NET_PASS double-clear pattern

**File**: `RoboSync.bat:179,201,266` and `network.bat:223`
**Current behavior**: `NET_PASS` is cleared in BOTH the caller (RoboSync.bat) AND the callee (network.bat fn_map_credentials). This is correct defense-in-depth.
**Status**: Already handled correctly. No action needed.

---

## Category 6: User Experience Dead-Ends

### EC-6.1: No "Backup ALL Profiles" for PUSH mode with type distinction

**File**: `RoboSync.bat:405-416`
**Current behavior**: "Backup ALL Profiles" always uses `PROFILE` type. Correct.
**Status**: Already correct. No issue.

---

### EC-6.2: PULL mode has no "ALL remote folders" with individual progress

**File**: `RoboSync.bat:490-493`
**Current behavior**: "Copy ENTIRE share" runs one robocopy for the whole share.
**Missing**: No option to copy each remote folder individually with per-folder status.
**Risk**: If one folder fails, entire operation status is unclear.
**Severity**: Low (enhancement, not bug)
**Decision (BA)**: Defer to v2.x enhancement.

---

### EC-6.3: No backup progress indicator beyond robocopy output

**File**: `engine.bat:93`
**Current behavior**: Robocopy shows native progress with `/NP /ETA`.
**Missing**: No summary after ALL operations complete (total files, total size, total time).
**Severity**: Low (enhancement)
**Decision (BA)**: Defer to v2.x. Would require parsing robocopy log after completion.

---

## Category 7: Version and Distribution

### EC-7.1: Dev RoboSync.bat header still says v1.3.0

**File**: `RoboSync.bat:3`
**Current behavior**: Header comment says `ROBOSYNC v1.3.0` but `APP_VERSION` is set to `v2.0.0` (line 72).
**Risk**: Confusion when reading source. Header =/= runtime version.
**Severity**: Low (cosmetic, but confusing)

**Acceptance Criteria**:
- [ ] EC-7.1.1: Header comment updated to match APP_VERSION

---

## Summary: Priority Matrix

```
  ┌──────────┬────────────────────────────────────────┬──────────┬──────────┐
  │ ID       │ Description                            │ Severity │ Action   │
  ├──────────┼────────────────────────────────────────┼──────────┼──────────┤
  │ EC-2.1   │ PUSH/PULL bypass network session       │ HIGH     │ FIX NOW  │
  │ EC-4.3   │ Special chars in paths (!, %, &)       │ HIGH     │ DOCUMENT │
  │ EC-1.1   │ Dest drive not validated (LOCAL)       │ MEDIUM   │ FIX NOW  │
  │ EC-1.2   │ Dest drive not validated (PULL)        │ MEDIUM   │ FIX NOW  │
  │ EC-3.2   │ DHCP restore errorlevel unchecked      │ MEDIUM   │ FIX NOW  │
  │ EC-3.3   │ mkdir errorlevel unchecked (router)    │ MEDIUM   │ FIX NOW  │
  │ EC-4.2   │ Paths with spaces not tested           │ MEDIUM   │ TEST     │
  │ EC-1.3   │ Custom source path not validated       │ LOW      │ FIX NOW  │
  │ EC-1.4   │ Custom remote path not validated       │ LOW      │ FIX NOW  │
  │ EC-2.2   │ RESTORE_BASE not cleared at MainMenu   │ LOW      │ FIX NOW  │
  │ EC-2.3   │ REMOTE_SOURCE not cleared at MainMenu  │ LOW      │ FIX NOW  │
  │ EC-3.1   │ netsh errorlevel not captured to RC    │ LOW      │ FIX NOW  │
  │ EC-7.1   │ Dev header version mismatch            │ LOW      │ FIX NOW  │
  │ EC-4.1   │ Trailing backslash inconsistency       │ LOW      │ TEST     │
  │ EC-5.1   │ Log files never cleaned                │ LOW      │ DEFER    │
  │ EC-5.2   │ Stale SRC_ array variables             │ V.LOW    │ DEFER    │
  │ EC-6.2   │ PULL ALL with per-folder progress      │ LOW      │ DEFER    │
  │ EC-6.3   │ Post-backup summary                    │ LOW      │ DEFER    │
  └──────────┴────────────────────────────────────────┴──────────┴──────────┘
```

### Action Plan

**FIX NOW (this iteration)**: EC-1.1, EC-1.2, EC-1.3, EC-1.4, EC-2.1, EC-2.2, EC-2.3, EC-3.1, EC-3.2, EC-3.3, EC-7.1
**TEST (add test coverage)**: EC-4.1, EC-4.2
**DOCUMENT (known limitation)**: EC-4.3
**DEFER (v2.x)**: EC-5.1, EC-5.2, EC-6.2, EC-6.3

---

## Decision Tree: Edge Case Resolution Flow

```
  Edge Case Found
       │
       ▼
  ┌──────────────────┐
  │ Can cause data    │──── YES ──── FIX NOW (Critical)
  │ loss or silent    │
  │ corruption?       │
  └────────┬──────────┘
           │ NO
           ▼
  ┌──────────────────┐
  │ Can leave system  │──── YES ──── FIX NOW (Medium)
  │ in bad state?     │
  │ (network, vars)   │
  └────────┬──────────┘
           │ NO
           ▼
  ┌──────────────────┐
  │ UX confusion or   │──── YES ──── FIX NOW (Low) or
  │ violates contract?│              DOCUMENT if unfixable
  └────────┬──────────┘
           │ NO
           ▼
  ┌──────────────────┐
  │ Enhancement /     │──── YES ──── DEFER to v2.x
  │ nice-to-have?     │
  └────────┬──────────┘
           │ NO
           ▼
       No action
```
