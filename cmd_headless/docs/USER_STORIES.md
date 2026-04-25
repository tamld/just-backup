# User Stories — RoboSync CMD Headless

## Overview

This document defines the formal user stories (Use Cases) for the RoboSync CMD Headless backup and restore tool. Each story maps to a specific operation mode in the application.

---

## UC1: Backup PUSH (Local → Remote)

**As a** technician backing up a user's PC,
**I want to** copy local data to a remote machine over SMB,
**So that** the data is safely stored on a network share or another PC.

### Flow
1. User selects **[1] Backup PUSH** from Main Menu.
2. System prompts for network type: Direct Cable (static IP) or DHCP.
3. If Direct Cable: system sets static IP on selected interface.
4. User enters remote IP, share name, username, password.
5. System pings remote host → maps credentials via `net use`.
6. Password is **cleared immediately** after `net use` (zero-leak).
7. System auto-detects local profiles (`C:\Users\*`) and partitions (D-Z drives).
8. User selects source(s): single profile, single partition, custom path, ALL profiles, or ALL partitions.
9. System confirms source → destination → type, asks Y/N.
10. Robocopy executes with appropriate flags (`/MIR /Z /MT:16` for network).
11. Exit code parsed: 0-3=SUCCESS, 4-7=WARNING (pause), 8+=FAILED (pause).
12. User can select another source or go back to Main Menu.
13. On exit: `net use` unmapped, DHCP restored if Direct Cable was used.

### Robocopy Flags by Source Type
| Source Type | Key Flags |
|---|---|
| PROFILE | `/MIR /ZB /XJ` + profile exclusions (cache, temp, browser data) |
| PARTITION | `/MIR /Z` + system file exclusions (pagefile, hiberfil, $Recycle.Bin) |
| USB | `/MIR /MT:8 /R:1 /W:0` (reduced threads for removable media) |
| CUSTOM | `/MIR /Z /MT:16` + $Recycle.Bin exclusion |

### Edge Cases
- Empty source/dest path → abort with `[!!]` message
- Source path doesn't exist → abort
- Source = Destination → abort (v2.0.0+)
- Network drop mid-copy → `/Z` restartable mode resumes automatically
- Outlook running → warning logged (PST/OST may be locked)

---

## UC2: Backup PULL (Remote → Local)

**As a** technician,
**I want to** pull data from a remote machine to local storage,
**So that** I can consolidate backups from multiple PCs.

### Flow
1. User selects **[2] Backup PULL** from Main Menu.
2. Network setup (same as UC1 steps 2-5).
3. User enters local save path (e.g., `D:\Restore`).
4. System lists remote folders on the network share.
5. User selects: specific folder, custom remote path, or ENTIRE share.
6. Robocopy copies remote → local with CUSTOM flags.
7. Exit code parsed, pause on warning/failure.

### Key Differences from UC1
- Source is remote (UNC path), destination is local.
- Cannot classify remote drive types (no `fsutil` over SMB).
- Remote folders listed via `for /d` only.

---

## UC3: Backup LOCAL (Local → Local)

**As a** user,
**I want to** backup data between local drives (e.g., C: → E:),
**So that** I have a quick local copy without network setup.

### Flow
1. User selects **[3] Backup LOCAL** from Main Menu.
2. User enters destination path (e.g., `E:\Backup`).
3. Auto-detection of profiles and partitions (same as UC1 step 7).
4. User selects source(s) and confirms.
5. Robocopy executes with appropriate flags.
6. **No network setup or cleanup required.**

---

## UC4: Restore into Existing Profile (Merge)

**As a** technician restoring a user's data,
**I want to** merge backed-up folders into an existing Windows profile,
**So that** the user gets their files back WITHOUT losing new files they've created since the backup.

### Flow
1. User selects **[4] Restore Profile** → **[A] Restore into existing Profile**.
2. User enters or browses to backup source location (local or network).
3. System lists available backup profiles.
4. User selects which backup to restore.
5. System detects target profiles on the local machine.
6. User selects target profile.
7. System detects restorable subfolders: Desktop, Documents, Downloads, Pictures, Videos, Music, Favorites, Links, Contacts, AppData\Roaming.
8. Confirmation screen shows: backup source, target profile, mode (MERGE), and folder list.
9. Robocopy restores **each subfolder individually** with `/E` (copy without deleting).
10. **Critical**: `/E` mode does NOT delete new files at destination. User's new work is preserved.

### Robocopy Flags
`/E /Z /MT:16 /R:2 /W:1 /NP /ETA`

### Edge Cases
- No profiles found on local machine → abort
- Empty backup (no known subfolders) → `SUBDIR_COUNT=0`, abort
- `AppData\Roaming` has backslash in name → handled correctly via string variable

---

## UC5: Restore to Designated Path (Mirror)

**As a** technician,
**I want to** make a full mirror copy of a backup to a specified folder,
**So that** I get an exact replica of the backed-up data.

### Flow
1. User selects **[4] Restore Profile** → **[B] Restore to designated path**.
2. User enters destination path (e.g., `D:\Restored\Admin`).
3. Confirmation screen shows source, dest, mode (MIRROR).
4. Robocopy copies with `/MIR` — this WILL delete files at destination that aren't in source.

### Robocopy Flags
`/MIR /Z /MT:16 /R:2 /W:1 /NP /ETA` + `$Recycle.Bin` exclusion

### Warning
⚠️ `/MIR` is destructive. Extra files at destination ARE deleted. This is by design for full mirror restore.

---

## UC6: Network Setup (Standalone)

**As a** technician,
**I want to** configure the network connection independently of a backup operation,
**So that** I can verify connectivity before starting a backup.

### Flow
1. User selects **[5] Network Setup** from Main Menu.
2. Options:
   - **[1] Connect via Direct Cable**: Set static IP, enter credentials, ping, authenticate.
   - **[2] Connect via Existing Network (DHCP)**: Enter credentials, ping, authenticate.
   - **[3] Disconnect & Reset**: Clear all connections, restore DHCP.
   - **[4] Show Connection Status**: Display current network state.
3. Network state persists across backup operations (Tier 2a — session vars NOT cleared at MainMenu).
4. Subsequent PUSH/PULL operations can skip network setup if already connected.

---

## Cross-Cutting Concerns

### Security
- Passwords cleared immediately after `net use` (`set "NET_PASS="`)
- Admin elevation required (UAC prompt via `cscript //nologo`)
- No passwords stored in logs or environment after use

### Unicode Support
- `chcp 65001` at startup
- All path variables in double quotes
- Vietnamese folder/file names fully supported

### Error Handling
- **Fail-Fast**: Empty inputs abort immediately with `[!!]` message
- **Pre-flight validation**: Paths verified before robocopy execution
- **Exit code parsing**: 0-3=SUCCESS, 4-7=WARNING (pause), 8+=FAILED (pause)
- **Source=Destination guard**: Prevents self-copy (v2.0.0+)

### Cleanup
- Network connections unmapped on exit or menu return
- DHCP restored on Direct Cable interfaces
- Pipeline variables cleared at MainMenu (Tier 2 scoping)
