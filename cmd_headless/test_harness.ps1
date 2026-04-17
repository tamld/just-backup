# ================================================================
# TEST HARNESS v3.0 — Comprehensive CMD Batch Verification
# PURPOSE: Static lint + Safe runtime + WORST-CASE edge cases
#          + v2.0 refactor validation + drift detection
#          PowerShell is BANNED from production, ESSENTIAL for testing.
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
