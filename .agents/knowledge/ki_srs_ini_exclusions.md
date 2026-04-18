# SRS: config.ini Exclusions Feature

## 1. Context & Scope (Ngữ cảnh & Phạm vi)
This SRS dictates the strict implementation rules for parsing the `config.ini` file to dynamically append exclusions (`/XD`) to the `robocopy` command in the **just-backup** project.

**CRITICAL RULES:**
- **Target Architecture**: This feature is strictly for the `cmd_headless` version (Batch scripts).
- **Out of Scope**: DO NOT modify the `src/` directory (Rust rewrite project). The Rust project is currently decoupled from this task.
- **No Dirty Patches**: Do NOT generate standalone `.py` or `.sh` files to modify auto-generated monolithic files.

## 2. Technical Requirements (Đặc tả kỹ thuật)

### 2.1 File Target
- You MUST implement the parsing logic explicitly inside `cmd_headless/lib/engine.bat`.
- The logic MUST be injected inside the `:fn_run_robocopy` function, exactly after the line `call :fn_build_flags "!_rc_type!"`.

### 2.2 Parsing Logic
- Use a `for /f` loop to read `config.ini` line-by-line.
- **Comment Handling**: Lines starting with a semicolon (`;`) or hash (`#`) MUST be ignored.
- **Append Logic**: Valid lines must be appended to the `_BUILD_FLAGS` variable with proper robocopy syntax: `set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD ""!_line!"""`
- **Fallback**: The logic must wrap inside an `if exist "config.ini"` block to prevent errors when the file does not exist.

## 3. Verification & Build Protocol (Kế hoạch Kiểm thử)
To ensure the changes are valid, any Agent performing this task MUST complete the following verification steps:
1. **Apply the Core Edit**: Ensure `cmd_headless/lib/engine.bat` is cleanly edited.
2. **Re-Build the Monolith**: You MUST instruct the user to run `cmd_headless/build.bat`, or if you are automating it, you MUST manually apply the EXACT SAME LOGIC to `cmd_headless/dist/RoboSync_Portable.bat` around the `fn_build_flags` line (around line 1061).
3. **Evidence-Based Reporting**: Report success only after verifying that the `RoboSync_Portable.bat` file contains the new parsing logic without syntax errors.
