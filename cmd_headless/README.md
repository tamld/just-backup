# RoboSync — Fast Backup & Restore Tool

RoboSync is a production-grade, enterprise-ready backup & restore utility built in pure CMD Batch for Windows. Zero dependencies. Zero installation. Drop the folder, double-click, and go.

## Features

| Feature | Detail |
|---|---|
| **Zero-Dependency** | Pure `.bat` files. No PowerShell, no runtime. Bypasses execution policies. |
| **5 Operation Modes** | Push (Local→Remote), Pull (Remote→Local), Local, Restore into Profile, Restore to Path |
| **Auto-Detection** | Profiles (`C:\Users\*`), Fixed Disks, USB/Removable (via `fsutil`) |
| **Dual Network** | Direct cable (static IP via `netsh`) or DHCP (existing LAN) with auto-restore |
| **Enterprise Robocopy** | `/Z` restartable (resume after network drop), `/ZB` backup mode for locked files, `/MT:16` multithreaded |
| **Smart Exclusions** | Browser caches, Temp, Windows Store, system files skipped — up to 400% faster on SMB |
| **Restore: Merge** | `/E` mode — merges data into existing profile WITHOUT deleting new files |
| **Restore: Mirror** | `/MIR` mode — full mirror copy to designated path |
| **Fail-Fast Engine** | Every input validated before execution. Empty variable = abort, not catastrophe. |
| **Unicode Support** | `chcp 65001` — Vietnamese file/folder names fully supported |

## Directory Structure

```
cmd_headless/
├── RoboSync.bat         ★ DEV Entry (modular, with lib/)
├── lib/
│   ├── ui.bat           Banner, messages, separators
│   ├── network.bat      net use, ping, static IP, DHCP restore
│   ├── discover.bat     Auto-detect profiles, partitions, USB
│   └── engine.bat       Robocopy wrapper, flag builder, exit codes
├── dist/
│   └── RoboSync_Portable.bat  ★ RUN Entry (single-file, portable)
├── test_harness.ps1     PowerShell test suite (14 automated checks)
├── build.bat            Guide for dual distribution
├── README.md            This file
└── AGENTS.md            ★ AI Agent governance (13 sections)
```

## How To Use

1. Copy `RoboSync_Fast/` folder to any Windows PC (or USB).
2. Double-click `RoboSync.bat` → auto-elevates to Administrator.
3. Choose mode:
   - `[1]` Push backup over network
   - `[2]` Pull backup from network
   - `[3]` Local backup (same machine)
   - `[4]` Restore user profile
   - `[5]` Exit

## Known Limitations

| Limitation | Why | Workaround |
|---|---|---|
| Passwords with `!` or `%` break | CMD delayed expansion eats `!`, `%` triggers variable expansion | Use passwords without these characters |
| Cannot detect remote drive types | `net use` only provides SMB file access, not OS-level commands | Remote drives shown as generic folders |
| VBScript blocked by policy | Some orgs disable Windows Script Host | Right-click → Run as Administrator |
| `/MIR` deletes at destination | Mirror mode removes files not in source | Use Restore Mode A (merge via `/E`) for profiles |

## Documentation

- **[AGENTS.md](AGENTS.md)**: Governance rules (13 sections) for AI and human contributors.
- **SRS**: Full system specification in the project's brain directory.

## Testing

CMD cannot test itself. We use **PowerShell as a test middleware layer**:

```powershell
powershell -ExecutionPolicy Bypass -File test_harness.ps1
```

**14 automated checks** in 2 sections:
- **Static Lint**: bracket balance, label integrity, `set /p` pre-clear, `%LIBS%` remnants, `::` in blocks
- **Safe Runtime**: sandbox robocopy, `/E` merge verification, profile detection, fsutil, UTF-8, banner rendering

PowerShell is **banned from production** (execution policy risk) but **essential for testing** (tests don't ship).

## Version History

| Version | Changes |
|---|---|
| v1.4.0 | Dual distribution, PowerShell test harness (14 checks), development pipeline mandate |
| v1.3.0 | Restore feature (UC4/UC5), USB detection, Enterprise robocopy `/Z`, PAUSE strategy |
| v1.2.0 | Static IP direct cable, DHCP dual mode, Unicode support, 3-tier variable scoping |
| v1.1.0 | Fail-fast, profile exclusions, `fn_build_flags` |
| v1.0.0 | Initial MVP: 3 backup modes, goUAC, modular architecture |
