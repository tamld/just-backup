# Standardized UAC Elevation Pattern (Windows Batch)

## Context & Problem
When writing Windows Batch (`.bat`) scripts, we often need to elevate privileges to Administrator. The legacy pattern was to write a temporary `.vbs` script and execute it directly.
**The Flaw**: On many enterprise systems, the default file association for `.vbs` is disabled or redirected to Notepad for security reasons. Executing the `.vbs` file directly will fail or open a text editor instead of triggering the UAC prompt.

## The Standardized Solution (Knowledge)
To guarantee execution regardless of file associations, we **must** explicitly invoke the Windows Script Host engine (`cscript.exe`) with the `//nologo` flag.

### Code Pattern
```batch
:request_admin
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %*", "", "runas", 1 >> "%temp%\getadmin.vbs"

REM Crucial: Use cscript //nologo to bypass file association issues
cscript //nologo "%temp%\getadmin.vbs"

del "%temp%\getadmin.vbs"
exit /B
```

## Verification Checklist
Before applying this pattern, always verify:
1. `cscript //nologo` is used instead of `wscript` (prevents UI popups if script errors).
2. The `>>` redirection is properly escaped as `^>^>` if it is used inside a bracketed code block `(...)`.
