# just-backup

## Product Overview
Portable Backup Tool for Windows.
Designed specifically for Vietnamese users (with English fallback).
Focuses on safety, reliable restore, no data corruption, and full Unicode support.

## System Architecture
Rust Application (System Layer) -> Planner / Identity / Manifest / UI -> Robocopy Adapter -> Robocopy (copy engine)

Robocopy is ONLY the copy engine. The Rust app acts as the backup system.

## Crate Choices
- `eframe`/`egui`: Simple and fast GUI, cross-platform (but used for Windows here).
- `serde`/`serde_json`: Manifest management and state persistence.
- `chrono`: Handling timestamps.
- `uuid`: Generating backup IDs.
- `tracing`/`tracing-subscriber`: Detailed logging for debugging and error tracking.
- `walkdir`/`fs_extra`: Directory traversing and optional manual fallbacks if needed.
- `sysinfo`: Detecting drives and system information for identifying valid external drives safely.

## Robocopy Integration
Robocopy is invoked via standard Rust `std::process::Command` safely using argument vectors to prevent injection.
Default pattern: `robocopy <src> <dst> /E /COPY:DAT /DCOPY:DAT /R:3 /W:5 /MT:8 /XJ /FFT /TEE /LOG:<logfile>`
Exit code handling:
- 0–7 = Success (with some skipped files)
- >=8 = Failure

## CMD Headless — Zero-Dependency Native Fallback

> **This is NOT a replacement for the Rust GUI.** It is a **nice-to-have** operational fallback optimized for cost, speed, and maximum compatibility.

The [`cmd_headless/`](cmd_headless/) directory contains a pure CMD Batch implementation of the same Robocopy-based backup engine — with zero external dependencies. No Rust runtime, no DLLs, no installation.

### When to use CMD Headless instead of the Rust GUI:
| Scenario | Why CMD Headless wins |
|---|---|
| Windows PE / Recovery Environment | No GUI runtime available |
| Server Core (no Desktop Experience) | No window manager |
| Windows 7/8 machines missing VC++ runtime | Rust binary won't launch |
| Execution Policy locks (no .exe allowed) | `.bat` files bypass this |
| Emergency USB deployment | Drop one file, double-click, done |

### Dual Distribution Model
The CMD version ships in two forms:

```
cmd_headless/
├── RoboSync.bat      # Entry point (modular — for dev/testing)
├── lib/              # Modules: ui, network, discover, engine
├── build.bat         # Bundler script
├── dist/
│   └── RoboSync_Portable.bat  # Single-file output (for production)
├── AGENTS.md         # AI governance rules for CMD code
└── README.md         # Usage documentation
```

- **Dev mode** (`RoboSync.bat` + `lib/`): Modular, debuggable, each module in its own file.
- **Run mode** (`dist/RoboSync_Portable.bat`): All modules inlined into ONE file. Copy this single file to any machine.

Build the portable version: `cd cmd_headless && build.bat`

### Strengths and Limitations of CMD approach

| ✅ Strengths | ❌ Limitations |
|---|---|
| Runs on ANY Windows (7-11, Server, PE) | No error handling (try/catch) |
| Zero dependencies, zero install | Passwords with `!` or `%` break |
| Bypasses Execution Policy | No progress tracking UI |
| Self-recovery via `/Z` restartable | Limited string manipulation |
| Direct cable + DHCP dual network | Cannot query remote OS info |
