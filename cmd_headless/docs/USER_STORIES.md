# User Stories -- RoboSync CMD Headless

## Overview

This document defines the formal user stories (Use Cases) for the RoboSync CMD Headless
backup and restore tool. Each story maps to a specific operation mode in the application.

Each UC includes: preconditions, postconditions, acceptance criteria, and error scenarios.

---

## UC1: Backup PUSH (Local --> Remote)

**As a** technician backing up a user's PC,
**I want to** copy local data to a remote machine over SMB,
**So that** the data is safely stored on a network share or another PC.

### Preconditions
- PC runs Windows 7+ with Administrator privileges
- Ethernet cable connected (Direct Cable) OR both PCs on same LAN (DHCP)
- Remote PC has a shared folder accessible via SMB (e.g., `C$` or custom share)
- Remote PC has valid credentials (username + password)
- Sufficient free space on remote destination

### Flow
1. User selects **[1] Backup PUSH** from Main Menu.
2. System prompts for network type: Direct Cable (static IP) or DHCP.
3. If Direct Cable: system sets static IP on selected interface.
4. User enters remote IP, share name, username, password.
5. System pings remote host --> maps credentials via `net use`.
6. Password is **cleared immediately** after `net use` (zero-leak).
7. System auto-detects local profiles (`C:\Users\*`) and partitions (D-Z drives).
8. User selects source(s): single profile, single partition, custom path, ALL profiles, or ALL partitions.
9. System confirms source --> destination --> type, asks Y/N.
10. Robocopy executes with appropriate flags (`/MIR /Z /MT:16` for network).
11. Exit code parsed: 0-3=SUCCESS, 4-7=WARNING (pause), 8+=FAILED (pause).
12. User can select another source or go back to Main Menu.
13. On exit: `net use` unmapped, DHCP restored if Direct Cable was used.

### Postconditions
- Remote destination contains an exact mirror of the selected source(s)
- Log file created at `logs/RS_<timestamp>.log` with full robocopy output
- Network connection cleaned up (unmapped, DHCP restored if Direct Cable)
- All pipeline variables (Tier 2b/3) cleared at MainMenu return
- `NET_PASS` is empty (zero-leak verified)

### Robocopy Flags by Source Type
| Source Type | Key Flags |
|---|---|
| PROFILE | `/MIR /ZB /XJ` + profile exclusions (cache, temp, browser data) |
| PARTITION | `/MIR /Z` + system file exclusions (pagefile, hiberfil, $Recycle.Bin) |
| USB | `/MIR /MT:8 /R:1 /W:0` (reduced threads for removable media) |
| CUSTOM | `/MIR /Z /MT:16` + $Recycle.Bin exclusion |

### Acceptance Criteria
- [ ] AC1.1: Network connection established and authenticated before backup starts
- [ ] AC1.2: Auto-detection lists all non-system user profiles under `C:\Users\`
- [ ] AC1.3: Auto-detection lists all non-C: fixed drives and USB drives
- [ ] AC1.4: USB drives detected with correct type (USB, not PARTITION)
- [ ] AC1.5: Confirmation screen shows Source, Destination, Type before execution
- [ ] AC1.6: Robocopy exit code 0-3 shows `[OK]` with no PAUSE
- [ ] AC1.7: Robocopy exit code 4-7 shows `[!!]` WARNING with PAUSE
- [ ] AC1.8: Robocopy exit code 8+ shows `[!!]` FAILED with PAUSE
- [ ] AC1.9: Password variable (`NET_PASS`) is empty after `net use` call
- [ ] AC1.10: "ALL Profiles" option loops through every profile
- [ ] AC1.11: "ALL Partitions" option loops through every non-C: drive
- [ ] AC1.12: After backup, user returns to source selection (can backup more)
- [ ] AC1.13: Network drop during copy resumes automatically via `/Z`

### Error Scenarios
| Scenario | Expected Behavior | ERRORLEVEL/Flag |
|---|---|---|
| Empty source path | `[!!]` abort, LAST_RC_CODE=99 | LAST_RC_STATUS=FAILED |
| Empty dest path | `[!!]` abort, LAST_RC_CODE=99 | LAST_RC_STATUS=FAILED |
| Source path doesn't exist | `[!!]` abort, LAST_RC_CODE=99 | LAST_RC_STATUS=FAILED |
| Source = Destination | `[!!]` abort, LAST_RC_CODE=99 | LAST_RC_STATUS=FAILED |
| Ping fails | `[!!]` PAUSE, return to menu | NET_PING_OK=0 |
| Auth fails (`net use`) | `[!!]` PAUSE, return to menu | NET_MAP_OK=0 |
| Network drop mid-copy | Auto-resume via `/Z` | Robocopy handles |
| Outlook running (PST locked) | Warning in log, file skipped | Exit code 4-7 |
| Invalid menu selection | `[!!]` Invalid, 2s timeout, re-prompt | N/A |

---

## UC2: Backup PULL (Remote --> Local)

**As a** technician,
**I want to** pull data from a remote machine to local storage,
**So that** I can consolidate backups from multiple PCs.

### Preconditions
- Same network preconditions as UC1
- Local drive has sufficient free space for backup
- Remote share contains data to pull

### Flow
1. User selects **[2] Backup PULL** from Main Menu.
2. Network setup (same as UC1 steps 2-6).
3. User enters local save path (e.g., `D:\Restore`).
4. System lists remote folders on the network share via `for /d`.
5. User selects: specific folder, custom remote path, or ENTIRE share.
6. Robocopy copies remote --> local with CUSTOM flags.
7. Exit code parsed, pause on warning/failure.
8. User can select another remote folder or go back.

### Postconditions
- Local destination contains copy of selected remote data
- Log file created at `logs/RS_<timestamp>.log`
- If local dest didn't exist, it was auto-created
- Network cleaned up on menu return

### Key Differences from UC1
- Source is remote (UNC path), destination is local.
- Cannot classify remote drive types (no `fsutil` over SMB).
- All remote sources treated as CUSTOM type.
- Remote folders listed via `for /d` only (no `fsutil`, no drive type).

### Acceptance Criteria
- [ ] AC2.1: Network connection established before remote folder listing
- [ ] AC2.2: Remote folders listed correctly via `for /d`
- [ ] AC2.3: User can select individual folder, custom path, or ENTIRE share
- [ ] AC2.4: "ENTIRE share" copies full `\\IP\Share\` to local dest
- [ ] AC2.5: Local destination auto-created if it doesn't exist
- [ ] AC2.6: Empty local path input shows `[!!]` and cancels
- [ ] AC2.7: Exit code parsing same as UC1 (0-3/4-7/8+)

### Error Scenarios
| Scenario | Expected Behavior | ERRORLEVEL/Flag |
|---|---|---|
| Empty local save path | `[!!]` cancel, return to menu | N/A |
| Remote share empty (0 folders) | Empty listing, user can enter custom path | N/A |
| Invalid folder selection | `[!!]` Invalid, 2s timeout, re-prompt | N/A |
| Network drop during pull | Auto-resume via `/Z` | Robocopy handles |

---

## UC3: Backup LOCAL (Local --> Local)

**As a** user,
**I want to** backup data between local drives (e.g., C: --> E:),
**So that** I have a quick local copy without network setup.

### Preconditions
- PC runs Windows 7+ with Administrator privileges
- Destination drive has sufficient free space
- Source and destination are DIFFERENT paths

### Flow
1. User selects **[3] Backup LOCAL** from Main Menu.
2. User enters destination path (e.g., `E:\Backup`).
3. Auto-detection of profiles and partitions (same as UC1 step 7).
4. User selects source(s) and confirms.
5. Robocopy executes with appropriate flags.
6. **No network setup or cleanup required.**

### Postconditions
- Destination contains mirror of selected source(s)
- Log file created at `logs/RS_<timestamp>.log`
- No network state modified (Tier 2a untouched)

### Acceptance Criteria
- [ ] AC3.1: No network setup prompt appears
- [ ] AC3.2: Source selection identical to UC1 (profiles, partitions, custom, ALL)
- [ ] AC3.3: USB drives detected and use `/MT:8` (not `/MT:16`)
- [ ] AC3.4: Empty destination path shows `[!!]` and returns to MainMenu
- [ ] AC3.5: Source = Destination guard prevents self-copy
- [ ] AC3.6: Fastest path (no network latency)

### Error Scenarios
| Scenario | Expected Behavior | ERRORLEVEL/Flag |
|---|---|---|
| Empty dest path | `[!!]` PAUSE, return to MainMenu | N/A |
| Source = Destination | `[!!]` abort, LAST_RC_CODE=99 | LAST_RC_STATUS=FAILED |
| Dest drive full | Robocopy exit code 8+ | LAST_RC_STATUS=FAILED |
| Dest drive removed mid-copy | Robocopy exit code 8+ | LAST_RC_STATUS=FAILED |

---

## UC4: Restore into Existing Profile (Merge)

**As a** technician restoring a user's data,
**I want to** merge backed-up folders into an existing Windows profile,
**So that** the user gets their files back WITHOUT losing new files they've created since the backup.

### Preconditions
- Backup exists (local folder or network share) with profile subfolder structure
- Target PC has at least one user profile under `C:\Users\`
- Backup contains recognizable subfolders (Desktop, Documents, Downloads, etc.)
- Administrator privileges on target PC

### Flow
1. User selects **[4] Restore Profile** --> **[A] Restore into existing Profile**.
2. User enters or browses to backup source location (local or network).
3. System lists available backup profiles (folders in backup path).
4. User selects which backup to restore.
5. System detects target profiles on the local machine (`C:\Users\*`).
6. User selects target profile.
7. System detects restorable subfolders: Desktop, Documents, Downloads, Pictures, Videos, Music, Favorites, Links, Contacts, AppData\Roaming.
8. Confirmation screen shows: backup source, target profile, mode (MERGE), and folder list.
9. Robocopy restores **each subfolder individually** with `/E` (copy without deleting).
10. **Critical**: `/E` mode does NOT delete new files at destination. User's new work is preserved.

### Postconditions
- Each subfolder restored from backup to target profile
- Existing user files at destination are PRESERVED (not deleted)
- New files from backup are added alongside existing files
- Log files created for each subfolder restore operation
- No ntuser.dat or system files touched

### Robocopy Flags
`/E /Z /MT:16 /R:2 /W:1 /NP /ETA`

### Acceptance Criteria
- [ ] AC4.1: `/E` used (NOT `/MIR`) -- existing files at dest are preserved
- [ ] AC4.2: Each subfolder (Desktop, Documents, etc.) restored individually
- [ ] AC4.3: User's new files created after backup are NOT deleted
- [ ] AC4.4: Backup files are added/overwritten at destination
- [ ] AC4.5: Confirmation screen shows source, target, mode=MERGE, folder list
- [ ] AC4.6: Profile detection lists all non-system profiles
- [ ] AC4.7: Subfolder detection handles `AppData\Roaming` (backslash in name)
- [ ] AC4.8: No profiles found on PC --> `[!!]` abort with PAUSE
- [ ] AC4.9: Empty backup (0 subfolders) --> `[!!]` abort with PAUSE
- [ ] AC4.10: User can cancel at confirmation (N) and re-select

### Error Scenarios
| Scenario | Expected Behavior | ERRORLEVEL/Flag |
|---|---|---|
| No profiles on local PC | `[!!]` PAUSE, return to source selection | PROFILE_COUNT=0 |
| Empty backup (0 subfolders) | `[!!]` PAUSE, return to source selection | SUBDIR_COUNT=0 |
| Invalid profile selection | `[!!]` Invalid, 2s timeout, re-prompt | N/A |
| Backup path doesn't exist | `[!!]` PAUSE, return to Restore menu | N/A |
| AppData\Roaming subfolder | Handled via string variable (no path parsing bug) | N/A |

---

## UC5: Restore to Designated Path (Mirror)

**As a** technician,
**I want to** make a full mirror copy of a backup to a specified folder,
**So that** I get an exact replica of the backed-up data.

### Preconditions
- Backup exists (selected from UC4 source selection flow)
- Destination path is writable
- User understands that `/MIR` DELETES extra files at destination

### Flow
1. User selects **[4] Restore Profile** --> **[B] Restore to designated path**.
2. User enters destination path (e.g., `D:\Restored\Admin`).
3. Confirmation screen shows source, dest, mode (MIRROR).
4. Robocopy copies with `/MIR` -- this WILL delete files at destination that aren't in source.

### Postconditions
- Destination is an exact mirror of the backup source
- Extra files at destination (not in backup) are DELETED
- Log file created at `logs/RS_<timestamp>.log`

### Robocopy Flags
`/MIR /Z /MT:16 /R:2 /W:1 /NP /ETA` + `$Recycle.Bin` exclusion

### Acceptance Criteria
- [ ] AC5.1: `/MIR` used (full mirror, extras deleted)
- [ ] AC5.2: Confirmation screen clearly shows mode=MIRROR
- [ ] AC5.3: User can cancel at confirmation (N)
- [ ] AC5.4: Empty destination path shows `[!!]` and returns
- [ ] AC5.5: Destination auto-created if it doesn't exist
- [ ] AC5.6: `$Recycle.Bin` excluded from mirror

### Error Scenarios
| Scenario | Expected Behavior | ERRORLEVEL/Flag |
|---|---|---|
| Empty dest path | `[!!]` PAUSE, return to source selection | N/A |
| Dest has existing files | Files NOT in backup are DELETED (by design) | N/A |
| Dest drive full | Robocopy exit code 8+ | LAST_RC_STATUS=FAILED |

### Warning
`/MIR` is destructive. Extra files at destination ARE deleted. This is by design for full mirror restore.

---

## UC6: Network Setup (Standalone)

**As a** technician,
**I want to** configure the network connection independently of a backup operation,
**So that** I can verify connectivity before starting a backup.

### Preconditions
- Ethernet cable connected (Direct Cable) OR both PCs on same LAN (DHCP)
- Remote PC has valid credentials
- Administrator privileges (for `netsh` in Direct Cable mode)

### Flow
1. User selects **[5] Network Setup** from Main Menu.
2. Options:
   - **[1] Connect via Direct Cable**: Set static IP, enter credentials, ping, authenticate.
   - **[2] Connect via Existing Network (DHCP)**: Enter credentials, ping, authenticate.
   - **[3] Disconnect & Reset**: Clear all connections, restore DHCP.
   - **[4] Show Connection Status**: Display current network state.
3. Network state persists across backup operations (Tier 2a -- session vars NOT cleared at MainMenu).
4. Subsequent PUSH/PULL operations can reuse the existing connection.

### Postconditions
- On successful connect: `NET_STATUS=CONNECTED`, `NETWORK_PATH=\\IP\Share`
- On disconnect: All network vars cleared, DHCP restored, `NET_STATUS=NOT_CONNECTED`
- Network state persists across MainMenu returns (Tier 2a)

### Acceptance Criteria
- [ ] AC6.1: Direct Cable sets static IP via `netsh` on selected interface
- [ ] AC6.2: DHCP mode skips static IP setup
- [ ] AC6.3: Ping verifies reachability before authentication
- [ ] AC6.4: Password cleared immediately after `net use` (zero-leak)
- [ ] AC6.5: Connection status shows IP, user, mode, interface
- [ ] AC6.6: Disconnect clears ALL network vars and restores DHCP
- [ ] AC6.7: Network persists across backup operations (Tier 2a scoping)
- [ ] AC6.8: PUSH/PULL can skip network setup if already connected

### Error Scenarios
| Scenario | Expected Behavior | ERRORLEVEL/Flag |
|---|---|---|
| Empty IP or username | `[!!]` Invalid input, PAUSE | INPUT_OK=0 |
| Ping fails (no reply) | `[!!]` Cannot reach, PAUSE | NET_PING_OK=0 |
| Auth fails (wrong creds) | `[!!]` Auth failed, PAUSE | NET_MAP_OK=0 |
| Direct Cable setup fails | `[!!]` Setup failed, PAUSE | DIRECT_SETUP_OK=0 |
| No network interface found | `[!!]` PAUSE, return to menu | N/A |

---

## Cross-Cutting Concerns

### Security
- Passwords cleared immediately after `net use` (`set "NET_PASS="`)
- Admin elevation required (UAC prompt via `cscript //nologo`)
- No passwords stored in logs or environment after use
- `NET_PASS` is the ONLY sensitive variable; all others are safe to persist

### Unicode Support
- `chcp 65001` at startup
- All path variables in double quotes (`"!VAR!"`)
- Vietnamese folder/file names fully supported

### Error Handling
- **ERRORLEVEL-driven**: Flag variables are the only reliable communication channel
- **Fail-fast**: Empty inputs abort immediately with `[!!]` message
- **Pre-flight validation**: Paths verified before robocopy execution
- **Exit code parsing**: 0-3=SUCCESS, 4-7=WARNING (pause), 8+=FAILED (pause)
- **Source=Destination guard**: Prevents self-copy (v2.0.0+)
- **Error loud**: Every error shows `[!!]` prefix with context

### Cleanup
- Network connections unmapped on exit or menu return
- DHCP restored on Direct Cable interfaces
- Pipeline variables cleared at MainMenu (Tier 2b/3 scoping)
- Session variables (Tier 2a) persist until explicit disconnect or exit

### Logging
- Every robocopy execution creates a log at `logs/RS_<timestamp>.log`
- Log includes `/TEE` (console + file) and `/V` (verbose) output
- Timestamp format: `YYYYMMDD_HHMMSS`
- Log survives across operations; new log per execution
