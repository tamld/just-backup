# RoboSync -- End-User Operation Guide

> **Audience**: IT Technicians, Helpdesk Staff, System Administrators
> **Purpose**: Step-by-step visual guide for real-world backup/restore scenarios

---

## Scenario 1: Backup PC-A to PC-B via Direct Cable

**Situation**: You are at a user's desk. You need to backup their data to another PC
before reimaging. The two PCs are connected by an Ethernet cable (no router/switch).

### What You Need

```
  ┌──────────────┐         Ethernet Cable          ┌──────────────┐
  │    PC-A      │ ================================ │    PC-B      │
  │  (Source)    │                                  │  (Dest)      │
  │              │                                  │              │
  │  Has data:   │                                  │  Has:        │
  │  - Profiles  │                                  │  - Shared    │
  │  - D: drive  │                                  │    folder    │
  │  - USB disk  │                                  │  - Free      │
  │              │                                  │    space     │
  │  Run         │                                  │              │
  │  RoboSync    │                                  │              │
  │  HERE        │                                  │              │
  └──────────────┘                                  └──────────────┘
```

### Pre-Setup on PC-B (Destination)
```
  1. Create a shared folder:
     Right-click folder --> Properties --> Sharing --> Share
     OR use admin share: \\PC-B-IP\C$

  2. Note down:
     - PC-B's current IP (or the IP you will assign)
     - Share name (e.g., "Backup" or "C$")
     - Username with access (e.g., "Admin")
     - Password
```

### Step-by-Step Operation

```
  STEP 1: LAUNCH
  ══════════════════════════════════════════════════════

    Double-click RoboSync_Portable.bat on PC-A
    
         ┌──────────────────────────────┐
         │  [UAC Prompt]               │
         │  "Do you want to allow      │
         │   this app to make changes  │
         │   to your device?"          │
         │                             │
         │       [Yes]  [No]           │
         └──────────────────────────────┘
    
    Click [Yes]
    
         ┌──────────────────────────────────────────────────┐
         │                                                  │
         │    ██████╗  ██████╗ ██████╗  ██████╗             │
         │    ██╔══██╗██╔═══██╗██╔══██╗██╔═══██╗            │
         │    ██████╔╝██║   ██║██████╔╝██║   ██║            │
         │    ██╔══██╗██║   ██║██╔══██╗██║   ██║            │
         │    ██║  ██║╚██████╔╝██████╔╝╚██████╔╝            │
         │    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝            │
         │               ROBOSYNC v2.0.0                    │
         │                                                  │
         │    [1] Backup PUSH     - Local to Remote         │
         │    [2] Backup PULL     - Remote to Local         │
         │    [3] Backup LOCAL    - Local to Local          │
         │    [4] Restore Profile - Recover data            │
         │    [5] Network Setup   - Configure network       │
         │    [6] Exit                                      │
         │                                                  │
         │    Network: NOT_CONNECTED                        │
         │                                                  │
         └──────────────────────────────────────────────────┘
    
    Press [1] for Backup PUSH


  STEP 2: NETWORK TYPE
  ══════════════════════════════════════════════════════

         ┌──────────────────────────────────────────────────┐
         │  [>>] NETWORK TYPE                               │
         │                                                  │
         │  [1] Direct Cable (Static IP)                    │
         │  [2] Existing Network (DHCP)                     │
         │  [0] Cancel                                      │
         └──────────────────────────────────────────────────┘
    
    Press [1] for Direct Cable
    
    (System will list your network interfaces)

         ┌──────────────────────────────────────────────────┐
         │  [>>] NETWORK INTERFACES                         │
         │                                                  │
         │  [1] Ethernet           Connected                │
         │  [2] Wi-Fi              Connected                │
         │                                                  │
         │  Choose interface for static IP: _               │
         └──────────────────────────────────────────────────┘
    
    Type [1] (the Ethernet port connected to PC-B)
    
    System sets IP 169.254.1.1/24 on that interface.
    (PC-B should also have a static IP in 169.254.1.x range)


  STEP 3: CREDENTIALS
  ══════════════════════════════════════════════════════

         ┌──────────────────────────────────────────────────┐
         │  Remote IP:    169.254.1.2                       │
         │  Share name:   Backup                            │
         │  Username:     Admin                             │
         │  Password:     ****                              │
         └──────────────────────────────────────────────────┘
    
    System pings 169.254.1.2...
    
         [OK] Reply received.
    
    System maps: net use \\169.254.1.2\Backup /user:Admin ****
    
         [OK] Network connected successfully.
    
    (Password is ERASED from memory immediately)


  STEP 4: SELECT SOURCE
  ══════════════════════════════════════════════════════

         ┌──────────────────────────────────────────────────┐
         │  [>>] SELECT BACKUP SOURCE                       │
         │  [--] Destination: \\169.254.1.2\Backup          │
         │  ────────────────────────────────────────         │
         │                                                  │
         │  --- USER PROFILES ---                           │
         │  [1] Admin        | C:\Users\Admin               │
         │  [2] NguyenVanA   | C:\Users\NguyenVanA          │
         │                                                  │
         │  --- DATA DRIVES ---                             │
         │  [3] D_Data       | D:\                          │
         │  [4] USB_Drive    | F:\                          │
         │                                                  │
         │  --- TUY CHON ---                                │
         │  [5] Enter path manually                         │
         │  [6] Backup ALL Profiles                         │
         │  [7] Backup ALL Partitions                       │
         │  [0] Go back                                     │
         └──────────────────────────────────────────────────┘
    
    Common choices:
    - Type [1] to backup "Admin" profile
    - Type [6] to backup ALL profiles (loop)
    - Type [7] to backup ALL partitions


  STEP 5: CONFIRM AND RUN
  ══════════════════════════════════════════════════════

    (Example: selected [1] Admin)

         ┌──────────────────────────────────────────────────┐
         │  [>>] CONFIRM BACKUP                             │
         │  ────────────────────────────────────────         │
         │  [--] Source : C:\Users\Admin                     │
         │  [--] Dest   : \\169.254.1.2\Backup\Profile_Admin│
         │  [--] Type   : PROFILE                           │
         │  ────────────────────────────────────────         │
         │                                                  │
         │  Run backup? [Y/N]: _                            │
         └──────────────────────────────────────────────────┘
    
    Press [Y]

         ┌──────────────────────────────────────────────────┐
         │  [>>] ROBOCOPY ENGINE                            │
         │  [--] Source : C:\Users\Admin                     │
         │  [--] Dest   : \\169.254.1.2\Backup\Profile_Admin│
         │  [--] Type   : PROFILE                           │
         │  [--] Log    : logs\RS_20250425_143022.log       │
         │                                                  │
         │  (robocopy output scrolling...)                  │
         │  ...                                             │
         │                                                  │
         │  [OK] Hoan tat. Code=1                           │
         │  [--] Log: logs\RS_20250425_143022.log           │
         └──────────────────────────────────────────────────┘
    
    Code=1 means files were copied successfully.
    Returns to source selection -- backup more or press [0].


  STEP 6: EXIT
  ══════════════════════════════════════════════════════

    Press [0] at source selection --> Main Menu
    Press [6] at Main Menu --> Exit
    
    System automatically:
    - Unmaps net use connection
    - Restores DHCP on the Ethernet interface
    - Clears all pipeline variables
    
         Thank you for using RoboSync!
```

### Time Estimates
| What | Size | Time (Gigabit) | Time (USB 3.0) |
|---|---|---|---|
| 1 profile (typical) | 5-15 GB | 2-5 min | 5-10 min |
| 1 profile (heavy, with AppData) | 20-40 GB | 7-15 min | 15-30 min |
| All profiles (3 users) | 30-60 GB | 10-25 min | N/A (network) |
| 1 partition (D: drive) | 50-200 GB | 15-60 min | N/A (network) |

---

## Scenario 2: Backup PC-A to PC-B via Existing Network (DHCP)

**Situation**: Both PCs are on the same LAN (connected to same router/switch/WiFi).

### Differences from Scenario 1

```
  ┌──────────────┐                              ┌──────────────┐
  │    PC-A      │ ─── Router/Switch ─────────── │    PC-B      │
  │  (Source)    │     (DHCP assigns IPs)        │  (Dest)      │
  │  192.168.1.10│                               │  192.168.1.20│
  └──────────────┘                               └──────────────┘
```

### Step-by-Step (only differences)

```
  STEP 2: NETWORK TYPE
  ══════════════════════════════════════════════════════
    
    Press [2] for DHCP (Existing Network)
    
    --> No static IP setup needed
    --> No interface selection needed
    --> Skip directly to credentials


  STEP 3: CREDENTIALS
  ══════════════════════════════════════════════════════

         ┌──────────────────────────────────────────────────┐
         │  Remote IP:    192.168.1.20                      │
         │  Share name:   C$                                │
         │  Username:     Admin                             │
         │  Password:     ****                              │
         └──────────────────────────────────────────────────┘
    
    (Rest is identical to Scenario 1 from Step 4 onward)


  ON EXIT:
    - net use unmapped
    - NO DHCP restore needed (was already DHCP)
    - Only pipeline vars cleared
```

---

## Scenario 3: Backup to Another Local Partition

**Situation**: You want to backup your profile to another drive on the same PC.
No network, no remote PC. Just C: --> E:.

```
  ┌──────────────────────────────────────────────────────────┐
  │                      SAME PC                             │
  │                                                          │
  │  ┌─────────────┐    robocopy     ┌─────────────────┐    │
  │  │ C:\Users\    │ ════════════►  │ E:\Backup\       │    │
  │  │  Admin\      │                │  Profile_Admin\  │    │
  │  │  Desktop\    │                │   Desktop\       │    │
  │  │  Documents\  │                │   Documents\     │    │
  │  │  Downloads\  │                │   Downloads\     │    │
  │  └─────────────┘                 └─────────────────┘    │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
```

### Step-by-Step

```
  STEP 1: LAUNCH
  ══════════════════════════════════════════════════════

    Same as Scenario 1 Step 1.
    Press [3] for Backup LOCAL.


  STEP 2: DESTINATION
  ══════════════════════════════════════════════════════

         ┌──────────────────────────────────────────────────┐
         │  [>>] BACKUP LOCAL (Local --> Local)              │
         │  ────────────────────────────────────────         │
         │                                                  │
         │  Destination path (e.g. E:\Backup): _            │
         └──────────────────────────────────────────────────┘
    
    Type: E:\Backup
    
    --> NO network setup, NO credentials
    --> Goes directly to source selection


  STEP 3: SELECT SOURCE
  ══════════════════════════════════════════════════════

    Same as Scenario 1 Step 4, but destination is E:\Backup.
    
    Select source --> Confirm --> Robocopy runs --> Done.


  TOTAL TIME: Fastest scenario (no network latency)
  ──────────────────────────────────────────────────
  10 GB profile: ~1-2 min (SSD to SSD)
  10 GB profile: ~3-5 min (SSD to HDD)
  10 GB profile: ~5-10 min (SSD to USB 3.0)
```

---

## Scenario 4: Backup to USB External Disk

**Situation**: You have a USB external hard drive. You want to backup data to it.

```
  ┌──────────────┐        USB 3.0        ┌──────────────┐
  │    PC-A      │ ═══════════════════════ │  USB Disk    │
  │              │                        │  (F:\)       │
  │  C:\Users\   │  robocopy /MT:8        │  F:\Backup\  │
  │  D:\Data\    │  (fewer threads        │              │
  │              │   for USB write speed) │              │
  └──────────────┘                        └──────────────┘
```

### Step-by-Step

```
  STEP 1: Same as Scenario 3 -- Press [3] Backup LOCAL

  STEP 2: Enter destination: F:\Backup

  STEP 3: SELECT SOURCE
  ══════════════════════════════════════════════════════

         ┌──────────────────────────────────────────────────┐
         │  --- USER PROFILES ---                           │
         │  [1] Admin        | C:\Users\Admin               │
         │                                                  │
         │  --- DATA DRIVES ---                             │
         │  [2] D_Data       | D:\                          │
         │  [3] USB_Drive    | F:\    <-- THIS IS THE USB   │
         │                                                  │
         │  --- TUY CHON ---                                │
         │  [4] Enter path manually                         │
         │  ...                                             │
         └──────────────────────────────────────────────────┘
    
    IMPORTANT: Do NOT select [3] (the USB itself) as source 
    when backing up TO the USB -- that would be source=dest!
    The source=dest guard (v2.0.0) will catch this and abort.
    
    Select [1] to backup Admin profile to USB.


  STEP 4: CONFIRM AND RUN
  ══════════════════════════════════════════════════════

    Notice: If source is detected as USB type,
    robocopy uses /MT:8 (not /MT:16) to avoid
    overwhelming USB write speed.
    
    If source is a PROFILE and dest is USB:
    Uses PROFILE flags (/MIR /ZB /XJ + exclusions).
```

---

## Scenario 5: Restore from Backup to New PC

**Situation**: User got a new PC. You need to restore their Desktop, Documents, etc.
from a backup on an external drive.

```
  ┌──────────────────┐                  ┌──────────────────┐
  │  USB/Network     │  robocopy /E     │    NEW PC        │
  │  (Backup)        │ ═══════════════► │                  │
  │                  │  (MERGE mode)    │  C:\Users\       │
  │  E:\Backup\      │                  │   NewAdmin\      │
  │   Profile_Admin\ │  Does NOT        │    Desktop\      │
  │    Desktop\      │  delete user's   │    Documents\    │
  │    Documents\    │  new files!      │    Downloads\    │
  │    Downloads\    │                  │    (new files    │
  │    Pictures\     │                  │     preserved)   │
  └──────────────────┘                  └──────────────────┘
```

### Step-by-Step

```
  STEP 1: LAUNCH
  ══════════════════════════════════════════════════════

    Press [4] for Restore Profile.

         ┌──────────────────────────────────────────────────┐
         │  [>>] RESTORE USER PROFILE                       │
         │                                                  │
         │  [--] Select backup source location:             │
         │                                                  │
         │  [1] Local folder on this PC                     │
         │  [2] Network folder (requires auth)              │
         │  [0] Go back                                     │
         └──────────────────────────────────────────────────┘
    
    Press [1] (backup is on USB drive plugged into new PC).


  STEP 2: BACKUP LOCATION
  ══════════════════════════════════════════════════════

         ┌──────────────────────────────────────────────────┐
         │  Backup folder path (e.g. E:\Backup): E:\Backup  │
         └──────────────────────────────────────────────────┘


  STEP 3: SELECT BACKUP PROFILE
  ══════════════════════════════════════════════════════

         ┌──────────────────────────────────────────────────┐
         │  [>>] SELECT BACKUP PROFILE TO RESTORE           │
         │  [--] Folder: E:\Backup                          │
         │  ────────────────────────────────────────         │
         │                                                  │
         │  [1] Profile_Admin                               │
         │  [2] Profile_NguyenVanA                          │
         │  [3] D_Data                                      │
         │                                                  │
         │  [0] Go back                                     │
         └──────────────────────────────────────────────────┘
    
    Press [1] to restore Admin's profile.


  STEP 4: CHOOSE RESTORE MODE
  ══════════════════════════════════════════════════════

         ┌──────────────────────────────────────────────────┐
         │  [>>] SELECT RESTORE MODE                        │
         │  [--] Source: Profile_Admin                       │
         │                                                  │
         │  [A] Restore into existing Profile               │
         │      Merge subfolders: Desktop, Documents...     │
         │      Does NOT overwrite ntuser.dat,              │
         │      does NOT delete old files.                  │
         │                                                  │
         │  [B] Restore to designated path                  │
         │      Full mirror copy to a folder you specify.   │
         │                                                  │
         │  [0] Go back                                     │
         └──────────────────────────────────────────────────┘
    
    Press [A] for merge restore (preserves user's new files).
    Press [B] for mirror restore (exact copy, deletes extras).


  STEP 5A: MERGE RESTORE (Most Common)
  ══════════════════════════════════════════════════════

    System detects profiles on the new PC:

         ┌──────────────────────────────────────────────────┐
         │  [--] Choose target profile:                     │
         │                                                  │
         │  [1] NewAdmin   | C:\Users\NewAdmin              │
         │  [2] OtherUser  | C:\Users\OtherUser             │
         │                                                  │
         │  [0] Go back                                     │
         └──────────────────────────────────────────────────┘
    
    Press [1] to restore into NewAdmin.
    
    System detects restorable subfolders:
    
         ┌──────────────────────────────────────────────────┐
         │  [>>] CONFIRM RESTORE                            │
         │  ────────────────────────────────────────         │
         │  [--] Backup source : E:\Backup\Profile_Admin    │
         │  [--] Restore into  : C:\Users\NewAdmin          │
         │  [--] Mode          : MERGE (/E - keeps files)   │
         │  [--] Folders:                                   │
         │       - Desktop                                  │
         │       - Documents                                │
         │       - Downloads                                │
         │       - Pictures                                 │
         │       - Videos                                   │
         │       - Music                                    │
         │       - AppData\Roaming                          │
         │  ────────────────────────────────────────         │
         │                                                  │
         │  Start restore? [Y/N]: _                         │
         └──────────────────────────────────────────────────┘
    
    Press [Y]
    
    Robocopy runs for EACH subfolder with /E (merge):
    
         [--] Restoring: Desktop
         [OK] Hoan tat. Code=1
         [--] Restoring: Documents
         [OK] Hoan tat. Code=1
         [--] Restoring: Downloads
         [OK] Hoan tat. Code=0
         ...
         
         [OK] Restore hoan tat.

    RESULT:
    ┌─────────────────────────────────────────────────────┐
    │ C:\Users\NewAdmin\Desktop\                          │
    │   report_2024.docx     <-- FROM BACKUP (restored)  │
    │   my_new_notes.txt     <-- USER'S NEW FILE (kept!) │
    │   project_plan.xlsx    <-- FROM BACKUP (restored)  │
    └─────────────────────────────────────────────────────┘
```

---

## Scenario 6: Quick Network Pre-Check

**Situation**: Before starting a big backup, you want to verify the network works.

```
  STEP 1: Press [5] Network Setup
  STEP 2: Press [1] Direct Cable (or [2] DHCP)
  STEP 3: Enter credentials, ping, authenticate
  STEP 4: Press [4] Show Connection Status
  
         ┌──────────────────────────────────────────────────┐
         │  [>>] NETWORK STATUS                             │
         │  ────────────────────────────────────────         │
         │  Mode      : DIRECT                              │
         │  Interface : Ethernet                            │
         │  Local IP  : 169.254.1.1                         │
         │  Remote IP : 169.254.1.2                         │
         │  Share     : Backup                              │
         │  User      : Admin                               │
         │  Path      : \\169.254.1.2\Backup                │
         │  Status    : CONNECTED                           │
         └──────────────────────────────────────────────────┘
  
  STEP 5: Press [0] Back to Main Menu
  STEP 6: Press [1] Backup PUSH
  
         --> Network is ALREADY connected!
         --> Skips network setup
         --> Goes directly to source selection
```

---

## Quick Reference Card

```
  ╔═══════════════════════════════════════════════════════════╗
  ║               ROBOSYNC QUICK REFERENCE                   ║
  ╠═══════════════════════════════════════════════════════════╣
  ║                                                          ║
  ║  BACKUP:                                                 ║
  ║  [1] PUSH  = My PC --> Other PC (need network)           ║
  ║  [2] PULL  = Other PC --> My PC (need network)           ║
  ║  [3] LOCAL = My PC --> My USB/drive (no network)         ║
  ║                                                          ║
  ║  RESTORE:                                                ║
  ║  [4A] MERGE  = Add files back, keep new ones             ║
  ║  [4B] MIRROR = Exact copy, delete extras                 ║
  ║                                                          ║
  ║  NETWORK:                                                ║
  ║  [5] Setup, verify, disconnect                           ║
  ║                                                          ║
  ║  EXIT CODES:                                             ║
  ║  0-3 = OK (green light, continue)                        ║
  ║  4-7 = WARNING (some files skipped, check log)           ║
  ║  8+  = ERROR (check log for details)                     ║
  ║                                                          ║
  ║  TIPS:                                                   ║
  ║  - If copy stops, just re-run -- /Z auto-resumes         ║
  ║  - Close Outlook before backup (PST/OST locks)           ║
  ║  - Log files in logs\ folder for troubleshooting         ║
  ║  - USB uses fewer threads (slower but safer)             ║
  ║                                                          ║
  ╚═══════════════════════════════════════════════════════════╝
```

---

## Troubleshooting

| Problem | Cause | Solution |
|---|---|---|
| "Cannot reach IP" | Cable not connected, wrong IP, firewall | Check cable, verify IP, disable firewall temporarily |
| "Auth failed" | Wrong username/password or share name | Verify credentials, check share permissions on PC-B |
| Exit code 5 (WARNING) | Some files were locked/in-use | Close Outlook, browsers. Re-run backup for locked files |
| Exit code 8+ (FAILED) | Permission denied, disk full, path too long | Check dest space, run as Admin, shorten folder names |
| "Source and Destination are the same" | Selected USB as both source and dest | Choose a different source or destination |
| UAC prompt won't appear | Running from restricted context | Right-click .bat --> "Run as administrator" |
| Vietnamese filenames garbled | Missing `chcp 65001` | Should auto-set; verify terminal supports UTF-8 |
| Script closes immediately | Missing lib\ modules (Dev mode) | Use Portable version or verify lib\ folder exists |
