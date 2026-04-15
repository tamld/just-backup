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
