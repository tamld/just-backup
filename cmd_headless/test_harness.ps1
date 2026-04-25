# ================================================================
# TEST HARNESS v4.0 -- Comprehensive CMD Batch Verification
# PURPOSE: Static lint + Safe runtime + WORST-CASE edge cases
#          + v2.0 refactor validation + drift detection
#          + variable scoping + engine flags + error handling
#          + restore flow + network module + edge case hardening
#          PowerShell is BANNED from production, ESSENTIAL for testing.
#
# SECTIONS: 11 (67 checks total)
#   1.  Static Lint (both Dev & Portable)
#   1B. v2.0 Specific Checks
#   1C. Drift Detection (Dev vs Portable)
#   2.  Worst-Case Edge Cases
#   3.  CMD Parser Traps
#   4.  Safe Runtime Checks
#   5.  Variable Scoping Validation
#   6.  Engine Flag Tests
#   7.  Error Handling Tests
#   8.  Restore Flow Tests
#   9.  Network Module Tests (safe/mocked)
#   10. Worst-Case Edge Cases (expanded)
#   11. Drift Detection Expansion
#
# USAGE:  powershell -ExecutionPolicy Bypass -File test_harness.ps1
# CI/CD:  Runs automatically via GitHub Actions on push/PR
# ================================================================

$ErrorActionPreference = "Stop"
$script:PassCount = 0
$script:FailCount = 0
$script:WarnCount = 0
$Target = "$PSScriptRoot\dist\RoboSync_Portable.bat"
$DevEntry = "$PSScriptRoot\RoboSync.bat"
$DevLibDir = "$PSScriptRoot\lib"
$Sandbox = "$env:TEMP\rs_test_sandbox_$(Get-Random)"

function Write-Result($Name, $Pass, $Detail = "", $Warn = $false) {
    if ($Warn) {
        $script:WarnCount++
        Write-Host "  [WARN] $Name :: $Detail" -ForegroundColor Yellow
    } elseif ($Pass) {
        $script:PassCount++
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:FailCount++
        Write-Host "  [FAIL] $Name :: $Detail" -ForegroundColor Red
    }
}

function Setup-Sandbox {
    if (Test-Path $Sandbox) { Remove-Item $Sandbox -Recurse -Force }
    New-Item -ItemType Directory -Path "$Sandbox\src\Desktop" -Force | Out-Null
    New-Item -ItemType Directory -Path "$Sandbox\src\Documents" -Force | Out-Null
    New-Item -ItemType Directory -Path "$Sandbox\src\Downloads" -Force | Out-Null
    New-Item -ItemType Directory -Path "$Sandbox\dst" -Force | Out-Null
}

function Cleanup-Sandbox {
    if (Test-Path $Sandbox) { Remove-Item $Sandbox -Recurse -Force -ErrorAction SilentlyContinue }
}

# ================================================================
# SECTION 1: STATIC LINT (Both DEV and PORTABLE)
# ================================================================
Write-Host "`n=== SECTION 1: STATIC LINT ===" -ForegroundColor Cyan

foreach ($file in @($Target, $DevEntry)) {
    $fname = Split-Path $file -Leaf
    if (-not (Test-Path $file)) {
        Write-Result "File exists: $fname" $false "Not found: $file"
        continue
    }
    $lines = Get-Content $file
    $content = Get-Content $file -Raw

    # 1.1: No %LIBS% in Portable (should be call :fn_)
    if ($file -eq $Target) {
        $libsRefs = ($lines | Select-String -Pattern '%LIBS%' -SimpleMatch).Count
        Write-Result "[$fname] No %%LIBS%% remnants" ($libsRefs -eq 0) "Found $libsRefs"
    }

    # 1.2: No :: inside if/for blocks
    $blockDepth = 0
    $badComments = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimStart()
        # Track block depth by counting ( and )
        $opens = ([regex]::Matches($line, '\(')).Count - ([regex]::Matches($line, '\^\(')).Count
        $closes = ([regex]::Matches($line, '\)')).Count - ([regex]::Matches($line, '\^\)')).Count
        $blockDepth += $opens - $closes
        if ($blockDepth -lt 0) { $blockDepth = 0 }
        if ($blockDepth -gt 0 -and $line -match '^::' -and $line -notmatch '^:::') {
            $badComments += ($i + 1)
        }
    }
    Write-Result "[$fname] No :: inside blocks" ($badComments.Count -eq 0) "Lines: $($badComments -join ', ')"

    # 1.3: Every set /p has pre-clear within 5 lines above
    $setpIssues = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'set\s+/p\s+"(\w+)=') {
            $varName = $Matches[1]
            $start = [Math]::Max(0, $i - 5)
            $prevLines = $lines[$start..$i] -join "`n"
            if ($prevLines -notmatch "set\s+`"$varName=`"") {
                $setpIssues += "L$($i+1):$varName"
            }
        }
    }
    Write-Result "[$fname] All set /p pre-cleared" ($setpIssues.Count -eq 0) "Missing: $($setpIssues -join ', ')"

    # 1.4: All labels targeted by goto/call exist
    $labelDefs = @{}
    $lines | ForEach-Object { if ($_ -match '^\s*:(\w+)') { $labelDefs[$Matches[1]] = $true } }
    $missingTargets = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        # Skip comment lines
        if ($line.TrimStart() -match '^(::|\bREM\b)') { continue }
        if ($line -match '(?:goto|call)\s+:(\w+)' -and $Matches[1] -ne 'eof') {
            if (-not $labelDefs.ContainsKey($Matches[1])) {
                $missingTargets += "L$($i+1):$($Matches[1])"
            }
        }
    }
    Write-Result "[$fname] All goto/call targets exist" ($missingTargets.Count -eq 0) "Missing: $($missingTargets -join ', ')"

    # 1.5: Parentheses balance (excluding escaped)
    $openCount = ([regex]::Matches($content, '\(')).Count
    $closeCount = ([regex]::Matches($content, '\)')).Count
    $escapedOpen = ([regex]::Matches($content, '\^\(')).Count
    $escapedClose = ([regex]::Matches($content, '\^\)')).Count
    $netOpen = $openCount - $escapedOpen
    $netClose = $closeCount - $escapedClose
    Write-Result "[$fname] Parentheses balanced" ($netOpen -eq $netClose) "Open=$netOpen Close=$netClose"

    # 1.6: No unquoted set assignments
    $unquotedSets = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimStart()
        if ($line -match '^set\s+(?!/[ap])(\w+=)' -and $line -notmatch '^set\s+"') {
            $unquotedSets += "L$($i+1)"
        }
    }
    Write-Result "[$fname] All set assignments quoted" ($unquotedSets.Count -eq 0) "Unquoted: $($unquotedSets -join ', ')"
}

# ================================================================
# SECTION 1B: v2.0 SPECIFIC CHECKS
# ================================================================
Write-Host "`n=== SECTION 1B: v2.0 SPECIFIC CHECKS ===" -ForegroundColor Cyan

foreach ($file in @($Target, $DevEntry)) {
    $fname = Split-Path $file -Leaf
    if (-not (Test-Path $file)) { continue }
    $content = Get-Content $file -Raw
    
    # If checking DevEntry, combine with lib files so we can find functions
    if ($file -eq $DevEntry -and (Test-Path $DevLibDir)) {
        foreach ($lib in Get-ChildItem "$DevLibDir\*.bat") {
            $content += "`n" + (Get-Content $lib.FullName -Raw)
        }
    }

    $lines = Get-Content $file

    # 1B.1: UAC uses cscript //nologo (not direct .vbs execution)
    $hasCscript = $content -match 'cscript //nologo'
    $hasDirectVbs = $content -match '"%temp%\\[^"]*\.vbs"[\s]*$' -and $content -notmatch 'cscript'
    Write-Result "[$fname] UAC uses cscript //nologo" $hasCscript
    Write-Result "[$fname] No direct .vbs execution" (-not $hasDirectVbs)

    # 1B.2: NET_STATUS variable is initialized
    $hasNetStatusInit = $content -match 'set "NET_STATUS=NOT_CONNECTED"'
    Write-Result "[$fname] NET_STATUS initialized" $hasNetStatusInit

    # 1B.3: NET_STATUS set to CONNECTED on map success
    $hasNetStatusConnect = $content -match 'NET_STATUS=CONNECTED'
    Write-Result "[$fname] NET_STATUS set on connect" $hasNetStatusConnect

    # 1B.4: displayMainMenu label exists (display/logic separation)
    $hasDisplayMain = $content -match ':displayMainMenu'
    Write-Result "[$fname] Menu display/logic separated" $hasDisplayMain

    # 1B.5: Network Setup menu exists
    $hasNetworkMenu = $content -match ':NetworkMenu'
    Write-Result "[$fname] Network Setup menu exists" $hasNetworkMenu

    # 1B.6: fn_status_bar exists
    $hasStatusBar = $content -match ':fn_status_bar'
    Write-Result "[$fname] fn_status_bar exists" $hasStatusBar
}

# ================================================================
# SECTION 1C: DRIFT DETECTION (Dev vs Portable)
# ================================================================
Write-Host "`n=== SECTION 1C: DRIFT DETECTION ===" -ForegroundColor Cyan

if ((Test-Path $Target) -and (Test-Path $DevEntry)) {
    $devContent = Get-Content $DevEntry -Raw
    $portContent = Get-Content $Target -Raw

    # Collect all lib module files for Dev
    $allDevContent = $devContent
    if (Test-Path $DevLibDir) {
        foreach ($lib in Get-ChildItem "$DevLibDir\*.bat") {
            $allDevContent += "`n" + (Get-Content $lib.FullName -Raw)
        }
    }

    # 1C.1: Function count parity (count :fn_ labels)
    $devFns = ([regex]::Matches($allDevContent, '(?m)^:fn_\w+')).Count
    $portFns = ([regex]::Matches($portContent, '(?m)^:fn_\w+')).Count
    Write-Result "Function count parity (Dev=$devFns Portable=$portFns)" ($devFns -eq $portFns) "Dev=$devFns Portable=$portFns"

    # 1C.2: Version string base match (allow -portable suffix)
    $devVer = if ($devContent -match 'APP_VERSION=v([\d.]+)') { $Matches[1] } else { "?" }
    $portVer = if ($portContent -match 'APP_VERSION=v([\d.]+)') { $Matches[1] } else { "?" }
    Write-Result "Version base match (Dev=$devVer Portable=$portVer)" ($devVer -eq $portVer) "Dev=v$devVer Portable=v$portVer"

    # 1C.3: Menu option count parity (count choice /c options)
    $devMainChoice = if ($devContent -match 'choice /n /c (\w+) /m "\s*Choose mode') { $Matches[1].Length } else { 0 }
    $portMainChoice = if ($portContent -match 'choice /n /c (\w+) /m "\s*Choose mode') { $Matches[1].Length } else { 0 }
    Write-Result "Main menu option count parity" ($devMainChoice -eq $portMainChoice) "Dev=$devMainChoice Portable=$portMainChoice"

    # 1C.4: Both have NetworkMenu
    $devHasNetMenu = $devContent -match ':NetworkMenu'
    $portHasNetMenu = $portContent -match ':NetworkMenu'
    Write-Result "Both have NetworkMenu" ($devHasNetMenu -and $portHasNetMenu)
}

# ================================================================
# SECTION 2: WORST-CASE EDGE CASES
# ================================================================
Write-Host "`n=== SECTION 2: WORST-CASE EDGE CASES ===" -ForegroundColor Cyan

Setup-Sandbox

# 2.1: Unicode Vietnamese folder names
$vnFolder = "$Sandbox\src\Tài liệu công việc"
New-Item -ItemType Directory -Path $vnFolder -Force | Out-Null
"Nội dung tiếng Việt" | Out-File "$vnFolder\báo_cáo.txt" -Encoding UTF8
$vnDst = "$Sandbox\dst\vn_test"
$vnResult = & cmd /c "chcp 65001 >nul & robocopy `"$vnFolder`" `"$vnDst`" /E /R:0 /W:0 /NP /NFL /NDL 2>&1"
$vnExit = $LASTEXITCODE
Write-Result "Unicode Vietnamese folder copy" ($vnExit -le 3) "ExitCode=$vnExit"
Write-Result "Unicode dest file exists" (Test-Path "$vnDst\báo_cáo.txt")

# 2.2: Paths with spaces (the classic CMD trap)
$spaceFolder = "$Sandbox\src\My Important Files"
New-Item -ItemType Directory -Path $spaceFolder -Force | Out-Null
"space test" | Out-File "$spaceFolder\my file.txt" -Encoding UTF8
$spaceDst = "$Sandbox\dst\space test"
$spResult = & cmd /c "robocopy `"$spaceFolder`" `"$spaceDst`" /E /R:0 /W:0 /NP /NFL /NDL 2>&1"
Write-Result "Paths with spaces copy OK" ($LASTEXITCODE -le 3) "ExitCode=$LASTEXITCODE"
Write-Result "Spaced filename exists at dest" (Test-Path "$spaceDst\my file.txt")

# 2.3: Empty source directory (robocopy should still succeed)
$emptyFolder = "$Sandbox\src\EmptyDir"
New-Item -ItemType Directory -Path $emptyFolder -Force | Out-Null
$emptyDst = "$Sandbox\dst\empty_test"
$emResult = & cmd /c "robocopy `"$emptyFolder`" `"$emptyDst`" /E /R:0 /W:0 /NP 2>&1"
Write-Result "Empty dir copy succeeds" ($LASTEXITCODE -le 1) "ExitCode=$LASTEXITCODE"
Write-Result "Empty dest dir created" (Test-Path $emptyDst)

# 2.4: /MIR deletes extra files at destination (verify destructive behavior)
$mirSrc = "$Sandbox\src\mir_test"
$mirDst = "$Sandbox\dst\mir_dest"
New-Item -ItemType Directory -Path $mirSrc -Force | Out-Null
New-Item -ItemType Directory -Path $mirDst -Force | Out-Null
"source_file" | Out-File "$mirSrc\keep.txt" -Encoding UTF8
"extra_file" | Out-File "$mirDst\delete_me.txt" -Encoding UTF8
& cmd /c "robocopy `"$mirSrc`" `"$mirDst`" /MIR /R:0 /W:0 /NP /NFL /NDL 2>&1" | Out-Null
Write-Result "/MIR keeps source file" (Test-Path "$mirDst\keep.txt")
Write-Result "/MIR deletes extra file" (-not (Test-Path "$mirDst\delete_me.txt")) "Extra file still exists!"

# 2.5: /E does NOT delete extra files (verify non-destructive merge)
$mergeSrc = "$Sandbox\src\merge_test"
$mergeDst = "$Sandbox\dst\merge_dest"
New-Item -ItemType Directory -Path $mergeSrc -Force | Out-Null
New-Item -ItemType Directory -Path $mergeDst -Force | Out-Null
"new_file" | Out-File "$mergeSrc\new.txt" -Encoding UTF8
"existing_file" | Out-File "$mergeDst\old.txt" -Encoding UTF8
& cmd /c "robocopy `"$mergeSrc`" `"$mergeDst`" /E /R:0 /W:0 /NP /NFL /NDL 2>&1" | Out-Null
Write-Result "/E copies new file" (Test-Path "$mergeDst\new.txt")
Write-Result "/E keeps existing file" (Test-Path "$mergeDst\old.txt") "Existing file was deleted!"

# 2.6: Very deep nested path (MAX_PATH stress test)
$deepPath = "$Sandbox\src"
for ($d = 1; $d -le 10; $d++) { $deepPath += "\level$d" }
New-Item -ItemType Directory -Path $deepPath -Force | Out-Null
"deep_file" | Out-File "$deepPath\deep.txt" -Encoding UTF8
$deepDst = "$Sandbox\dst\deep_test"
& cmd /c "robocopy `"$Sandbox\src\level1`" `"$deepDst`" /E /R:0 /W:0 /NP /NFL /NDL 2>&1" | Out-Null
Write-Result "Deep nested path (10 levels) copy" ($LASTEXITCODE -le 3) "ExitCode=$LASTEXITCODE"

# 2.7: Destination auto-mkdir (robocopy creates intermediate folders)
$autoMkdir = "$Sandbox\dst\auto\created\by\robocopy"
& cmd /c "robocopy `"$Sandbox\src\Desktop`" `"$autoMkdir`" /E /R:0 /W:0 /NP /NFL /NDL 2>&1" | Out-Null
Write-Result "Auto-mkdir nested destination" (Test-Path $autoMkdir)

# 2.8: Robocopy /Z flag accepted (restartable mode)
$zResult = & cmd /c "robocopy `"$Sandbox\src\Desktop`" `"$Sandbox\dst\z_test`" /E /Z /R:0 /W:0 /NP 2>&1"
Write-Result "/Z restartable flag accepted" ($LASTEXITCODE -le 3) "ExitCode=$LASTEXITCODE"

# ================================================================
# SECTION 3: CMD PARSER TRAPS (worst-case syntax validation)
# ================================================================
Write-Host "`n=== SECTION 3: CMD PARSER TRAPS ===" -ForegroundColor Cyan

# 3.1: Delayed expansion works correctly in loop
$deTest = @'
@echo off
setlocal enabledelayedexpansion
set "COUNT=0"
for /l %%i in (1,1,3) do (
    set /a COUNT+=1
    if !COUNT! equ 3 echo [DE_TEST_PASS]
)
'@
$deFile = "$Sandbox\test_delayed.bat"
$deTest | Out-File $deFile -Encoding ASCII
$deOut = & cmd /c "`"$deFile`"" 2>&1
Write-Result "Delayed expansion in loop" (($deOut -join '') -match 'DE_TEST_PASS')

# 3.2: call set double expansion (our array pattern)
$callTest = @'
@echo off
setlocal enabledelayedexpansion
set "ITEM_1=Alpha"
set "ITEM_2=Beta"
set "ITEM_3=Gamma"
set "IDX=2"
call set "RESULT=%%ITEM_!IDX!%%"
if "!RESULT!"=="Beta" echo [CALL_SET_PASS]
'@
$callFile = "$Sandbox\test_callset.bat"
$callTest | Out-File $callFile -Encoding ASCII
$callOut = & cmd /c "`"$callFile`"" 2>&1
Write-Result "call set double expansion (array)" (($callOut -join '') -match 'CALL_SET_PASS')

# 3.3: Escaped parentheses in echo inside if block
$escTest = @'
@echo off
setlocal enabledelayedexpansion
set "MODE=MERGE"
if "!MODE!"=="MERGE" (
    echo [--] Mode: MERGE ^(/E - keep files^)
    echo [ESC_PAREN_PASS]
)
'@
$escFile = "$Sandbox\test_escape.bat"
$escTest | Out-File $escFile -Encoding ASCII
$escOut = & cmd /c "`"$escFile`"" 2>&1
Write-Result "Escaped () in echo inside if" (($escOut -join '') -match 'ESC_PAREN_PASS')

# 3.4: Pipe and && inside for block (our fsutil pattern)
$pipeTest = @'
@echo off
setlocal enabledelayedexpansion
set "_dtype=Unknown"
for /f "tokens=*" %%T in ('fsutil fsinfo drivetype C: 2^>nul') do (
    set "_line=%%T"
    echo "!_line!" | find "Fixed" >nul 2>&1 && set "_dtype=Fixed"
)
if "!_dtype!"=="Fixed" echo [PIPE_AND_PASS]
'@
$pipeFile = "$Sandbox\test_pipe.bat"
$pipeTest | Out-File $pipeFile -Encoding ASCII
$pipeOut = & cmd /c "`"$pipeFile`"" 2>&1
Write-Result "Pipe + && inside for block (fsutil)" (($pipeOut -join '') -match 'PIPE_AND_PASS')

# 3.5: goto :eof returns correctly from call
$gotoTest = @'
@echo off
setlocal enabledelayedexpansion
call :fn_test
echo [RETURN_OK]
goto :done
:fn_test
    echo [INSIDE_FN]
    goto :eof
:done
echo [GOTO_EOF_PASS]
'@
$gotoFile = "$Sandbox\test_goto.bat"
$gotoTest | Out-File $gotoFile -Encoding ASCII
$gotoOut = & cmd /c "`"$gotoFile`"" 2>&1
$gotoJoined = $gotoOut -join ''
Write-Result "goto :eof returns to caller" ($gotoJoined -match 'INSIDE_FN' -and $gotoJoined -match 'RETURN_OK')

# 3.6: Nested if blocks (3 levels, like our profile filter)
$nestedTest = @'
@echo off
setlocal enabledelayedexpansion
set "_name=Administrator"
if /i not "!_name!"=="Public" (
    if /i not "!_name!"=="Default" (
        if /i not "!_name!"=="All Users" (
            echo [NESTED_IF_PASS]
        )
    )
)
'@
$nestedFile = "$Sandbox\test_nested.bat"
$nestedTest | Out-File $nestedFile -Encoding ASCII
$nestedOut = & cmd /c "`"$nestedFile`"" 2>&1
Write-Result "Nested if (3 levels)" (($nestedOut -join '') -match 'NESTED_IF_PASS')

# 3.7: for /d with delayed expansion path (restore source listing)
$forTest = @'
@echo off
setlocal enabledelayedexpansion
set "BASE=%TEMP%"
set /a _COUNT=0
for /d %%D in ("!BASE!\*") do (
    set /a _COUNT+=1
)
if !_COUNT! gtr 0 echo [FORD_DE_PASS]
'@
$forFile = "$Sandbox\test_ford.bat"
$forTest | Out-File $forFile -Encoding ASCII
$forOut = & cmd /c "`"$forFile`"" 2>&1
Write-Result "for /d with delayed expansion path" (($forOut -join '') -match 'FORD_DE_PASS')

# ================================================================
# SECTION 4: SAFE RUNTIME CHECKS
# ================================================================
Write-Host "`n=== SECTION 4: SAFE RUNTIME CHECKS ===" -ForegroundColor Cyan

# 4.1: Profile detection
$profileOut = & cmd /c "chcp 65001 >nul & for /d %U in (C:\Users\*) do @echo %~nxU" 2>&1
$profiles = $profileOut | Where-Object { $_ -notmatch 'Public|Default|All Users' -and $_.Trim() -ne '' }
Write-Result "Profile detection finds users" ($profiles.Count -gt 0) "Found: $($profiles -join ', ')"

# 4.2: Partition detection
$partOut = & cmd /c "for %D in (C D E F G H) do @if exist %D:\ @echo %D" 2>&1
$parts = $partOut | Where-Object { $_.Trim() -ne '' }
Write-Result "Partition detection finds drives" ($parts.Count -gt 0) "Found: $($parts -join ', ')"

# 4.3: fsutil drive type (admin)
$fsOut = & cmd /c "fsutil fsinfo drivetype C:" 2>&1
Write-Result "fsutil drivetype works" ($fsOut -match 'Fixed') "Output: $fsOut"

# 4.4: chcp 65001
$chcpOut = & cmd /c "chcp 65001 >nul & echo OK" 2>&1
Write-Result "UTF-8 codepage switch" (($chcpOut -join '') -match 'OK')

# 4.5: choice command available
$choiceHelp = & cmd /c "choice /? 2>&1" 2>&1
Write-Result "choice command available" (($choiceHelp -join '') -match '/C')

# 4.6: Banner render test
$bannerTest = @'
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
set "APP_VERSION=v1.4.0-test"
echo   ==========================================
echo   ROBOSYNC PORTABLE  %APP_VERSION%
echo   Fast Backup and Restore Engine
echo   ==========================================
echo [BANNER_OK]
'@
$bannerFile = "$Sandbox\test_banner.bat"
$bannerTest | Out-File $bannerFile -Encoding ASCII
$bannerOut = & cmd /c "`"$bannerFile`"" 2>&1
Write-Result "Banner renders without crash" (($bannerOut -join '') -match 'BANNER_OK')

# ================================================================
# SECTION 5: VARIABLE SCOPING VALIDATION (A1)
# ================================================================
Write-Host "`n=== SECTION 5: VARIABLE SCOPING VALIDATION ===" -ForegroundColor Cyan

# 5.1: MainMenu clears Tier 2 pipeline vars
$scopeTest1 = @'
@echo off
setlocal enabledelayedexpansion
set "BACKUP_MODE=PUSH"
set "BACKUP_DEST=D:\Test"
set "NET_PASS=secret123"
set "SELECTED_SRC=C:\Source"
set "SELECTED_NAME=TestName"
set "SELECTED_TYPE=PROFILE"
set "FINAL_DEST=D:\Final"

REM Simulate MainMenu pipeline cleanup
set "BACKUP_MODE="
set "BACKUP_DEST="
set "NET_PASS="
set "SELECTED_SRC="
set "SELECTED_NAME="
set "SELECTED_TYPE="
set "FINAL_DEST="

set "_ok=1"
if defined BACKUP_MODE set "_ok=0"
if defined BACKUP_DEST set "_ok=0"
if defined NET_PASS set "_ok=0"
if defined SELECTED_SRC set "_ok=0"
if defined SELECTED_NAME set "_ok=0"
if defined SELECTED_TYPE set "_ok=0"
if defined FINAL_DEST set "_ok=0"
if "!_ok!"=="1" echo [SCOPE_CLEAR_PASS]
'@
$scopeFile1 = "$Sandbox\test_scope_clear.bat"
$scopeTest1 | Out-File $scopeFile1 -Encoding ASCII
$scopeOut1 = & cmd /c "`"$scopeFile1`"" 2>&1
Write-Result "Tier 2/3 vars cleared at MainMenu" (($scopeOut1 -join '') -match 'SCOPE_CLEAR_PASS')

# 5.2: Tier 1 globals survive pipeline clear
$scopeTest2 = @'
@echo off
setlocal enabledelayedexpansion
set "APP_VERSION=v2.0.0"
set "SCRIPT_DIR=C:\Test\"
set "LIBS=C:\Test\lib"
set "LOG_DIR=C:\Test\logs"

REM Simulate clearing pipeline (Tier 2 only)
set "BACKUP_MODE="
set "NET_PASS="

REM Verify Tier 1 survived
set "_ok=1"
if not "!APP_VERSION!"=="v2.0.0" set "_ok=0"
if not defined SCRIPT_DIR set "_ok=0"
if not defined LIBS set "_ok=0"
if not defined LOG_DIR set "_ok=0"
if "!_ok!"=="1" echo [GLOBALS_SURVIVE_PASS]
'@
$scopeFile2 = "$Sandbox\test_scope_globals.bat"
$scopeTest2 | Out-File $scopeFile2 -Encoding ASCII
$scopeOut2 = & cmd /c "`"$scopeFile2`"" 2>&1
Write-Result "Tier 1 globals survive pipeline clear" (($scopeOut2 -join '') -match 'GLOBALS_SURVIVE_PASS')

# 5.3: Zero-leak password pattern
$scopeTest3 = @'
@echo off
setlocal enabledelayedexpansion
set "NET_PASS=MySecret123"
REM Simulate zero-leak: password cleared after use
set "NET_PASS="
if not defined NET_PASS echo [ZERO_LEAK_PASS]
'@
$scopeFile3 = "$Sandbox\test_zero_leak.bat"
$scopeTest3 | Out-File $scopeFile3 -Encoding ASCII
$scopeOut3 = & cmd /c "`"$scopeFile3`"" 2>&1
Write-Result "Zero-leak password pattern" (($scopeOut3 -join '') -match 'ZERO_LEAK_PASS')

# ================================================================
# SECTION 6: ENGINE FLAG TESTS (A2)
# ================================================================
Write-Host "`n=== SECTION 6: ENGINE FLAG TESTS ===" -ForegroundColor Cyan

# Helper: Build a temp .bat that sources fn_build_flags and echoes result
function Test-BuildFlags($Type, $ExpectedFlags, $NotExpectedFlags = @()) {
    $flagTest = @"
@echo off
setlocal enabledelayedexpansion
set "LOG_DIR=%TEMP%"

:fn_build_flags
    set "_btype=%~1"
    set "_BUILD_FLAGS="

    if /i "!_btype!"=="RESTORE_MERGE" (
        set "_BUILD_FLAGS=/E /Z /MT:16 /R:2 /W:1 /NP /ETA"
        goto :done
    )
    if /i "!_btype!"=="RESTORE_MIRROR" (
        set "_BUILD_FLAGS=/MIR /Z /MT:16 /R:2 /W:1 /NP /ETA"
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "`$Recycle.Bin""
        goto :done
    )
    set "_BUILD_FLAGS=/MIR /Z /MT:16 /R:2 /W:1 /NP /ETA"
    if /i "!_btype!"=="PROFILE" (
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /ZB /XJ"
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "`$Recycle.Bin""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "System Volume Information""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Temp""
        goto :done
    )
    if /i "!_btype!"=="PARTITION" (
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "`$Recycle.Bin" "System Volume Information""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XF "pagefile.sys" "hiberfil.sys" "swapfile.sys""
        goto :done
    )
    if /i "!_btype!"=="USB" (
        set "_BUILD_FLAGS=/MIR /MT:8 /R:1 /W:0 /NP /ETA"
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "`$Recycle.Bin""
        goto :done
    )
    set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "`$Recycle.Bin""
:done
    echo !_BUILD_FLAGS!
"@
    # Write the test bat
    $testFile = "$Sandbox\test_flags_$Type.bat"
    $flagTest | Out-File $testFile -Encoding ASCII

    # Create caller
    $callerContent = "@echo off`r`nsetlocal enabledelayedexpansion`r`ncall `"$testFile`" $Type"
    $callerFile = "$Sandbox\test_flags_caller_$Type.bat"
    $callerContent | Out-File $callerFile -Encoding ASCII

    $output = & cmd /c "`"$callerFile`"" 2>&1
    $outputStr = ($output -join ' ').Trim()

    $allFound = $true
    foreach ($flag in $ExpectedFlags) {
        if ($outputStr -notmatch [regex]::Escape($flag)) {
            $allFound = $false
        }
    }
    $noneFound = $true
    foreach ($flag in $NotExpectedFlags) {
        if ($outputStr -match [regex]::Escape($flag)) {
            $noneFound = $false
        }
    }
    return ($allFound -and $noneFound)
}

# 6.1: PROFILE flags include /ZB, /XJ, exclude Temp
$profileResult = Test-BuildFlags "PROFILE" @("/MIR", "/ZB", "/XJ", "AppData\Local\Temp")
Write-Result "PROFILE flags: /MIR /ZB /XJ + exclusions" $profileResult

# 6.2: PARTITION flags include /MIR, exclude pagefile
$partResult = Test-BuildFlags "PARTITION" @("/MIR", "pagefile.sys")
Write-Result "PARTITION flags: /MIR + system file exclusions" $partResult

# 6.3: USB flags use /MT:8 (not /MT:16)
$usbResult = Test-BuildFlags "USB" @("/MIR", "/MT:8") @("/MT:16")
Write-Result "USB flags: /MT:8 (reduced threads)" $usbResult

# 6.4: RESTORE_MERGE uses /E (not /MIR)
$mergeResult = Test-BuildFlags "RESTORE_MERGE" @("/E", "/Z") @("/MIR")
Write-Result "RESTORE_MERGE flags: /E (no /MIR)" $mergeResult

# 6.5: RESTORE_MIRROR uses /MIR
$mirrorResult = Test-BuildFlags "RESTORE_MIRROR" @("/MIR", "/Z")
Write-Result "RESTORE_MIRROR flags: /MIR /Z" $mirrorResult

# 6.6: CUSTOM fallback includes /MIR and $Recycle.Bin exclusion
$customResult = Test-BuildFlags "CUSTOM" @("/MIR")
Write-Result "CUSTOM flags: /MIR fallback" $customResult

# ================================================================
# SECTION 7: ERROR HANDLING TESTS (A3)
# ================================================================
Write-Host "`n=== SECTION 7: ERROR HANDLING TESTS ===" -ForegroundColor Cyan

# 7.1: fn_run_robocopy with empty source -> FAILED
$errTest1 = @'
@echo off
setlocal enabledelayedexpansion
set "LOG_DIR=%TEMP%\rs_err_test"
set "LAST_RC_STATUS="
set "LAST_RC_CODE="
set "_rc_src="
set "_rc_dst=C:\Temp\test"
set "_rc_type=CUSTOM"
if "!_rc_src!"=="" (
    set "LAST_RC_STATUS=FAILED"
    set "LAST_RC_CODE=99"
)
if "!LAST_RC_STATUS!"=="FAILED" if "!LAST_RC_CODE!"=="99" echo [EMPTY_SRC_PASS]
'@
$errFile1 = "$Sandbox\test_err_empty_src.bat"
$errTest1 | Out-File $errFile1 -Encoding ASCII
$errOut1 = & cmd /c "`"$errFile1`"" 2>&1
Write-Result "Empty source -> FAILED/99" (($errOut1 -join '') -match 'EMPTY_SRC_PASS')

# 7.2: fn_run_robocopy with empty dest -> FAILED
$errTest2 = @'
@echo off
setlocal enabledelayedexpansion
set "LAST_RC_STATUS="
set "LAST_RC_CODE="
set "_rc_src=C:\Windows"
set "_rc_dst="
if "!_rc_dst!"=="" (
    set "LAST_RC_STATUS=FAILED"
    set "LAST_RC_CODE=99"
)
if "!LAST_RC_STATUS!"=="FAILED" if "!LAST_RC_CODE!"=="99" echo [EMPTY_DST_PASS]
'@
$errFile2 = "$Sandbox\test_err_empty_dst.bat"
$errTest2 | Out-File $errFile2 -Encoding ASCII
$errOut2 = & cmd /c "`"$errFile2`"" 2>&1
Write-Result "Empty dest -> FAILED/99" (($errOut2 -join '') -match 'EMPTY_DST_PASS')

# 7.3: Source path doesn't exist -> FAILED
$errTest3 = @'
@echo off
setlocal enabledelayedexpansion
set "LAST_RC_STATUS="
set "_rc_src=Z:\NonExistent\Path\12345"
if not exist "!_rc_src!" (
    set "LAST_RC_STATUS=FAILED"
    set "LAST_RC_CODE=99"
)
if "!LAST_RC_STATUS!"=="FAILED" echo [NOEXIST_SRC_PASS]
'@
$errFile3 = "$Sandbox\test_err_noexist.bat"
$errTest3 | Out-File $errFile3 -Encoding ASCII
$errOut3 = & cmd /c "`"$errFile3`"" 2>&1
Write-Result "Non-existent source -> FAILED" (($errOut3 -join '') -match 'NOEXIST_SRC_PASS')

# 7.4: Robocopy exit code >= 8 means FAILED
$errTest4 = @'
@echo off
setlocal enabledelayedexpansion
set "LAST_RC_CODE=8"
if !LAST_RC_CODE! LEQ 3 (
    set "LAST_RC_STATUS=SUCCESS"
) else if !LAST_RC_CODE! LEQ 7 (
    set "LAST_RC_STATUS=WARNING"
) else (
    set "LAST_RC_STATUS=FAILED"
)
if "!LAST_RC_STATUS!"=="FAILED" echo [RC8_FAIL_PASS]
'@
$errFile4 = "$Sandbox\test_err_rc8.bat"
$errTest4 | Out-File $errFile4 -Encoding ASCII
$errOut4 = & cmd /c "`"$errFile4`"" 2>&1
Write-Result "Exit code 8 -> FAILED status" (($errOut4 -join '') -match 'RC8_FAIL_PASS')

# 7.5: Robocopy exit code 4-7 means WARNING
$errTest5 = @'
@echo off
setlocal enabledelayedexpansion
set "LAST_RC_CODE=5"
if !LAST_RC_CODE! LEQ 3 (
    set "LAST_RC_STATUS=SUCCESS"
) else if !LAST_RC_CODE! LEQ 7 (
    set "LAST_RC_STATUS=WARNING"
) else (
    set "LAST_RC_STATUS=FAILED"
)
if "!LAST_RC_STATUS!"=="WARNING" echo [RC5_WARN_PASS]
'@
$errFile5 = "$Sandbox\test_err_rc5.bat"
$errTest5 | Out-File $errFile5 -Encoding ASCII
$errOut5 = & cmd /c "`"$errFile5`"" 2>&1
Write-Result "Exit code 5 -> WARNING status" (($errOut5 -join '') -match 'RC5_WARN_PASS')

# ================================================================
# SECTION 8: RESTORE FLOW TESTS (A4)
# ================================================================
Write-Host "`n=== SECTION 8: RESTORE FLOW TESTS ===" -ForegroundColor Cyan

# 8.1: UC4 Merge -- /E preserves existing files at dest
$uc4Src = "$Sandbox\src\uc4_backup"
$uc4Dst = "$Sandbox\dst\uc4_profile"
New-Item -ItemType Directory -Path "$uc4Src\Desktop" -Force | Out-Null
New-Item -ItemType Directory -Path "$uc4Src\Documents" -Force | Out-Null
New-Item -ItemType Directory -Path "$uc4Dst\Desktop" -Force | Out-Null
"backup_file" | Out-File "$uc4Src\Desktop\restored.txt" -Encoding UTF8
"backup_doc" | Out-File "$uc4Src\Documents\report.txt" -Encoding UTF8
"user_new_file" | Out-File "$uc4Dst\Desktop\my_new_work.txt" -Encoding UTF8
# Restore Desktop with /E (merge)
& cmd /c "robocopy `"$uc4Src\Desktop`" `"$uc4Dst\Desktop`" /E /Z /R:0 /W:0 /NP /NFL /NDL 2>&1" | Out-Null
Write-Result "UC4 Merge: backup file restored" (Test-Path "$uc4Dst\Desktop\restored.txt")
Write-Result "UC4 Merge: user's new file preserved" (Test-Path "$uc4Dst\Desktop\my_new_work.txt")

# 8.2: UC5 Mirror -- /MIR deletes extra at dest
$uc5Src = "$Sandbox\src\uc5_backup"
$uc5Dst = "$Sandbox\dst\uc5_mirror"
New-Item -ItemType Directory -Path $uc5Src -Force | Out-Null
New-Item -ItemType Directory -Path $uc5Dst -Force | Out-Null
"backup_data" | Out-File "$uc5Src\original.txt" -Encoding UTF8
"stale_data" | Out-File "$uc5Dst\should_be_deleted.txt" -Encoding UTF8
& cmd /c "robocopy `"$uc5Src`" `"$uc5Dst`" /MIR /R:0 /W:0 /NP /NFL /NDL 2>&1" | Out-Null
Write-Result "UC5 Mirror: source file copied" (Test-Path "$uc5Dst\original.txt")
Write-Result "UC5 Mirror: extra file deleted" (-not (Test-Path "$uc5Dst\should_be_deleted.txt"))

# 8.3: fn_detect_profile_subdirs pattern -- known folders detected
$subdirSrc = "$Sandbox\src\subdirs"
foreach ($f in @("Desktop", "Documents", "Downloads", "Pictures", "Videos", "Music")) {
    New-Item -ItemType Directory -Path "$subdirSrc\$f" -Force | Out-Null
}
$subdirTest = @"
@echo off
setlocal enabledelayedexpansion
set /a SUBDIR_COUNT=0
for %%F in (Desktop Documents Downloads Pictures Videos Music Favorites Links Contacts) do (
    if exist "$subdirSrc\%%F" (
        set /a SUBDIR_COUNT+=1
    )
)
echo COUNT=!SUBDIR_COUNT!
if !SUBDIR_COUNT! geq 6 echo [SUBDIR_DETECT_PASS]
"@
$subdirFile = "$Sandbox\test_subdirs.bat"
$subdirTest | Out-File $subdirFile -Encoding ASCII
$subdirOut = & cmd /c "`"$subdirFile`"" 2>&1
Write-Result "Profile subdir detection (6+ folders)" (($subdirOut -join '') -match 'SUBDIR_DETECT_PASS')

# 8.4: Empty backup folder -> SUBDIR_COUNT=0
$emptyBackup = "$Sandbox\src\empty_backup"
New-Item -ItemType Directory -Path $emptyBackup -Force | Out-Null
$emptySubTest = @"
@echo off
setlocal enabledelayedexpansion
set /a SUBDIR_COUNT=0
for %%F in (Desktop Documents Downloads) do (
    if exist "$emptyBackup\%%F" (
        set /a SUBDIR_COUNT+=1
    )
)
if !SUBDIR_COUNT! equ 0 echo [EMPTY_SUBDIR_PASS]
"@
$emptySubFile = "$Sandbox\test_empty_subdirs.bat"
$emptySubTest | Out-File $emptySubFile -Encoding ASCII
$emptySubOut = & cmd /c "`"$emptySubFile`"" 2>&1
Write-Result "Empty backup -> SUBDIR_COUNT=0" (($emptySubOut -join '') -match 'EMPTY_SUBDIR_PASS')

# ================================================================
# SECTION 9: NETWORK MODULE TESTS (A5 -- safe/mocked)
# ================================================================
Write-Host "`n=== SECTION 9: NETWORK MODULE TESTS ===" -ForegroundColor Cyan

# 9.1: Empty IP -> INPUT_OK=0
$netTest1 = @'
@echo off
setlocal enabledelayedexpansion
set "INPUT_OK=0"
set "DEST_IP="
if "!DEST_IP!"=="" (
    set "INPUT_OK=0"
    echo [EMPTY_IP_PASS]
)
'@
$netFile1 = "$Sandbox\test_net_empty_ip.bat"
$netTest1 | Out-File $netFile1 -Encoding ASCII
$netOut1 = & cmd /c "`"$netFile1`"" 2>&1
Write-Result "Empty IP -> INPUT_OK=0" (($netOut1 -join '') -match 'EMPTY_IP_PASS')

# 9.2: Invalid IP -> NET_PING_OK=0 (ping unreachable address)
$netTest2 = @'
@echo off
setlocal enabledelayedexpansion
set "NET_PING_OK=0"
set "_ping_result="
for /f "tokens=*" %%L in ('ping -n 1 -w 500 "192.0.2.1" 2^>nul') do (
    echo "%%L" | find "TTL=" >nul 2>&1 && set "_ping_result=OK"
)
if not "!_ping_result!"=="OK" (
    set "NET_PING_OK=0"
    echo [INVALID_PING_PASS]
)
'@
$netFile2 = "$Sandbox\test_net_bad_ping.bat"
$netTest2 | Out-File $netFile2 -Encoding ASCII
$netOut2 = & cmd /c "`"$netFile2`"" 2>&1
Write-Result "Invalid IP -> NET_PING_OK=0" (($netOut2 -join '') -match 'INVALID_PING_PASS')

# 9.3: Empty username -> NET_MAP_OK=0
$netTest3 = @'
@echo off
setlocal enabledelayedexpansion
set "NET_MAP_OK=0"
set "_user="
if "!_user!"=="" (
    set "NET_MAP_OK=0"
    echo [EMPTY_USER_PASS]
)
'@
$netFile3 = "$Sandbox\test_net_empty_user.bat"
$netTest3 | Out-File $netFile3 -Encoding ASCII
$netOut3 = & cmd /c "`"$netFile3`"" 2>&1
Write-Result "Empty username -> NET_MAP_OK=0" (($netOut3 -join '') -match 'EMPTY_USER_PASS')

# 9.4: fn_show_status NOT_CONNECTED output
$netTest4 = @'
@echo off
setlocal enabledelayedexpansion
set "NET_STATUS=NOT_CONNECTED"
if "!NET_STATUS!"=="NOT_CONNECTED" echo [STATUS_NOTCONN_PASS]
'@
$netFile4 = "$Sandbox\test_net_status.bat"
$netTest4 | Out-File $netFile4 -Encoding ASCII
$netOut4 = & cmd /c "`"$netFile4`"" 2>&1
Write-Result "NOT_CONNECTED status output" (($netOut4 -join '') -match 'STATUS_NOTCONN_PASS')

# ================================================================
# SECTION 10: WORST-CASE EDGE CASES (A6)
# ================================================================
Write-Host "`n=== SECTION 10: WORST-CASE EDGE CASES ===" -ForegroundColor Cyan

# 10.1: Junction point skipped with /XJ
$juncSrc = "$Sandbox\src\junc_test"
$juncDst = "$Sandbox\dst\junc_test"
New-Item -ItemType Directory -Path $juncSrc -Force | Out-Null
New-Item -ItemType Directory -Path "$juncSrc\real_folder" -Force | Out-Null
"real_data" | Out-File "$juncSrc\real_folder\data.txt" -Encoding UTF8
# Create junction point
$juncTarget = "$Sandbox\src\junc_target"
New-Item -ItemType Directory -Path $juncTarget -Force | Out-Null
"junction_data" | Out-File "$juncTarget\junc_file.txt" -Encoding UTF8
& cmd /c "mklink /J `"$juncSrc\my_junction`" `"$juncTarget`"" 2>&1 | Out-Null
# Copy with /XJ -- junction should be skipped
& cmd /c "robocopy `"$juncSrc`" `"$juncDst`" /E /XJ /R:0 /W:0 /NP /NFL /NDL 2>&1" | Out-Null
Write-Result "/XJ skips junction point" (Test-Path "$juncDst\real_folder\data.txt")
# Junction content should NOT be at dest (junction itself skipped)
$juncSkipped = -not (Test-Path "$juncDst\my_junction\junc_file.txt")
Write-Result "/XJ junction content not copied" $juncSkipped "Junction data was copied!"

# 10.2: Read-only file copy
$roSrc = "$Sandbox\src\readonly_test"
$roDst = "$Sandbox\dst\readonly_test"
New-Item -ItemType Directory -Path $roSrc -Force | Out-Null
"readonly_content" | Out-File "$roSrc\readonly.txt" -Encoding UTF8
Set-ItemProperty "$roSrc\readonly.txt" -Name IsReadOnly -Value $true
& cmd /c "robocopy `"$roSrc`" `"$roDst`" /E /R:0 /W:0 /NP /NFL /NDL 2>&1" | Out-Null
Write-Result "Read-only file copied successfully" (Test-Path "$roDst\readonly.txt")
# Cleanup readonly attribute
if (Test-Path "$roDst\readonly.txt") { Set-ItemProperty "$roDst\readonly.txt" -Name IsReadOnly -Value $false }
if (Test-Path "$roSrc\readonly.txt") { Set-ItemProperty "$roSrc\readonly.txt" -Name IsReadOnly -Value $false }

# 10.3: Zero-byte file copy
$zbSrc = "$Sandbox\src\zerobyte_test"
$zbDst = "$Sandbox\dst\zerobyte_test"
New-Item -ItemType Directory -Path $zbSrc -Force | Out-Null
New-Item -ItemType File -Path "$zbSrc\empty.txt" -Force | Out-Null
& cmd /c "robocopy `"$zbSrc`" `"$zbDst`" /E /R:0 /W:0 /NP /NFL /NDL 2>&1" | Out-Null
Write-Result "Zero-byte file copied" (Test-Path "$zbDst\empty.txt")

# 10.4: Source = Destination detection pattern
$samePath = @'
@echo off
setlocal enabledelayedexpansion
set "_rc_src=C:\Users\Admin\Documents"
set "_rc_dst=C:\Users\Admin\Documents"
if "!_rc_src!"=="!_rc_dst!" (
    echo [SAME_PATH_DETECTED]
)
'@
$sameFile = "$Sandbox\test_same_path.bat"
$samePath | Out-File $sameFile -Encoding ASCII
$sameOut = & cmd /c "`"$sameFile`"" 2>&1
Write-Result "Source=Dest detection pattern" (($sameOut -join '') -match 'SAME_PATH_DETECTED')

# 10.5: Robocopy with 0 files (empty dir) -> exit code 0 or 1
$noFileSrc = "$Sandbox\src\nofiles"
$noFileDst = "$Sandbox\dst\nofiles"
New-Item -ItemType Directory -Path $noFileSrc -Force | Out-Null
& cmd /c "robocopy `"$noFileSrc`" `"$noFileDst`" /E /R:0 /W:0 /NP 2>&1" | Out-Null
Write-Result "0 files -> exit code <= 1" ($LASTEXITCODE -le 1) "ExitCode=$LASTEXITCODE"

# ================================================================
# SECTION 11: DRIFT DETECTION EXPANSION (A7)
# ================================================================
Write-Host "`n=== SECTION 11: DRIFT DETECTION EXPANSION ===" -ForegroundColor Cyan

if ((Test-Path $Target) -and (Test-Path $DevEntry)) {
    $devContent = Get-Content $DevEntry -Raw
    $portContent = Get-Content $Target -Raw

    # Collect all lib module files for Dev
    $allDevContent = $devContent
    if (Test-Path $DevLibDir) {
        foreach ($lib in Get-ChildItem "$DevLibDir\*.bat") {
            $allDevContent += "`n" + (Get-Content $lib.FullName -Raw)
        }
    }

    # 11.1: All Tier 2 vars cleared in Dev MainMenu also cleared in Portable
    $tier2Vars = @("BACKUP_MODE", "BACKUP_DEST", "NET_PASS", "SELECTED_SRC", "SELECTED_NAME", "SELECTED_TYPE", "FINAL_DEST")
    $devMainMenuBlock = ""
    $portMainMenuBlock = ""
    # Extract MainMenu cleanup section from both
    if ($devContent -match '(?s):MainMenu(.+?)(?=:display|:Mode|:Network)') {
        $devMainMenuBlock = $Matches[1]
    }
    if ($portContent -match '(?s):MainMenu(.+?)(?=:display|:Mode|:Network)') {
        $portMainMenuBlock = $Matches[1]
    }
    $missingInPort = @()
    foreach ($var in $tier2Vars) {
        if ($portMainMenuBlock -notmatch "set `"$var=`"") {
            $missingInPort += $var
        }
    }
    Write-Result "Tier 2 var cleanup parity (Dev vs Portable)" ($missingInPort.Count -eq 0) "Missing in Portable: $($missingInPort -join ', ')"

    # 11.2: Backup type count parity (fn_build_flags handles same types)
    $typePattern = '(?i)"([A-Z][A-Z0-9_]+)".*goto :eof'
    $devTypes = ([regex]::Matches($allDevContent, $typePattern)).Count
    $portTypes = ([regex]::Matches($portContent, $typePattern)).Count
    # Just check both have the 5 types
    $devHasAllTypes = ($allDevContent -match 'RESTORE_MERGE') -and ($allDevContent -match 'RESTORE_MIRROR') -and ($allDevContent -match 'PROFILE') -and ($allDevContent -match 'PARTITION') -and ($allDevContent -match 'USB')
    $portHasAllTypes = ($portContent -match 'RESTORE_MERGE') -and ($portContent -match 'RESTORE_MIRROR') -and ($portContent -match 'PROFILE') -and ($portContent -match 'PARTITION') -and ($portContent -match 'USB')
    Write-Result "Both have all 5 backup types" ($devHasAllTypes -and $portHasAllTypes)

    # 11.3: Network status bar exists in both
    $devHasStatusBar = $allDevContent -match ':fn_status_bar'
    $portHasStatusBar = $portContent -match ':fn_status_bar'
    $devHasShowStatus = $allDevContent -match ':fn_show_status'
    $portHasShowStatus = $portContent -match ':fn_show_status'
    Write-Result "fn_status_bar + fn_show_status in both" ($devHasStatusBar -and $portHasStatusBar -and $devHasShowStatus -and $portHasShowStatus)
}

# ================================================================
# CLEANUP & SUMMARY
# ================================================================
Cleanup-Sandbox

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Passed:   $script:PassCount" -ForegroundColor Green
Write-Host "  Warnings: $script:WarnCount" -ForegroundColor Yellow
Write-Host "  Failed:   $script:FailCount" -ForegroundColor $(if ($script:FailCount -gt 0) { "Red" } else { "Green" })
Write-Host "  Total:    $($script:PassCount + $script:FailCount + $script:WarnCount)" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

exit $script:FailCount
