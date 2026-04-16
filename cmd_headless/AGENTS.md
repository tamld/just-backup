# 🤖 AGENTS.md — RoboSync AI Governance & Contribution Protocol

> **SYSTEM DIRECTIVE**: If you are an AI Agent (Claude, Gemini, Cursor, Copilot, etc.) contributing to `RoboSync`, this file is your **Absolute Source of Truth**. You MUST read, understand, and rigidly comply with these directives before proposing architecture, generating code, or fixing bugs.

---

## 1. Identity & Core Doctrine

**RoboSync** is a production-grade, automated backup & restore utility designed for restricted Windows environments.
Our mission is **Speed, Data Integrity, and Absolute Ubiquity**.

To achieve ubiquity, we adhere to the **Zero-Dependency Mandate**:
- **No PowerShell for Core Logic:** Execution policies (`Restricted`) routinely block `.ps1` files in enterprise environments. PowerShell is strictly banned from handling core flow. It may only be used as a 1-liner fallback (e.g., masking password input) where no native CMD alternative exists.
- **PowerShell IS allowed for TESTING.** Test harnesses don't ship to production. See §12.
- **No Third-Party Runtimes:** Do not write code requiring Node.js, Python, Rust, or external binaries.
- **No Deprecated Tooling:** `wmic` is deprecated in Windows 11. Do not use it.

---

## 2. The Architectural Mandate (Anti-Monolith)

Code must be modularized:

- **The Router (`RoboSync.bat`)**: Main Menu, State Routing, Global Variables, Pipeline Cleanup. No business logic.
- **The Libraries (`lib\*.bat`)**:
  - `ui.bat`: Banners, separators, standard output formatting.
  - `network.bat`: IPC auth (`net use`), ping, static IP setup/restore.
  - `discover.bat`: Disk/Profile/USB scanning using native loops.
  - `engine.bat`: Robocopy wrapper — flags, exclusions, exit code parsing, auto-mkdir.

**Cross-Module Rule**: `call "%LIBS%\module.bat" fn_name "args"`. Never `goto` across files. Never assume CWD; anchor to `%~dp0`.

---

## 3. The Local ≠ Remote Asymmetry (Critical Constraint)

> **"Because you CAN run a command locally does NOT mean it works remotely."**

`net use` provides **file-level access only** via SMB. You CANNOT:
- Run `fsutil` on a remote machine's drives
- Execute `for /f` with system commands against UNC paths
- Query remote drive types, free space, or hardware info
- Run ANY executable on the remote OS

**What you CAN do** over `net use`:
- `for /d` to list directories on `\\IP\Share\*`
- `robocopy` to/from UNC paths
- `if exist` on `\\IP\Share\folder`
- `mkdir` on `\\IP\Share\newfolder`

**Design Implication**: `discover.bat` uses `fsutil` ONLY for LOCAL drives. For remote shares, we can only list folders — never classify them. Any AI agent attempting to "improve" remote discovery with local-only commands will produce silently broken code.

---

## 4. The "Fail-Fast" and "Trust Nothing" Principle

1. **Pre-Flight Input Validation**: Every function MUST validate its inputs.
   ```bat
   if "%~1"=="" ( echo [!!] Parameter missing. & goto :eof )
   ```
2. **Path Verification**: Never spawn `robocopy` or `net use` without verifying the path exists.
3. **Execution Halts**: Use `goto :eof` or `exit /b` to unwind. NEVER `exit` inside a module (kills terminal).
4. **Pre-clear before `set /p`**: A bare Enter keeps the OLD value. Always `set "VAR="` first.

---

## 5. The PAUSE Strategy (Interactive vs Unattended Balance)

CMD has no `try/catch`. Our error strategy is **PAUSE-based debugging** with clear rules:

| Phase | Behavior | Rationale |
|---|---|---|
| **Input** (IP, Share, User, mode selection) | ⏸️ PAUSE — wait for user | Business decision — requires human |
| **Pre-flight** (Ping fail, Map fail, path missing) | ⏸️ PAUSE on FAILURE only | Config error — user must see and fix |
| **Execution** (Robocopy running) | ▶️ UNATTENDED | Robocopy handles its own retry/resume |
| **Post-flight** (Exit code WARN or FAIL) | ⏸️ PAUSE | Abnormal result — user must read before continuing |
| **Cleanup** (Unmap, DHCP restore) | ▶️ UNATTENDED | Housekeeping — no decision needed |

**The Golden Rule**: Script runs automatically until it needs a **human decision** or hits an **abnormal state**. Then it pauses with enough context for the operator to diagnose.

---

## 6. Robocopy Enterprise Standards

### A. Flag Philosophy
Flags are not arbitrary. Each serves a production purpose:

| Flag | Purpose | When Used |
|---|---|---|
| `/Z` | **Restartable mode** — resumes from byte position if network drops | ALL network copies (Push/Pull) |
| `/ZB` | Restartable + Backup mode — reads locked files (ntuser.dat) | Profile backup only |
| `/MIR` | Mirror — sync + delete extras at dest | Backup and Restore-Mirror (UC5) |
| `/E` | Copy subdirs — keeps existing files at dest | Restore-Merge only (UC4) |
| `/MT:16` | 16 parallel threads | Fixed disk + network |
| `/MT:8` | 8 threads | USB/Removable (slower write) |
| `/R:2 /W:1` | Retry 2x, wait 1s | Default for all |

### B. Self-Recovery
Robocopy with `/Z` bookmarks byte position. If a copy is interrupted (network drop, Ctrl+C), re-running the same command **automatically resumes** from where it stopped. This is our self-recovery mechanism — no custom code needed.

### C. Exclusion Rationale 
Profile exclusions (browser caches, Temp, Packages) reduce network I/O by up to 400%. Removing an exclusion requires benchmarking the I/O cost first.

---

## 7. Strict Code Conventions

### A. Memory Management
- **Zero-Leak Passwords**: `set "NET_PASS="` immediately after `net use`.
- **Pipeline Purity**: ALL Tier 2/3 vars cleared at `:MainMenu`.

### B. Variable Taxonomy
- **Global Constants**: `UPPER_SNAKE_CASE` — Set once, never cleared.
- **Pipeline Variables**: `UPPER_SNAKE_CASE` — Set per-job, cleared at menu.
- **Local Variables**: `_underscore_prefix` — Function-scoped by convention.

### C. Console Output Prefixes
- `[>>]` Section Header
- `[--]` Processing Info
- `[OK]` Success
- `[!!]` Warning/Error

### D. Comment Rules
- `::` for top-level comments (outside blocks)
- `REM` inside `if/for` blocks (prevents parser crash, see SRS §9.4)

### E. CMD Symbol Rules (The Rosetta Stone)

Full reference with examples: see SRS §13. Mandatory summary:

```
%~dp0          Script's folder path (ALWAYS use for path building, NEVER %CD%)
%~1, %~2       Strip quotes from function arguments
!VAR!          Delayed expansion — use for ALL runtime variable reads
%VAR%          Normal expansion — ONLY for static constants set before blocks
%%D            FOR variable in .bat files (double %%, never single)
^( ^) ^> ^&    Escape special chars inside echo statements
call set "X=%%ARRAY_!IDX!%%"    Dynamic array access (double expansion)
%TEMP%         Windows temp dir (for goUAC .vbs)
%SYSTEMROOT%   C:\Windows (for admin check)
```

**The Cardinal Sin**: Using `%VAR%` inside a `for` or `if` block where the variable changes. It will ALWAYS read the **old value** because `%` expands at parse time, not execution time. Use `!VAR!`.

---

## 8. Edge Cases

### A. Vietnamese / Unicode
`chcp 65001` at startup. ALL path vars in double quotes `"!VAR!"`.

### B. Dual Network (Direct Cable vs DHCP)
Static IP via `netsh` → auto-restore DHCP on cleanup.

### C. Passwords with `!` or `%`
Known limitation: `!` eaten by delayed expansion, `%` triggers variable expansion. Documented, no workaround in CMD.

---

## 9. The 3-Tier Variable Scoping Contract

```
TIER 1 — GLOBAL (Immortal)
  APP_VERSION, SCRIPT_DIR, LIBS, LOG_DIR

TIER 2 — PIPELINE (Per-job, cleared at :MainMenu)
  BACKUP_MODE, NET_TYPE, DEST_IP, DEST_SHARE,
  NET_USER, NET_PASS, NETWORK_PATH, BACKUP_DEST,
  NET_IFACE, NET_LOCAL_IP, RESTORE_BASE

TIER 3 — SELECTED (Ephemeral)
  SELECTED_SRC, SELECTED_NAME, SELECTED_TYPE, FINAL_DEST

LOCAL — (_prefix, die at goto :eof)
```

**Contract**: New pipeline variable → add `set "VAR="` in `:MainMenu` cleanup.

---

## 10. The Development Pipeline (Mandatory for AI Agents)

Every change — no matter how small — follows this cycle:

```
PLAN → DOCUMENT → EXECUTE → EVALUATE → OPTIMIZE
 ↑                                          ↓
 └──────────── feedback loop ───────────────┘
```

| Phase | What you produce | Where it lives |
|---|---|---|
| **Plan** | Intent, constraints, dependencies | SRS / implementation_plan.md |
| **Document** | Update specs BEFORE writing code | AGENTS.md, README.md, SRS |
| **Execute** | Write code strictly following the documented plan | `*.bat` files |
| **Evaluate** | Gap analysis: plan vs reality, strengths & weaknesses | walkthrough.md |
| **Optimize** | Fix gaps, update docs with lessons learned | All docs + code |

**The Cardinal Rule**: If your code diverges from the plan and you don't update the documentation, you have created **invisible drift** — the most dangerous state in any system.

---

## 11. Dual Distribution Model

```
cmd_headless/
├── RoboSync.bat + lib/   ← DEV mode (modular, debuggable)
├── dist/
│   └── RoboSync_Portable.bat  ← RUN mode (single-file, portable)
├── build.bat             ← Guide (NOT auto-concat — see build.bat comments)
└── test_harness.ps1      ← PowerShell test suite
```

**WHY NOT auto-concat?** CMD module dispatchers (`call :%*`, `exit /b`) break when inlined. The portable file is **hand-crafted** with all `call "%LIBS%\..."` rewritten to `call :fn_...`. See `build.bat` for full explanation.

**Sync protocol**: Edit modular source → test → manually sync changes to Portable → test again.

---

## 12. Testing Philosophy (PowerShell as Test Middleware)

CMD cannot test itself. PowerShell serves as the **test harness layer** — banned from production, essential for verification.

### The 3-Layer Testing Strategy

| Layer | What | How | Safety |
|---|---|---|---|
| **Static Lint** | Grep for crash patterns | PS regex on `.bat` source | 100% safe — read-only |
| **Safe Runtime** | Test non-destructive actions | PS launches CMD subprocess, captures output | Safe — sandbox, no network, no admin ops |
| **Sandbox Robocopy** | Test copy logic with real files | PS creates temp dirs, runs robocopy, asserts results | Safe — `%TEMP%` sandbox, auto-cleanup |

### Static Lint Checks (Automated)

| Check | What it catches |
|---|---|
| `%LIBS%` remnants | Modular→Portable transform forgot to rewrite a call |
| `::` inside blocks | Parser crash: `::` is a hidden label, breaks `if/for` |
| `set /p` without pre-clear | Bare Enter keeps the OLD value — state leak |
| Missing goto/call targets | Label typo → script crashes |
| Parentheses imbalance | Unmatched `(` or `)` → parser breaks entire block |
| Unquoted `set` assignments | Trailing space becomes part of the value |

### Run the test suite:
```powershell
powershell -ExecutionPolicy Bypass -File test_harness.ps1
```

**The Principle**: "I don't THINK it works — I PROVE it works." Inference is not evidence.

---

## 13. The Knowledge Flywheel

You are a maintainer of institutional memory. If you discover a pattern, optimization, or pitfall:
- Document the **Why** and **How** in inline comments
- Update `AGENTS.md` (this file) or `README.md`
- We trust the **Codebase as eternal record**, never implicit AI memory
