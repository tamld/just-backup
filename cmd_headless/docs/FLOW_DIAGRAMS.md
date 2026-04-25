# RoboSync -- Flow Diagrams & Decision Trees

> **Perspective**: Business Analyst designing for end-users (IT technicians, helpdesk staff)
> in enterprise environments with restricted Windows policies.

---

## 1. Master Flow -- Application Lifecycle

```
  ╔══════════════════════════════════════════════════════════╗
  ║              USER DOUBLE-CLICKS RoboSync.bat            ║
  ╚══════════════════════════╦═══════════════════════════════╝
                             ▼
                   ┌─────────────────┐
                   │  Is Admin?       │
                   │  (cacls.exe test)│
                   └────────┬────────┘
                       ╱         ╲
                    YES            NO
                     │              │
                     │    ┌─────────▼──────────┐
                     │    │ UAC Prompt via VBS  │
                     │    │ (cscript //nologo)  │
                     │    └─────────┬──────────┘
                     │          ╱        ╲
                     │      ACCEPT     DENY
                     │         │          │
                     │         │    ┌─────▼──────┐
                     │         │    │ App Closes  │
                     │         │    │ (no access) │
                     │         │    └─────────────┘
                     ▼         ▼
              ┌────────────────────────┐
              │     BOOTSTRAP          │
              │  chcp 65001 (Unicode)  │
              │  Set Tier 1 Globals    │
              │  Verify lib/*.bat      │
              └───────────┬────────────┘
                          ▼
              ╔══════════════════════╗
              ║     MAIN MENU       ║◄─────────────────────────┐
              ║  (Pipeline Clear)   ║                          │
              ╠══════════════════════╣                          │
              ║ [1] Backup PUSH     ║──► UC1                   │
              ║ [2] Backup PULL     ║──► UC2                   │
              ║ [3] Backup LOCAL    ║──► UC3                   │
              ║ [4] Restore Profile ║──► UC4/UC5               │
              ║ [5] Network Setup   ║──► UC6          Return   │
              ║ [6] Exit            ║──► Cleanup & Quit  ──────┘
              ║                     ║     (only Exit
              ║ [Status Bar]        ║      leaves loop)
              ╚══════════════════════╝
```

**BA Decision**: The Main Menu is the **single entry point** and **safe harbor**.
Every operation returns here. Pipeline vars are cleared on re-entry,
preventing stale state from a previous operation contaminating the next one.

---

## 2. UC1: Backup PUSH (Local --> Remote)

**User Story**: "I'm at a user's desk. I need to push their profile/data to our file server before reimaging."

```
  MAIN MENU ─[1]─► PUSH
                     │
           ┌─────────▼──────────┐
           │  NETWORK SETUP     │ (shared with PULL)
           │  (see Section 7)   │
           └─────────┬──────────┘
                ╱         ╲
            SUCCESS      FAIL
               │           │
               │     ┌─────▼──────┐
               │     │ PAUSE      │
               │     │ Show error │
               │     │ Return     │
               │     └──────┬─────┘
               │            ▼
               │       MAIN MENU
               ▼
     ┌──────────────────────┐
     │  SELECT SOURCE       │◄─────────────────────┐
     │  Auto-detect:        │                       │
     │  - User Profiles     │                       │
     │  - Data Drives       │                       │
     │  - USB Drives        │              Another  │
     │                      │              source?  │
     │  Options:            │                       │
     │  [1..N] Pick one     │                       │
     │  [N+1] Custom path   │                       │
     │  [N+2] ALL Profiles  │                       │
     │  [N+3] ALL Partitions│                       │
     │  [0]   Go back       │                       │
     └────────┬─────────────┘                       │
              │                                     │
         ╔════╧═════╗                               │
         ║ DECISION ║                               │
         ╚════╤═════╝                               │
          ╱   │   ╲    ╲                            │
    Single  Custom ALL_P  ALL_D                     │
       │      │     │       │                       │
       ▼      │     │       │                       │
  ┌────────┐  │     │       │                       │
  │CONFIRM │  │     │       │                       │
  │Src/Dst │  │     │       │                       │
  │Type    │  │     │       │                       │
  │[Y/N]?  │  │     │       │                       │
  └───┬────┘  │     │       │                       │
    ╱   ╲     │     │       │                       │
  YES    NO   │     │       │                       │
   │     │    │     │       │                       │
   │     └────┼─────┼───────┼───────────────────────┘
   ▼          ▼     ▼       ▼
┌──────────────────────────────────┐
│         ROBOCOPY ENGINE          │
│  fn_build_flags(TYPE)            │
│  Type-specific flags applied     │
│  Log file created                │
│  /Z = auto-resume on disconnect  │
└──────────────┬───────────────────┘
               │
         ╔═════╧══════╗
         ║ EXIT CODE  ║
         ╚═════╤══════╝
          ╱    │     ╲
       0-3    4-7    8+
        │      │      │
   ┌────▼─┐ ┌─▼───┐ ┌▼─────┐
   │ [OK] │ │[!!] │ │[!!]  │
   │  No  │ │WARN │ │FAIL  │
   │pause │ │PAUSE│ │PAUSE │
   └──┬───┘ └──┬──┘ └──┬───┘
      └────────┴────────┘
               │
               ▼
         Back to SELECT SOURCE ──────────────────────┘
```

### BA Notes -- UC1
| Concern | Design Decision | Rationale |
|---|---|---|
| User picks wrong source | Confirmation screen (Y/N) before execution | Prevents accidental backup of system drive |
| Network drops mid-copy | `/Z` restartable mode auto-resumes | No user action needed; robocopy bookmarks byte position |
| User wants ALL profiles | Batch loop option (`ALL Profiles`) | Saves 5+ manual selections in multi-user PCs |
| Password leak | `NET_PASS` cleared immediately after `net use` | Zero-leak pattern; password never persists in env |

---

## 3. UC2: Backup PULL (Remote --> Local)

**User Story**: "I'm at a clean PC. I need to pull data from the old machine (connected via cable or LAN)."

```
  MAIN MENU ─[2]─► PULL
                     │
           ┌─────────▼──────────┐
           │  NETWORK SETUP     │
           └─────────┬──────────┘
                ╱         ╲
            SUCCESS      FAIL ──► PAUSE ──► MAIN MENU
               │
         ┌─────▼──────────┐
         │ Enter local     │
         │ save path       │
         │ e.g. D:\Restore │
         └─────┬───────────┘
           ╱       ╲
        empty    has path
          │         │
    ┌─────▼───┐     ▼
    │Cancel   │ ┌───────────────────┐
    │Cleanup  │ │ SELECT REMOTE SRC │◄────────────────┐
    │MainMenu │ │ List remote dirs  │                  │
    └─────────┘ │                   │                  │
                │ [1..N] Folder     │        Another   │
                │ [N+1] Custom path │        source?   │
                │ [N+2] ENTIRE share│                  │
                │ [0]   Go back     │                  │
                └────────┬──────────┘                  │
                         │                             │
                    ╔════╧═════╗                       │
                    ║ DECISION ║                       │
                    ╚════╤═════╝                       │
                   ╱     │     ╲                       │
              Folder  Custom  Entire                   │
                 │      │       │                      │
                 ▼      ▼       ▼                      │
           ┌────────────────────────┐                  │
           │   ROBOCOPY ENGINE     │                  │
           │   (CUSTOM type flags)  │                  │
           └────────────┬───────────┘                  │
                        ▼                              │
                  Exit Code Parse ─────────────────────┘
```

### BA Notes -- UC2
| Concern | Design Decision | Rationale |
|---|---|---|
| Can't classify remote drives | All remote sources treated as CUSTOM type | `fsutil` doesn't work over SMB |
| User wants everything | "ENTIRE share" option copies full `\\IP\Share\` | One-click full backup for small shares |
| Destination doesn't exist | Auto-mkdir before robocopy | Reduces user friction |

---

## 4. UC3: Backup LOCAL (Local --> Local)

**User Story**: "I just want to copy my profile to an external hard drive. No network needed."

```
  MAIN MENU ─[3]─► LOCAL
                     │
               ┌─────▼───────────┐
               │ Enter dest path  │
               │ e.g. E:\Backup   │
               └─────┬───────────┘
                 ╱       ╲
              empty    has path
                │         │
          ┌─────▼───┐     ▼
          │PAUSE    │  SELECT SOURCE
          │MainMenu │  (same as UC1)
          └─────────┘     │
                          ▼
                    Confirm ──► Engine ──► Loop
```

### BA Notes -- UC3
| Concern | Design Decision | Rationale |
|---|---|---|
| No network needed | Skip entire NetworkSetup flow | Fastest path for local backup |
| USB detection | `fsutil` identifies USB drives -> `/MT:8` | Slower write speed on USB = fewer threads |
| Same as PUSH source selection | Reuse `:SelectSource` flow | Consistency; user learns one UI pattern |

---

## 5. UC4: Restore into Existing Profile (Merge)

**User Story**: "User got a new PC. I need to restore their Desktop, Documents, etc. WITHOUT deleting their new files."

```
  MAIN MENU ─[4]─► RESTORE
                     │
               ┌─────▼──────────────┐
               │ Choose source type  │
               │ [1] Local folder    │
               │ [2] Network folder  │
               │ [0] Go back         │
               └─────┬──────────────┘
                ╱     │     ╲
             Local  Network  Back
               │      │       │
               │  ┌───▼───┐   ▼
               │  │Network│  MainMenu
               │  │Setup  │
               │  └───┬───┘
               │      │
               ▼      ▼
          ┌────────────────────┐
          │ Enter/browse       │
          │ backup folder path │
          └─────────┬──────────┘
               ╱         ╲
           empty      valid path
             │             │
        ┌────▼────┐        ▼
        │ PAUSE   │  ┌──────────────────┐
        │ Retry   │  │ LIST BACKUP      │
        └─────────┘  │ PROFILES         │◄──────────────┐
                     │ [1..N] profile    │               │
                     │ [0] Go back       │               │
                     └────────┬──────────┘               │
                              │                          │
                              ▼                          │
                   ┌────────────────────┐                │
                   │ Choose restore mode│                │
                   │ [A] Into Profile   │                │
                   │     (MERGE /E)     │                │
                   │ [B] To custom path │                │
                   │     (MIRROR /MIR)  │                │
                   │ [0] Go back        │                │
                   └─────────┬──────────┘                │
                        ╱         ╲                      │
                    [A] MERGE    [B] MIRROR               │
                       │              │                  │
                       ▼              ▼                  │
                   (UC4 flow)    (UC5 flow)              │
                       │                                 │
               ┌───────▼──────────┐                      │
               │ Detect LOCAL     │                      │
               │ profiles on PC   │                      │
               │ (C:\Users\*)     │                      │
               └───────┬──────────┘                      │
                  ╱         ╲                            │
              found=0     found>0                        │
                │             │                          │
          ┌─────▼────┐        ▼                          │
          │No profile│  ┌───────────────┐                │
          │PAUSE     │  │Choose target  │                │
          │Back      │  │profile        │                │
          └──────────┘  │[1] Admin      │                │
                        │[2] User1 ...  │                │
                        └───────┬───────┘                │
                                │                        │
                        ┌───────▼───────────┐            │
                        │ Detect subdirs    │            │
                        │ Desktop, Docs,    │            │
                        │ Downloads, Pics,  │            │
                        │ Videos, Music ... │            │
                        └───────┬───────────┘            │
                           ╱         ╲                   │
                       found=0     found>0               │
                         │             │                 │
                   ┌─────▼────┐        ▼                 │
                   │No subdirs│  ┌──────────────┐        │
                   │PAUSE     │  │ CONFIRM      │        │
                   │Back      │  │ Src->Profile │        │
                   └──────────┘  │ Mode: MERGE  │        │
                                 │ Folders: ... │        │
                                 │ [Y/N]?       │        │
                                 └──────┬───────┘        │
                                   ╱         ╲           │
                                 YES          NO ────────┘
                                  │
                          ┌───────▼────────────┐
                          │ FOR each subfolder │
                          │   robocopy /E      │
                          │   (RESTORE_MERGE)  │
                          │   NO /MIR!         │
                          └───────┬────────────┘
                                  │
                            ┌─────▼──────┐
                            │ [OK] Done  │
                            │ PAUSE      │
                            │ Back to    │
                            │ profile    │
                            │ selection  │
                            └────────────┘
```

### BA Notes -- UC4
| Concern | Design Decision | Rationale |
|---|---|---|
| User has new files on new PC | `/E` mode (NOT `/MIR`) | `/MIR` would DELETE the user's new work |
| Per-subfolder restore | Loop over Desktop, Documents, etc. individually | Avoids touching ntuser.dat or system folders |
| Wrong profile selected | Confirmation screen shows source + target + folder list | Last chance to verify before restore |
| Empty backup | `SUBDIR_COUNT=0` -> abort early | Prevents robocopy with no content |

---

## 6. UC5: Restore to Designated Path (Mirror)

**User Story**: "I want an exact copy of the backup at a specific folder. I don't care about existing files there."

```
  (from UC4 mode selection: [B])
                     │
               ┌─────▼───────────┐
               │ Enter dest path  │
               │ e.g. D:\Restored │
               └─────┬───────────┘
                 ╱       ╲
              empty    has path
                │         │
          ┌─────▼───┐     ▼
          │PAUSE    │ ┌──────────────┐
          │Retry    │ │ CONFIRM      │
          └─────────┘ │ Src -> Dest  │
                      │ Mode: MIRROR │
                      │ [Y/N]?       │
                      └──────┬───────┘
                        ╱         ╲
                      YES          NO ──► Back to profile list
                       │
                ┌──────▼──────────┐
                │ robocopy /MIR   │
                │ (RESTORE_MIRROR)│
                │ Full mirror     │
                │ DELETES extras  │
                └──────┬──────────┘
                       │
                 ┌─────▼──────┐
                 │ [OK] Done  │
                 │ PAUSE      │
                 └────────────┘
```

### BA Notes -- UC5
| Concern | Design Decision | Rationale |
|---|---|---|
| Destructive operation | `/MIR` warning in confirmation | User MUST understand extras will be deleted |
| Simpler than UC4 | Single robocopy call (no subfolder loop) | Full mirror = one command, one destination |

---

## 7. Network Setup -- Shared Decision Flow

Used by UC1 (PUSH), UC2 (PULL), and UC6 (standalone).

```
  ┌─────────────────────────────────────┐
  │ NETWORK TYPE SELECTION              │
  │                                     │
  │ [1] Direct Cable (Static IP)        │
  │     For: 2 PCs connected by         │
  │     Ethernet cable, no router       │
  │                                     │
  │ [2] Existing Network (DHCP)         │
  │     For: Both PCs already on        │
  │     same LAN/WiFi                   │
  │                                     │
  │ [0] Cancel                          │
  └──────────────┬──────────────────────┘
            ╱    │    ╲
      Direct   DHCP   Cancel
         │       │       │
         │       │    MainMenu
         │       │
         ▼       │
  ┌─────────────┐│
  │STATIC IP    ││
  │SETUP        ││
  │             ││
  │List NICs    ││
  │User picks   ││
  │interface    ││
  │             ││
  │Set IP:      ││
  │169.254.1.1  ││
  │via netsh    ││
  └──────┬──────┘│
     ╱      ╲    │
   OK      FAIL  │
    │        │    │
    │  ┌─────▼─┐ │
    │  │PAUSE  │ │
    │  │Abort  │ │
    │  └───────┘ │
    │            │
    ▼            ▼
  ┌──────────────────────────┐
  │ INPUT CREDENTIALS        │
  │                          │
  │ Enter IP:  ___________   │
  │ Enter Share: ________    │
  │ Enter User: _________   │
  │ Enter Password: ****    │
  │  (masked via PS fallback)│
  └───────────┬──────────────┘
         ╱         ╲
      valid      empty/invalid
        │             │
        │       ┌─────▼─────┐
        │       │ PAUSE     │
        │       │ "Invalid" │
        │       │ Return    │
        │       └───────────┘
        ▼
  ┌──────────────────┐
  │ PING REMOTE HOST │
  │ ping -n 2 <IP>   │
  └────────┬─────────┘
      ╱         ╲
   Reply     No reply
     │           │
     │     ┌─────▼──────────┐
     │     │ PAUSE           │
     │     │ "Cannot reach   │
     │     │  <IP>"          │
     │     │ Return          │
     │     └────────────────┘
     ▼
  ┌──────────────────────────┐
  │ MAP CREDENTIALS          │
  │ net use \\IP\Share       │
  │   /user:USER PASS        │
  │                          │
  │ *** ZERO-LEAK ***        │
  │ set "NET_PASS=" (instant)│
  └────────┬─────────────────┘
      ╱         ╲
   MAP_OK     MAP_FAIL
     │           │
     │     ┌─────▼──────┐
     │     │ PAUSE       │
     │     │ "Auth fail" │
     │     │ (wrong user │
     │     │  or pass?)  │
     │     │ Return      │
     │     └─────────────┘
     ▼
  ┌──────────────────┐
  │ [OK] CONNECTED   │
  │ NETWORK_PATH set │
  │ Continue to      │
  │ backup flow      │
  └──────────────────┘
```

### BA Notes -- Network
| Concern | Design Decision | Rationale |
|---|---|---|
| Enterprise blocks PowerShell | Password mask uses PS one-liner with plaintext fallback | Works even if PS execution policy blocks scripts |
| Direct cable (no router) | Auto-set `169.254.1.1/24` via `netsh` | Both PCs need static IPs in same subnet |
| DHCP restore on exit | `fn_restore_dhcp` called at cleanup | Don't leave the user's NIC misconfigured |
| Credential failure | Separate PAUSE at each step | User sees EXACTLY which step failed |

---

## 8. UC6: Network Setup (Standalone)

**User Story**: "I want to verify my network connection works before starting any backup."

```
  MAIN MENU ─[5]─► NETWORK SETUP MENU
                          │
                ┌─────────▼──────────────┐
                │ [Status Bar shown]      │
                │                         │
                │ [1] Connect Direct Cable│
                │ [2] Connect DHCP        │──► Same as Section 7
                │ [3] Disconnect & Reset  │    (Network flow)
                │ [4] Show Status         │
                │ [0] Back to Main Menu   │
                └──────────┬──────────────┘
                      ╱    │    ╲     ╲
                   [1/2]  [3]   [4]   [0]
                     │     │     │      │
                     │     ▼     ▼      ▼
                     │  ┌──────┐ Show  MainMenu
                     │  │Clear │ status
                     │  │all   │ details
                     │  │vars  │
                     │  │DHCP  │
                     │  │reset │
                     │  │[OK]  │
                     │  └──┬───┘
                     │     │
                     ▼     ▼
                  NetworkMenu ◄──── (loop back)
```

### BA Notes -- UC6
| Concern | Design Decision | Rationale |
|---|---|---|
| Network persists across modes | Tier 2a vars NOT cleared at MainMenu | Connect once, backup multiple times |
| Clean disconnect | [3] clears ALL network vars + restores DHCP | No stale connections left behind |
| Pre-flight verification | [4] shows IP, user, mode, interface | User confirms config before backup |

---

## 9. Error Handling -- Master Decision Tree

```
  ╔═══════════════════════════════════════════════════════════╗
  ║                 ERROR CLASSIFICATION                     ║
  ╠═══════════════════════════════════════════════════════════╣
  ║                                                          ║
  ║  INPUT ERROR (empty path, invalid selection)             ║
  ║  ├── Action: PAUSE with [!!] message                     ║
  ║  ├── Recovery: User re-enters input                      ║
  ║  └── Flow: Return to previous menu                       ║
  ║                                                          ║
  ║  PRE-FLIGHT ERROR (ping fail, auth fail, path missing)   ║
  ║  ├── Action: PAUSE with specific error context           ║
  ║  ├── Recovery: User fixes config (IP, creds, cable)      ║
  ║  └── Flow: Return to network/source menu                 ║
  ║                                                          ║
  ║  EXECUTION WARNING (robocopy exit 4-7)                   ║
  ║  ├── Action: PAUSE -- "Some files not copied"            ║
  ║  ├── Recovery: User reviews log, re-runs if needed       ║
  ║  └── Flow: Back to source selection (can retry)          ║
  ║                                                          ║
  ║  EXECUTION FAILURE (robocopy exit 8+)                    ║
  ║  ├── Action: PAUSE -- "CRITICAL ERROR"                   ║
  ║  ├── Recovery: User checks log for cause                 ║
  ║  └── Flow: Back to source selection                      ║
  ║                                                          ║
  ║  GUARD FAILURE (source=dest, module missing)             ║
  ║  ├── Action: ABORT with [!!] message, LAST_RC_CODE=99    ║
  ║  ├── Recovery: User corrects the configuration           ║
  ║  └── Flow: Return to caller                              ║
  ║                                                          ║
  ╚═══════════════════════════════════════════════════════════╝
```

---

## 10. State Lifecycle -- Variable Scoping Visualized

```
  APP START
    │
    ▼
  ┌──────────────────────────────────────────────┐
  │ TIER 1: GLOBAL (immortal)                    │
  │ APP_VERSION, SCRIPT_DIR, LIBS, LOG_DIR       │
  │ ─────────────────────────────────────────     │
  │ Set once. Never cleared. Never overwritten.   │
  └──────────────────────────────────────────────┘
    │
    ▼
  ┌──────────────────────────────────────────────┐
  │ TIER 2a: SESSION (persist across modes)      │
  │ DEST_IP, NET_USER, NETWORK_PATH, NET_STATUS  │
  │ NET_TYPE, NET_IFACE, NET_LOCAL_IP            │
  │ ─────────────────────────────────────────     │
  │ Set during Network Setup.                     │
  │ Cleared ONLY by [3] Disconnect or Exit.       │
  │ Survives MainMenu pipeline clear.             │
  └──────────────────────────────────────────────┘
    │
    ▼
  ┌──────────────────────────────────────────────┐
  │ TIER 2b: PIPELINE (per-job)                  │
  │ BACKUP_MODE, BACKUP_DEST, NET_PASS           │
  │ ─────────────────────────────────────────     │
  │ Set at mode entry (PUSH/PULL/LOCAL).          │
  │ Cleared at :MainMenu on every return.         │
  │ NET_PASS cleared IMMEDIATELY after net use.   │
  └──────────────────────────────────────────────┘
    │
    ▼
  ┌──────────────────────────────────────────────┐
  │ TIER 3: SELECTED (ephemeral)                 │
  │ SELECTED_SRC, SELECTED_NAME, SELECTED_TYPE   │
  │ FINAL_DEST                                   │
  │ ─────────────────────────────────────────     │
  │ Set when user picks a source.                 │
  │ Overwritten on next selection.                │
  │ Cleared at :MainMenu.                         │
  └──────────────────────────────────────────────┘
    │
    ▼
  ┌──────────────────────────────────────────────┐
  │ LOCAL: _prefix vars (function-scoped)        │
  │ _rc_src, _idx, _btype, _p, _n, _custom ...  │
  │ ─────────────────────────────────────────     │
  │ Die at goto :eof (function return).           │
  │ Convention only -- CMD has no real scope.      │
  └──────────────────────────────────────────────┘
```

---

## 11. Typical User Journeys (Happy Path Scenarios)

### Journey A: "Backup one user before reimage" (most common)
```
  Start --> [1] PUSH --> Direct Cable --> Enter creds -->
  Ping OK --> Map OK --> Select "Admin" profile -->
  Confirm Y --> Robocopy runs --> [OK] Code=1 -->
  [0] Go back --> [6] Exit
  
  Time: ~5 min for 10GB profile over gigabit Ethernet
```

### Journey B: "Backup everything, go to lunch"
```
  Start --> [1] PUSH --> DHCP --> Enter creds -->
  Ping OK --> Map OK --> Select "ALL Profiles" -->
  Robocopy loops through 4 profiles --> [OK] -->
  Select "ALL Partitions" --> Robocopy loops through 2 drives -->
  [OK] --> [0] Go back --> [6] Exit
  
  Time: ~30 min for 50GB total
```

### Journey C: "Restore to new PC"
```
  Start --> [4] Restore --> [1] Local folder -->
  Enter E:\Backup --> Select "Admin" backup -->
  [A] Into existing profile --> Select "NewAdmin" -->
  Confirm Y --> Robocopy /E per subfolder -->
  [OK] --> [6] Exit
  
  Time: ~8 min for 10GB profile
```

### Journey D: "Quick local backup to USB"
```
  Start --> [3] LOCAL --> Enter F:\Backup -->
  Select USB drive (auto-detected as USB) -->
  Confirm Y --> Robocopy /MT:8 --> [OK] -->
  [6] Exit
  
  Time: ~15 min for 20GB over USB 3.0
```

### Journey E: "Pre-verify network before backup"
```
  Start --> [5] Network Setup --> [1] Direct Cable -->
  Setup IP --> Enter creds --> Ping OK --> Map OK -->
  [4] Show Status --> Verify all OK -->
  [0] Back to Main Menu --> [1] PUSH -->
  (skips network setup -- already connected) -->
  Select source --> Backup
```

---

## 12. ERRORLEVEL Decision Chains

CMD has no exceptions, no try/catch, no return values from functions.
**ERRORLEVEL is the only reliable communication channel.**

### Why Not STDOUT?

```
  stdout parsing (for /f)         vs     ERRORLEVEL
  ─────────────────────────              ────────────────
  Breaks on ! % ^ & > < |               Always an integer
  Requires escape gymnastics             Survives all chars
  for /f "delims=" is fragile            if !RC! LEQ 3 is solid
  Result lost after next command         Capture: set "RC=!errorlevel!"
```

### The Network Setup Decision Chain

```
  ┌───────────────────┐
  │fn_input_credentials│
  └─────────┬─────────┘
            │
       INPUT_OK?
       ╱        ╲
     =1          =0
      │           │
      ▼     ┌─────▼───────────────┐
      │     │ [!!] Invalid input  │
      │     │ PAUSE               │
      │     │ goto :CleanupAndMenu│
      │     └─────────────────────┘
      │
  ┌───▼───────────────┐
  │fn_test_connection  │
  │  ping -n 2 <IP>    │
  │  ERRORLEVEL 0=reply│
  └─────────┬─────────┘
            │
      NET_PING_OK?
       ╱        ╲
     =1          =0
      │           │
      ▼     ┌─────▼───────────────┐
      │     │ [!!] Cannot reach   │
      │     │ PAUSE               │
      │     │ goto :CleanupAndMenu│
      │     └─────────────────────┘
      │
  ┌───▼───────────────┐
  │fn_map_credentials  │
  │  net use \\IP\Share│
  │  ERRORLEVEL 0=OK   │
  └─────────┬─────────┘
            │
      NET_MAP_OK?
       ╱        ╲
     =1          =0
      │           │
      ▼     ┌─────▼───────────────┐
      │     │ [!!] Auth failed    │
      │     │ PAUSE               │
      │     │ goto :CleanupAndMenu│
      │     └─────────────────────┘
      │
  ┌───▼───────────────┐
  │ set "NET_PASS="   │  *** ZERO-LEAK ***
  │ NETWORK_PATH set  │
  │ CONTINUE          │
  └───────────────────┘
```

### The Robocopy Exit Code Chain

```
  ┌────────────────────────────────┐
  │ fn_run_robocopy                │
  │ PRE-FLIGHT GUARDS             │
  └──────────────┬─────────────────┘
                 │
         ┌───────▼───────┐     ┌──────────────────────┐
         │ src empty?    │─YES─► [!!] FAILED, RC=99   │
         └───────┬───────┘     └──────────────────────┘
                 │ NO
         ┌───────▼───────┐     ┌──────────────────────┐
         │ dst empty?    │─YES─► [!!] FAILED, RC=99   │
         └───────┬───────┘     └──────────────────────┘
                 │ NO
         ┌───────▼───────┐     ┌──────────────────────┐
         │ src exists?   │─NO──► [!!] FAILED, RC=99   │
         └───────┬───────┘     └──────────────────────┘
                 │ YES
         ┌───────▼───────┐     ┌──────────────────────┐
         │ src == dst?   │─YES─► [!!] FAILED, RC=99   │
         └───────┬───────┘     └──────────────────────┘
                 │ NO
         ┌───────▼───────┐
         │ Auto-mkdir dst│
         │ Build flags   │
         │ robocopy runs │
         └───────┬───────┘
                 │
         ┌───────▼───────────┐
         │ ERRORLEVEL = ?    │
         └───────┬───────────┘
            ╱    │      ╲
         0-3    4-7     8+
          │      │       │
     ┌────▼──┐ ┌─▼────┐ ┌▼──────┐
     │SUCCESS│ │WARN  │ │FAILED │
     │ [OK]  │ │ [!!] │ │ [!!]  │
     │  No   │ │PAUSE │ │PAUSE  │
     │ PAUSE │ │      │ │       │
     └───────┘ └──────┘ └───────┘
```

### Flag Variable Quick Reference

```
  ┌──────────────────┬───────────┬──────────────────────────┐
  │ Flag Variable    │ OK Value  │ Set By                   │
  ├──────────────────┼───────────┼──────────────────────────┤
  │ INPUT_OK         │ 1         │ fn_input_credentials     │
  │ NET_PING_OK      │ 1         │ fn_test_connection       │
  │ NET_MAP_OK       │ 1         │ fn_map_credentials       │
  │ DIRECT_SETUP_OK  │ 1         │ fn_setup_direct_cable    │
  │ LAST_RC_STATUS   │ SUCCESS   │ fn_run_robocopy          │
  │ LAST_RC_CODE     │ 0-3       │ fn_run_robocopy          │
  └──────────────────┴───────────┴──────────────────────────┘
  
  Rule: Check flag IMMEDIATELY after calling the function.
  Rule: If flag = FAIL, PAUSE + return to menu. Never continue.
```

---

## 13. Two Side Parts -- Local vs Network Architecture

RoboSync operates in two fundamentally different modes based on whether
a network is involved. This section maps the architecture from the
end-user's operational perspective.

### 13.1 The Two Worlds

```
  ╔══════════════════════════════════════════════════════════════════════╗
  ║                        ROBOSYNC v2.0.0                             ║
  ╠══════════════════════════════╦═══════════════════════════════════════╣
  ║                              ║                                      ║
  ║   SIDE A: LOCAL              ║   SIDE B: NETWORK                    ║
  ║   (No network needed)        ║   (SMB via net use)                  ║
  ║                              ║                                      ║
  ║   Menu: [3] Backup LOCAL     ║   Menu: [1] Backup PUSH             ║
  ║                              ║         [2] Backup PULL             ║
  ║                              ║         [5] Network Setup           ║
  ║                              ║                                      ║
  ║   Source: Local disk/profile  ║   Source: Local OR Remote           ║
  ║   Dest:   Local disk/USB     ║   Dest:   Remote OR Local           ║
  ║                              ║                                      ║
  ║   Prereqs:                   ║   Prereqs:                           ║
  ║   - Admin privileges         ║   - Admin privileges                ║
  ║   - Dest drive exists        ║   - Ethernet/LAN connected          ║
  ║                              ║   - Remote share + credentials      ║
  ║                              ║   - Ping + net use success          ║
  ║                              ║                                      ║
  ║   Robocopy flags:            ║   Robocopy flags:                    ║
  ║   - Same as network          ║   - /Z (restartable on drop)        ║
  ║   - No /Z needed (local)     ║   - /ZB for profiles (locked files) ║
  ║   - USB uses /MT:8           ║   - /MT:16 for network throughput   ║
  ║                              ║                                      ║
  ║   Cleanup:                   ║   Cleanup:                           ║
  ║   - Pipeline vars only       ║   - net use /delete                 ║
  ║                              ║   - DHCP restore (if Direct Cable)  ║
  ║                              ║   - Pipeline vars                    ║
  ║                              ║                                      ║
  ╚══════════════════════════════╩═══════════════════════════════════════╝
```

### 13.2 Side A: Local Backup Flow

No network, no credentials, no cleanup. The fastest path.

```
  USER
   │
   ▼
  ┌───────────────────────────────────┐
  │ [3] Backup LOCAL                  │
  └──────────────┬────────────────────┘
                 │
           ┌─────▼───────────────┐
           │ Enter dest path      │
           │ e.g. E:\Backup       │
           │      F:\USB_Backup   │
           └─────┬───────────────┘
                 │
   ┌─────────────▼─────────────────────────┐
   │         AUTO-DETECT SOURCES           │
   │                                       │
   │  ┌──────────────┐  ┌───────────────┐  │
   │  │ USER PROFILES│  │ DATA DRIVES   │  │
   │  │              │  │               │  │
   │  │ C:\Users\    │  │ D:\ (Fixed)   │  │
   │  │  Admin       │  │ E:\ (Fixed)   │  │
   │  │  User1       │  │ F:\ (USB)     │  │
   │  │  User2       │  │ G:\ (USB)     │  │
   │  │              │  │               │  │
   │  │ Type:PROFILE │  │ Type:PARTITION │  │
   │  │              │  │   or USB      │  │
   │  └──────────────┘  └───────────────┘  │
   │                                       │
   │  fsutil identifies drive type:        │
   │  Fixed Disk --> PARTITION (/MT:16)    │
   │  Removable  --> USB (/MT:8)           │
   └─────────────┬─────────────────────────┘
                 │
           ┌─────▼───────────────┐
           │ User picks source:   │
           │  Single item         │
           │  Custom path         │
           │  ALL Profiles        │
           │  ALL Partitions      │
           └─────┬───────────────┘
                 │
           ┌─────▼───────────────┐
           │ CONFIRM              │
           │ Source --> Dest       │
           │ Type: PROFILE/       │
           │       PARTITION/USB  │
           │ [Y/N]?               │
           └─────┬───────────────┘
                 │
           ┌─────▼───────────────┐
           │ ROBOCOPY ENGINE      │
           │ fn_build_flags(TYPE) │
           │ Logs to RS_*.log    │
           └─────┬───────────────┘
                 │
           ┌─────▼───────────────┐
           │ Exit code parse      │
           │ 0-3: OK              │
           │ 4-7: WARN + PAUSE    │
           │ 8+:  FAIL + PAUSE    │
           └─────┬───────────────┘
                 │
                 ▼
           Back to source selection
           (backup more or [0] back)
```

### 13.3 Side B: Network Backup Flow (Bidirectional)

The key insight: **PUSH and PULL use the same network connection**.
The only difference is which side is source and which is destination.

```
  ┌────────────────────────────────────────────────────────────────┐
  │                    THE BIDIRECTIONAL PRINCIPLE                 │
  │                                                                │
  │  Same tool, same net use connection, user decides direction:  │
  │                                                                │
  │  ┌────────────────────────────────────────────────────────┐    │
  │  │                                                        │    │
  │  │   PUSH: You sit at PC-A, data goes A ══► B            │    │
  │  │                                                        │    │
  │  │   ┌───────┐     net use      ┌───────┐               │    │
  │  │   │ PC-A  │ ════════════════ │ PC-B  │               │    │
  │  │   │(local)│   robocopy -->   │(remote)│               │    │
  │  │   │SOURCE │                  │ DEST  │               │    │
  │  │   └───────┘                  └───────┘               │    │
  │  │                                                        │    │
  │  └────────────────────────────────────────────────────────┘    │
  │                                                                │
  │  ┌────────────────────────────────────────────────────────┐    │
  │  │                                                        │    │
  │  │   PULL: You sit at PC-A, data comes B ══► A            │    │
  │  │                                                        │    │
  │  │   ┌───────┐     net use      ┌───────┐               │    │
  │  │   │ PC-A  │ ════════════════ │ PC-B  │               │    │
  │  │   │(local)│   <-- robocopy   │(remote)│               │    │
  │  │   │ DEST  │                  │SOURCE │               │    │
  │  │   └───────┘                  └───────┘               │    │
  │  │                                                        │    │
  │  └────────────────────────────────────────────────────────┘    │
  │                                                                │
  │  SYMMETRY: If you take the same tool to PC-B and run it:      │
  │                                                                │
  │  ┌────────────────────────────────────────────────────────┐    │
  │  │                                                        │    │
  │  │   PUSH from PC-B: data goes B ══► A                    │    │
  │  │   PULL from PC-B: data comes A ══► B                    │    │
  │  │                                                        │    │
  │  │   Same result, different perspective!                   │    │
  │  │                                                        │    │
  │  └────────────────────────────────────────────────────────┘    │
  │                                                                │
  └────────────────────────────────────────────────────────────────┘
```

### 13.4 Network Flow -- Detailed

```
  USER
   │
   ├──── [1] PUSH ──── or ──── [2] PULL ────┐
   │                                         │
   ▼                                         ▼
  ┌────────────────────────────────────────────────┐
  │          SHARED NETWORK SETUP                  │
  │  (identical for PUSH and PULL)                 │
  │                                                │
  │  ┌────────────────┐                            │
  │  │ Network Type?   │                            │
  │  │ [1] Direct Cable│──► netsh set static IP     │
  │  │ [2] DHCP        │──► skip IP setup           │
  │  │ [0] Cancel      │──► MainMenu                │
  │  └───────┬─────────┘                            │
  │          │                                      │
  │  ┌───────▼─────────┐                            │
  │  │ Input:           │                            │
  │  │  IP, Share,      │                            │
  │  │  User, Password  │                            │
  │  └───────┬─────────┘                            │
  │          │                                      │
  │  ┌───────▼─────────┐                            │
  │  │ Ping ──► Map     │                            │
  │  │ NET_PASS erased  │                            │
  │  └───────┬─────────┘                            │
  │          │                                      │
  │     NETWORK_PATH = \\IP\Share                   │
  └──────────┬─────────────────────────────────────┘
             │
      ┌──────┴──────┐
      │              │
    PUSH            PULL
      │              │
      ▼              ▼
  ┌──────────┐  ┌──────────────┐
  │SRC=Local │  │SRC=Remote    │
  │DST=Remote│  │   (UNC path) │
  │          │  │DST=Local     │
  │Auto-     │  │   (user      │
  │detect    │  │    enters    │
  │profiles  │  │    path)     │
  │partitions│  │              │
  │          │  │List remote   │
  │SelectSrc │  │folders       │
  │flow      │  │via for /d    │
  └────┬─────┘  └──────┬───────┘
       │               │
       ▼               ▼
  ┌────────────────────────────┐
  │    ROBOCOPY ENGINE         │
  │    (same for both)         │
  │    /Z = auto-resume        │
  │    /MT:16 = network speed  │
  └────────────┬───────────────┘
               │
         Exit code parse
               │
               ▼
         Back to source selection
```

### 13.5 Source/Destination Matrix

```
  ┌────────────────────┬───────────────────┬───────────────────────────┐
  │ Mode               │ Source            │ Destination               │
  ├────────────────────┼───────────────────┼───────────────────────────┤
  │ [1] PUSH           │ LOCAL auto-detect │ REMOTE (\\IP\Share)       │
  │                    │ (profiles, drives)│                           │
  ├────────────────────┼───────────────────┼───────────────────────────┤
  │ [2] PULL           │ REMOTE (\\IP\     │ LOCAL (user enters path)  │
  │                    │  Share\folder)    │                           │
  ├────────────────────┼───────────────────┼───────────────────────────┤
  │ [3] LOCAL          │ LOCAL auto-detect │ LOCAL (user enters path)  │
  │                    │ (profiles, drives)│                           │
  ├────────────────────┼───────────────────┼───────────────────────────┤
  │ [4A] Restore Merge │ LOCAL or REMOTE   │ LOCAL profile             │
  │                    │ backup folder     │ (C:\Users\<name>)         │
  ├────────────────────┼───────────────────┼───────────────────────────┤
  │ [4B] Restore Mirror│ LOCAL or REMOTE   │ LOCAL (user enters path)  │
  │                    │ backup folder     │                           │
  └────────────────────┴───────────────────┴───────────────────────────┘
```

### 13.6 The Constraint: Local vs Remote Asymmetry

```
  ┌────────────────────────────────────────────────────────────────┐
  │                WHAT YOU CAN DO                                 │
  ├───────────────────────────┬────────────────────────────────────┤
  │ On LOCAL drives           │ On REMOTE shares (via net use)     │
  ├───────────────────────────┼────────────────────────────────────┤
  │ fsutil (drive type)       │ CANNOT -- no fsutil over SMB      │
  │ for /f + system commands  │ CANNOT -- no remote execution     │
  │ Auto-detect profiles      │ CANNOT -- can only list folders   │
  │ Auto-detect USB vs Fixed  │ CANNOT -- all treated as CUSTOM   │
  │ Read file attributes      │ CAN -- robocopy handles this      │
  │ Create directories        │ CAN -- mkdir on UNC path          │
  │ Copy files (robocopy)     │ CAN -- bidirectional              │
  │ List folders (for /d)     │ CAN -- for /d on \\IP\Share\*     │
  └───────────────────────────┴────────────────────────────────────┘

  IMPLICATION FOR PUSH vs PULL:
  ─────────────────────────────
  PUSH: Auto-detect works (source is local) --> smart flag selection
  PULL: Auto-detect doesn't work (source is remote) --> CUSTOM flags only
  
  This is WHY PUSH has richer source selection (profiles, partitions, USB)
  while PULL only lists remote folders and uses CUSTOM type.
```

### 13.7 Version Roadmap -- Enhance Bidirectional UX

Current state (v2.0.0) and future enhancement path:

```
  v2.0.0 (CURRENT)
  ┌──────────────────────────────────────────┐
  │ Menu: PUSH / PULL / LOCAL                │
  │ User must understand direction concept   │
  │ Separate flows for each mode             │
  │ Network setup embedded in PUSH/PULL      │
  └──────────────────────────────────────────┘
                    │
                    ▼ (future enhancement)
  v2.x.0 (PROPOSED)
  ┌──────────────────────────────────────────┐
  │ Menu: BACKUP / RESTORE / NETWORK         │
  │                                          │
  │ BACKUP flow:                             │
  │  Step 1: "Where is the data?"            │
  │          [1] On THIS PC (local source)   │
  │          [2] On ANOTHER PC (remote src)  │
  │                                          │
  │  Step 2: "Where to save the backup?"     │
  │          [1] On THIS PC (local dest)     │
  │          [2] On ANOTHER PC (remote dest) │
  │          [3] On USB drive                │
  │                                          │
  │  Step 3: System auto-determines:         │
  │          local+remote = PUSH             │
  │          remote+local = PULL             │
  │          local+local  = LOCAL            │
  │                                          │
  │  User doesn't need to know PUSH/PULL    │
  │  terminology -- just answers questions   │
  └──────────────────────────────────────────┘
```
