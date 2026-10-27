@echo off
:: ================================================================
::   ROBOSYNC PORTABLE v2.0.0 — SINGLE-FILE DISTRIBUTION
::   Engine : Robocopy  |  Auth : Net Use  |  Format : Pure CMD
::
::   This is the PRODUCTION build. One file, zero folders.
::   For the modular DEV version, see: cmd_headless/RoboSync.bat
::
:: ================================================================
:: FILE SKELETON (Navigation Map)
:: ================================================================
::
::   LINE RANGE    SECTION
::   ─────────────────────────────────────
::   001 - 080     BOOTSTRAP (chcp, UAC, globals)
::   081 - 120     MAIN MENU + Pipeline Cleanup
::   121 - 175     NETWORK SETUP (shared flow)
::   176 - 340     MODE 1-3: PUSH / PULL / LOCAL + Source Selection
::   341 - 530     MODE 4: RESTORE (UC4 + UC5)
::   531 - 560     CLEANUP + EXIT
::   ─────────────────────────────────────
::   561+          FUNCTION LIBRARY (all :fn_ labels)
::     :fn_banner, :fn_separator, :fn_pause_msg
::     :fn_select_network_type, :fn_setup_direct_cable
::     :fn_restore_dhcp, :fn_input_credentials
::     :fn_test_connection, :fn_map_credentials
::     :fn_unmap_credentials, :fn_cleanup_all
::     :fn_detect_profiles, :fn_detect_partitions
::     :fn_detect_remote, :fn_detect_profile_subdirs
::     :fn_get_timestamp, :fn_run_robocopy, :fn_build_flags
::
:: ================================================================

:: --- UNICODE SUPPORT ---
chcp 65001 >nul 2>&1

:: --- ADMIN CHECK ---
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo  Requesting Administrator privileges...
    call :request_admin
    exit /b
)

goto :goADMIN

:request_admin
    set "vbsFile=%temp%\rs_getadmin.vbs"
    >"%vbsFile%" echo Set UAC = CreateObject("Shell.Application")
    set "params=%*"
    set "params=%params:"=\"%"
    >>"%vbsFile%" echo UAC.ShellExecute "cmd.exe", "/c \"%~s0\" %params%", "", "runas", 1
    cscript //nologo "%vbsFile%"
    del "%vbsFile%"
    exit /b

:goADMIN
    pushd "%CD%"
    cd /d "%~dp0"

:: ================================================================
:: GLOBALS (Tier 1 — set once, never cleared)
:: ================================================================
setlocal enabledelayedexpansion

set "APP_VERSION=v2.0.0-portable"
set "SCRIPT_DIR=%~dp0"
set "LOG_DIR=%SCRIPT_DIR%logs"
set "NET_STATUS=NOT_CONNECTED"

:: ================================================================
:: MAIN MENU
:: Note: Network session vars persist across backup operations.
::       Only backup pipeline vars (Tier 2b + Tier 3) are cleared.
:: ================================================================
:MainMenu
    :: --- Clear Pipeline vars (Tier 2b: per-job) ---
    set "BACKUP_MODE="
    set "BACKUP_DEST="
    set "NET_PASS="
    set "RESTORE_BASE="
    :: --- Clear Selected (Tier 3) ---
    set "SELECTED_SRC="
    set "SELECTED_NAME="
    set "SELECTED_TYPE="
    set "FINAL_DEST="

    call :displayMainMenu
    choice /n /c 123456 /m "  Choose mode: "
    if !errorlevel! equ 6 goto :ExitApp
    if !errorlevel! equ 5 goto :NetworkMenu
    if !errorlevel! equ 4 goto :ModeRestore
    if !errorlevel! equ 3 goto :ModeLocal
    if !errorlevel! equ 2 goto :ModePull
    if !errorlevel! equ 1 goto :ModePush
    goto :MainMenu

:: ================================================================
:: DISPLAY: Main Menu
:: ================================================================
:displayMainMenu
    call :fn_banner

    echo        ========================================================
    echo        [1] Backup PUSH          - Local to Remote     : Press 1
    echo        [2] Backup PULL          - Remote to Local     : Press 2
    echo        [3] Backup LOCAL         - Local to Local      : Press 3
    echo        [4] Restore Profile      - Recover data        : Press 4
    echo        [5] Network Setup        - Configure network   : Press 5
    echo        [6] Exit                                       : Press 6
    echo        ========================================================
    call :fn_status_bar
    echo.
    goto :eof

:: ================================================================
:: NETWORK SETUP MENU (Optional — user-driven)
:: ================================================================
:NetworkMenu
    cls
    echo.
    echo  [^>^>] NETWORK SETUP
    call :fn_separator
    call :fn_show_status
    call :displayNetworkMenu
    choice /n /c 12340 /m "  Choose: "
    if !errorlevel! equ 5 goto :MainMenu
    if !errorlevel! equ 4 goto :NetworkShowStatus
    if !errorlevel! equ 3 goto :NetworkDisconnect
    if !errorlevel! equ 2 goto :NetworkConnectDHCP
    if !errorlevel! equ 1 goto :NetworkConnectDirect
    goto :NetworkMenu

:displayNetworkMenu
    echo.
    echo   [1] Connect via Direct Cable ^(Static IP^)
    echo   [2] Connect via Existing Network ^(DHCP^)
    echo   [3] Disconnect ^& Reset
    echo   [4] Show Connection Status
    echo   [0] Back to Main Menu
    echo.
    goto :eof

:NetworkConnectDirect
    set "NET_TYPE=DIRECT"
    call :fn_setup_direct_cable
    if "!DIRECT_SETUP_OK!"=="0" (
        call :fn_pause_msg "Direct cable setup failed."
        goto :NetworkMenu
    )
    call :fn_input_credentials
    if "!INPUT_OK!"=="0" (
        call :fn_pause_msg "Invalid input."
        goto :NetworkMenu
    )
    call :fn_test_connection "!DEST_IP!"
    if "!NET_PING_OK!"=="0" (
        call :fn_pause_msg
        goto :NetworkMenu
    )
    call :fn_map_credentials "!DEST_IP!" "!NET_USER!" "!NET_PASS!"
    set "NET_PASS="
    if "!NET_MAP_OK!"=="0" (
        call :fn_pause_msg
        goto :NetworkMenu
    )
    set "NETWORK_PATH=\\!DEST_IP!\!DEST_SHARE!"
    call :fn_pause_msg "[OK] Network connected successfully."
    goto :NetworkMenu

:NetworkConnectDHCP
    set "NET_TYPE=DHCP"
    call :fn_input_credentials
    if "!INPUT_OK!"=="0" (
        call :fn_pause_msg "Invalid input."
        goto :NetworkMenu
    )
    call :fn_test_connection "!DEST_IP!"
    if "!NET_PING_OK!"=="0" (
        call :fn_pause_msg
        goto :NetworkMenu
    )
    call :fn_map_credentials "!DEST_IP!" "!NET_USER!" "!NET_PASS!"
    set "NET_PASS="
    if "!NET_MAP_OK!"=="0" (
        call :fn_pause_msg
        goto :NetworkMenu
    )
    set "NETWORK_PATH=\\!DEST_IP!\!DEST_SHARE!"
    call :fn_pause_msg "[OK] Network connected successfully."
    goto :NetworkMenu

:NetworkDisconnect
    call :fn_cleanup_all
    set "DEST_IP="
    set "DEST_SHARE="
    set "NET_USER="
    set "NET_PASS="
    set "NETWORK_PATH="
    set "NET_TYPE="
    call :fn_pause_msg "[OK] Disconnected. All connections cleared."
    goto :NetworkMenu

:NetworkShowStatus
    cls
    echo.
    call :fn_show_status
    call :fn_pause_msg
    goto :NetworkMenu

:: ================================================================
:: NETWORK SETUP (Shared flow for Push/Pull/Restore-Network)
:: ================================================================
:NetworkSetup
    call :fn_select_network_type
    if "!NET_TYPE!"=="CANCEL" goto :MainMenu
    if "!NET_TYPE!"=="DIRECT" (
        call :fn_setup_direct_cable
        if "!DIRECT_SETUP_OK!"=="0" (
            call :fn_pause_msg "Direct cable setup failed."
            goto :MainMenu
        )
    )

    call :fn_input_credentials
    if "!INPUT_OK!"=="0" (
        call :fn_pause_msg "Invalid input."
        goto :CleanupAndMenu
    )

    call :fn_test_connection "!DEST_IP!"
    if "!NET_PING_OK!"=="0" (
        call :fn_pause_msg
        goto :CleanupAndMenu
    )

    call :fn_map_credentials "!DEST_IP!" "!NET_USER!" "!NET_PASS!"
    set "NET_PASS="
    if "!NET_MAP_OK!"=="0" (
        call :fn_pause_msg
        goto :CleanupAndMenu
    )
    goto :eof

:: ================================================================
:: MODE 1: PUSH (Local -> Remote)
:: ================================================================
:ModePush
    set "BACKUP_MODE=PUSH"
    title RoboSync Portable - PUSH
    cls
    echo.
    echo  [^>^>] BACKUP PUSH (Local -^> Remote)
    call :fn_separator

    REM Reuse existing network session if available (EC-2.1)
    if "!NET_STATUS!"=="CONNECTED" (
        echo  [OK] Using existing connection: !NETWORK_PATH!
        echo.
        choice /n /c YN /m "  Continue with this connection? [Y/N]: "
        if !errorlevel! equ 1 (
            set "BACKUP_DEST=!NETWORK_PATH!"
            goto :SelectSource
        )
    )
    call :NetworkSetup
    set "BACKUP_DEST=!NETWORK_PATH!"
    goto :SelectSource

:: ================================================================
:: MODE 2: PULL (Remote -> Local)
:: ================================================================
:ModePull
    set "BACKUP_MODE=PULL"
    title RoboSync Portable - PULL
    cls
    echo.
    echo  [^>^>] BACKUP PULL (Remote -^> Local)
    call :fn_separator

    REM Reuse existing network session if available (EC-2.1)
    if "!NET_STATUS!"=="CONNECTED" (
        echo  [OK] Using existing connection: !NETWORK_PATH!
        echo.
        choice /n /c YN /m "  Continue with this connection? [Y/N]: "
        if !errorlevel! equ 2 call :NetworkSetup
    ) else (
        call :NetworkSetup
    )
    echo.
    set "BACKUP_DEST="
    set /p "BACKUP_DEST=  Local save path (e.g. D:\Restore): "
    if "!BACKUP_DEST!"=="" (
        echo  [!!] Path is empty.
        goto :CleanupAndMenu
    )
    if not exist "!BACKUP_DEST!" mkdir "!BACKUP_DEST!" 2>nul
    set "REMOTE_SOURCE=!NETWORK_PATH!"
    goto :SelectRemoteSource

:: ================================================================
:: MODE 3: LOCAL
:: ================================================================
:ModeLocal
    set "BACKUP_MODE=LOCAL"
    title RoboSync Portable - LOCAL
    cls
    echo.
    echo  [^>^>] BACKUP LOCAL (Local -^> Local)
    call :fn_separator
    echo.
    set "BACKUP_DEST="
    set /p "BACKUP_DEST=  Destination path (e.g. E:\Backup): "
    if "!BACKUP_DEST!"=="" (
        echo  [!!] Path is empty.
        call :fn_pause_msg
        goto :MainMenu
    )
    goto :SelectSource

:: ================================================================
:: SELECT SOURCE (Push + Local)
:: ================================================================
:SelectSource
    cls
    echo.
    echo  [^>^>] SELECT BACKUP SOURCE
    echo  [--] Destination: !BACKUP_DEST!
    call :fn_separator
    echo.

    call :fn_detect_profiles
    call :fn_detect_partitions

    set /a _TOTAL=0

    if !PROFILE_COUNT! gtr 0 (
        echo   --- USER PROFILES ---
        for /l %%i in (1,1,!PROFILE_COUNT!) do (
            set /a _TOTAL+=1
            call set "_p=%%PROFILE_%%i_PATH%%"
            call set "_n=%%PROFILE_%%i_NAME%%"
            set "SRC_!_TOTAL!_PATH=!_p!"
            set "SRC_!_TOTAL!_NAME=Profile_!_n!"
            set "SRC_!_TOTAL!_TYPE=PROFILE"
            echo   [!_TOTAL!] !_n!  ^|  !_p!
        )
        echo.
    )

    if !PART_COUNT! gtr 0 (
        echo   --- DATA DRIVES ---
        for /l %%i in (1,1,!PART_COUNT!) do (
            set /a _TOTAL+=1
            call set "_p=%%PART_%%i_PATH%%"
            call set "_n=%%PART_%%i_NAME%%"
            call set "_dt=%%PART_%%i_TYPE%%"
            set "SRC_!_TOTAL!_PATH=!_p!"
            set "SRC_!_TOTAL!_NAME=!_n!"
            if /i "!_dt!"=="USB" (
                set "SRC_!_TOTAL!_TYPE=USB"
            ) else (
                set "SRC_!_TOTAL!_TYPE=PARTITION"
            )
            echo   [!_TOTAL!] !_n!  ^|  !_p!
        )
        echo.
    )

    echo   --- OPTIONS ---
    set /a _TOTAL+=1
    set "_IDX_CUSTOM=!_TOTAL!"
    echo   [!_TOTAL!] Enter path manually

    set /a _TOTAL+=1
    set "_IDX_ALL_P=!_TOTAL!"
    echo   [!_TOTAL!] Backup ALL Profiles

    set /a _TOTAL+=1
    set "_IDX_ALL_D=!_TOTAL!"
    echo   [!_TOTAL!] Backup ALL Partitions

    echo   [0] Go back
    echo.
    call :fn_separator

    set "_SC="
    set /p "_SC=  Choose [0-!_TOTAL!]: "

    if "!_SC!"=="0" goto :CleanupAndMenu

    if "!_SC!"=="!_IDX_ALL_P!" (
        for /l %%i in (1,1,!PROFILE_COUNT!) do (
            call set "SELECTED_SRC=%%PROFILE_%%i_PATH%%"
            call set "_pn=%%PROFILE_%%i_NAME%%"
            set "SELECTED_NAME=Profile_!_pn!"
            set "FINAL_DEST=!BACKUP_DEST!\!SELECTED_NAME!"
            if not exist "!FINAL_DEST!" mkdir "!FINAL_DEST!" 2>nul
            call :fn_run_robocopy "!SELECTED_SRC!" "!FINAL_DEST!" "PROFILE"
        )
        call :fn_pause_msg "[OK] All Profiles backed up."
        goto :SelectSource
    )

    if "!_SC!"=="!_IDX_ALL_D!" (
        for /l %%i in (1,1,!PART_COUNT!) do (
            call set "SELECTED_SRC=%%PART_%%i_PATH%%"
            call set "SELECTED_NAME=%%PART_%%i_NAME%%"
            set "FINAL_DEST=!BACKUP_DEST!\!SELECTED_NAME!"
            if not exist "!FINAL_DEST!" mkdir "!FINAL_DEST!" 2>nul
            call :fn_run_robocopy "!SELECTED_SRC!" "!FINAL_DEST!" "PARTITION"
        )
        call :fn_pause_msg "[OK] All Partitions backed up."
        goto :SelectSource
    )

    if "!_SC!"=="!_IDX_CUSTOM!" (
        set "SELECTED_SRC="
        set /p "SELECTED_SRC=  Source path: "
        if "!SELECTED_SRC!"=="" goto :SelectSource
        set "SELECTED_NAME=Custom"
        set "SELECTED_TYPE=CUSTOM"
        goto :ConfirmAndRun
    )

    call set "SELECTED_SRC=%%SRC_!_SC!_PATH%%"
    call set "SELECTED_NAME=%%SRC_!_SC!_NAME%%"
    call set "SELECTED_TYPE=%%SRC_!_SC!_TYPE%%"
    if "!SELECTED_SRC!"=="" (
        echo  [!!] Invalid selection.
        timeout /t 2 >nul
        goto :SelectSource
    )
    goto :ConfirmAndRun

:: ================================================================
:: SELECT REMOTE SOURCE (Pull mode)
:: ================================================================
:SelectRemoteSource
    cls
    echo.
    echo  [^>^>] SELECT REMOTE SOURCE
    echo  [--] Remote: !REMOTE_SOURCE!
    echo  [--] Local:  !BACKUP_DEST!
    call :fn_separator
    echo.

    call :fn_detect_remote "!REMOTE_SOURCE!"

    set /a _TOTAL=0
    if !REMOTE_COUNT! gtr 0 (
        echo   --- FOLDERS ---
        for /l %%i in (1,1,!REMOTE_COUNT!) do (
            set /a _TOTAL+=1
            call set "_rname=%%REMOTE_%%i_NAME%%"
            echo   [!_TOTAL!] !_rname!
        )
        echo.
    )

    echo   --- OPTIONS ---
    set /a _TOTAL+=1
    set "_IDX_CUSTOM=!_TOTAL!"
    echo   [!_TOTAL!] Enter path manually
    set /a _TOTAL+=1
    set "_IDX_ALL=!_TOTAL!"
    echo   [!_TOTAL!] Copy ENTIRE share
    echo   [0] Go back
    echo.
    set "_RC="
    set /p "_RC=  Choose [0-!_TOTAL!]: "

    if "!_RC!"=="0" goto :CleanupAndMenu
    if "!_RC!"=="!_IDX_ALL!" (
        call :fn_run_robocopy "!REMOTE_SOURCE!" "!BACKUP_DEST!" "CUSTOM"
        call :fn_pause_msg
        goto :SelectRemoteSource
    )
    if "!_RC!"=="!_IDX_CUSTOM!" (
        set "_custom="
        set /p "_custom=  Remote path: "
        if "!_custom!"=="" goto :SelectRemoteSource
        call :fn_run_robocopy "!_custom!" "!BACKUP_DEST!" "CUSTOM"
        call :fn_pause_msg
        goto :SelectRemoteSource
    )

    call set "SELECTED_SRC=%%REMOTE_!_RC!_PATH%%"
    call set "SELECTED_NAME=%%REMOTE_!_RC!_NAME%%"
    if "!SELECTED_SRC!"=="" (
        echo  [!!] Invalid selection.
        timeout /t 2 >nul
        goto :SelectRemoteSource
    )
    set "_rdst=!BACKUP_DEST!\!SELECTED_NAME!"
    if not exist "!_rdst!" mkdir "!_rdst!" 2>nul
    call :fn_run_robocopy "!SELECTED_SRC!" "!_rdst!" "CUSTOM"
    call :fn_pause_msg
    goto :SelectRemoteSource

:: ================================================================
:: CONFIRM AND RUN
:: ================================================================
:ConfirmAndRun
    set "FINAL_DEST=!BACKUP_DEST!\!SELECTED_NAME!"
    echo.
    echo  [^>^>] CONFIRM BACKUP
    call :fn_separator
    echo  [--] Source : !SELECTED_SRC!
    echo  [--] Dest   : !FINAL_DEST!
    echo  [--] Type   : !SELECTED_TYPE!
    call :fn_separator
    echo.
    choice /n /c YN /m "  Run backup? [Y/N]: "
    if !errorlevel! equ 2 goto :SelectSource

    if not exist "!FINAL_DEST!" mkdir "!FINAL_DEST!" 2>nul
    call :fn_run_robocopy "!SELECTED_SRC!" "!FINAL_DEST!" "!SELECTED_TYPE!"
    call :fn_pause_msg
    goto :SelectSource

:: ================================================================
:: MODE 4: RESTORE USER PROFILE
:: ================================================================
:ModeRestore
    set "BACKUP_MODE=RESTORE"
    title RoboSync Portable - RESTORE
    cls
    echo.
    echo  [^>^>] RESTORE USER PROFILE
    call :fn_separator
    echo.
    echo  [--] Select backup source location:
    echo.
    echo   [1] Local folder on this PC
    echo   [2] Network folder ^(requires auth^)
    echo   [0] Go back
    echo.
    choice /n /c 120 /m "  Choose: "
    if !errorlevel! equ 3 goto :MainMenu
    if !errorlevel! equ 2 goto :RestoreFromNetwork
    if !errorlevel! equ 1 goto :RestoreFromLocal
    goto :MainMenu

:RestoreFromLocal
    echo.
    set "RESTORE_BASE="
    set /p "RESTORE_BASE=  Backup folder path (e.g. E:\Backup): "
    if "!RESTORE_BASE!"=="" (
        echo  [!!] Path is empty.
        call :fn_pause_msg
        goto :ModeRestore
    )
    if not exist "!RESTORE_BASE!" (
        echo  [!!] Path does not exist: !RESTORE_BASE!
        call :fn_pause_msg
        goto :ModeRestore
    )
    goto :SelectRestoreSource

:RestoreFromNetwork
    call :NetworkSetup
    set "RESTORE_BASE=!NETWORK_PATH!"
    goto :SelectRestoreSource

:SelectRestoreSource
    cls
    echo.
    echo  [^>^>] SELECT BACKUP PROFILE TO RESTORE
    echo  [--] Folder: !RESTORE_BASE!
    call :fn_separator
    echo.

    set /a _TOTAL=0
    for /d %%D in ("!RESTORE_BASE!\*") do (
        set /a _TOTAL+=1
        set "RS_!_TOTAL!_PATH=%%D"
        set "RS_!_TOTAL!_NAME=%%~nxD"
        echo   [!_TOTAL!] %%~nxD
    )

    if !_TOTAL! equ 0 (
        echo  [--] No folders found.
        call :fn_pause_msg
        goto :ModeRestore
    )

    echo.
    echo   [0] Go back
    echo.
    set "_RS="
    set /p "_RS=  Choose backup: "
    if "!_RS!"=="0" goto :CleanupAndMenu
    if "!_RS!"=="" goto :SelectRestoreSource

    call set "SELECTED_SRC=%%RS_!_RS!_PATH%%"
    call set "SELECTED_NAME=%%RS_!_RS!_NAME%%"
    if "!SELECTED_SRC!"=="" (
        echo  [!!] Invalid selection.
        timeout /t 2 >nul
        goto :SelectRestoreSource
    )

    echo.
    echo  [^>^>] SELECT RESTORE MODE
    call :fn_separator
    echo  [--] Source: !SELECTED_NAME!
    echo.
    echo   [A] Restore into existing Profile
    echo       Merge subfolders - does NOT delete old files.
    echo.
    echo   [B] Restore to designated path
    echo       Full mirror copy.
    echo.
    echo   [0] Go back
    echo.
    choice /n /c AB0 /m "  Choose [A/B/0]: "
    if !errorlevel! equ 3 goto :SelectRestoreSource
    if !errorlevel! equ 2 goto :RestoreToPath
    if !errorlevel! equ 1 goto :RestoreIntoProfile
    goto :SelectRestoreSource

:: ================================================================
:: UC4: RESTORE INTO EXISTING PROFILE
:: ================================================================
:RestoreIntoProfile
    cls
    echo.
    echo  [^>^>] RESTORE INTO EXISTING PROFILE
    echo  [--] Backup: !SELECTED_SRC!
    call :fn_separator
    echo.

    call :fn_detect_profiles
    if !PROFILE_COUNT! equ 0 (
        echo  [!!] No profiles found on this PC.
        call :fn_pause_msg
        goto :SelectRestoreSource
    )

    echo  [--] Choose target profile:
    echo.
    for /l %%i in (1,1,!PROFILE_COUNT!) do (
        call set "_pn=%%PROFILE_%%i_NAME%%"
        call set "_pp=%%PROFILE_%%i_PATH%%"
        echo   [%%i] !_pn!  ^|  !_pp!
    )
    echo.
    echo   [0] Go back
    echo.
    set "_RP="
    set /p "_RP=  Choose profile [0-!PROFILE_COUNT!]: "
    if "!_RP!"=="" goto :RestoreIntoProfile
    if "!_RP!"=="0" goto :SelectRestoreSource

    call set "_dest_profile=%%PROFILE_!_RP!_PATH%%"
    if "!_dest_profile!"=="" (
        echo  [!!] Invalid selection.
        timeout /t 2 >nul
        goto :RestoreIntoProfile
    )

    call :fn_detect_profile_subdirs "!SELECTED_SRC!"
    if !SUBDIR_COUNT! equ 0 (
        echo  [!!] No subfolders found in backup.
        call :fn_pause_msg
        goto :SelectRestoreSource
    )

    echo.
    echo  [^>^>] CONFIRM RESTORE
    call :fn_separator
    echo  [--] Source : !SELECTED_SRC!
    echo  [--] Into   : !_dest_profile!
    echo  [--] Mode   : MERGE ^(/E^)
    echo  [--] Folders:
    for /l %%i in (1,1,!SUBDIR_COUNT!) do (
        call set "_sd=%%SUBDIR_%%i_NAME%%"
        echo       - !_sd!
    )
    call :fn_separator
    echo.
    choice /n /c YN /m "  Start restore? [Y/N]: "
    if !errorlevel! equ 2 goto :SelectRestoreSource

    echo.
    for /l %%i in (1,1,!SUBDIR_COUNT!) do (
        call set "_sd=%%SUBDIR_%%i_NAME%%"
        set "_s=!SELECTED_SRC!\!_sd!"
        set "_d=!_dest_profile!\!_sd!"
        echo  [--] Restoring: !_sd!
        if not exist "!_d!" mkdir "!_d!" 2>nul
        call :fn_run_robocopy "!_s!" "!_d!" "RESTORE_MERGE"
    )
    echo.
    call :fn_pause_msg "[OK] Restore complete."
    goto :SelectRestoreSource

:: ================================================================
:: UC5: RESTORE TO DESIGNATED PATH
:: ================================================================
:RestoreToPath
    echo.
    set "_rdest="
    set /p "_rdest=  Destination path (e.g. D:\Restored\Admin): "
    if "!_rdest!"=="" (
        echo  [!!] Path is empty.
        call :fn_pause_msg
        goto :SelectRestoreSource
    )

    echo.
    echo  [^>^>] CONFIRM RESTORE
    call :fn_separator
    echo  [--] Source : !SELECTED_SRC!
    echo  [--] Dest   : !_rdest!
    echo  [--] Mode   : MIRROR ^(/MIR^)
    call :fn_separator
    echo.
    choice /n /c YN /m "  Start restore? [Y/N]: "
    if !errorlevel! equ 2 goto :SelectRestoreSource

    call :fn_run_robocopy "!SELECTED_SRC!" "!_rdest!" "RESTORE_MIRROR"
    echo.
    call :fn_pause_msg "[OK] Restore complete."
    goto :SelectRestoreSource

:: ================================================================
:: CLEANUP AND MENU
:: ================================================================
:CleanupAndMenu
    if defined DEST_IP call :fn_unmap_credentials "!DEST_IP!"
    if defined NET_IFACE call :fn_restore_dhcp
    goto :MainMenu

:: ================================================================
:: EXIT
:: ================================================================
:ExitApp
    cls
    echo.
    call :fn_cleanup_all
    echo.
    echo  Thank you for using RoboSync!
    echo.
    timeout /t 2 >nul
    endlocal
    exit /b 0

:: ================================================================
::
::             F U N C T I O N   L I B R A R Y
::
::   All :fn_ labels below. Called via: call :fn_name "args"
::   No module dispatchers needed in single-file mode.
::
:: ================================================================

:: === UI FUNCTIONS ================================================

:fn_banner
    cls
    echo.
    echo   ╔═══════════════════════════════════════════════════════╗
    echo   ║          ROBOSYNC PORTABLE  %APP_VERSION%            ║
    echo   ║          Fast Backup ^& Restore Engine                ║
    echo   ╚═══════════════════════════════════════════════════════╝
    echo.
    goto :eof

:fn_separator
    echo  ────────────────────────────────────────────────────────
    goto :eof

:fn_pause_msg
    if not "%~1"=="" echo  %~1
    echo.
    pause
    goto :eof

:fn_status_bar
    if "!NET_STATUS!"=="CONNECTED" (
        echo        [Network: CONNECTED - !NETWORK_PATH!]
    ) else (
        echo        [Network: NOT CONNECTED]
    )
    goto :eof

:: === NETWORK FUNCTIONS ===========================================

:fn_select_network_type
    echo.
    echo  [^>^>] SELECT NETWORK MODE
    call :fn_separator
    echo   [1] Direct Cable ^(Static IP^)
    echo   [2] Existing Network ^(DHCP - Router / Modem^)
    echo   [0] Go back
    echo.
    choice /n /c 120 /m "  Choose: "
    if !errorlevel! equ 3 (
        set "NET_TYPE=CANCEL"
        goto :eof
    )
    if !errorlevel! equ 1 (
        set "NET_TYPE=DIRECT"
    ) else (
        set "NET_TYPE=DHCP"
    )
    echo  [--] Mode: !NET_TYPE!
    goto :eof

:fn_setup_direct_cable
    set "DIRECT_SETUP_OK=0"
    echo.
    echo  [^>^>] DIRECT CABLE SETUP (Static IP)
    call :fn_separator

    echo  [--] Available network interfaces:
    echo.
    for /f "tokens=1,2,3,4*" %%A in ('netsh interface show interface') do (
        echo   %%A %%B %%C %%D
    )
    echo.

    echo  [--] Default interface: Ethernet
    choice /n /c YN /m "  Use 'Ethernet'? [Y/N]: "
    if !errorlevel! equ 1 (
        set "NET_IFACE=Ethernet"
    ) else (
        set "NET_IFACE="
        set /p "NET_IFACE=  Enter interface name: "
        if "!NET_IFACE!"=="" goto :eof
    )

    echo.
    echo  [--] Suggested IP for direct cable:
    echo   This PC: 192.168.0.1  ^|  Remote PC: 192.168.0.2
    echo   Or     : 10.0.0.1     ^|  Remote PC: 10.0.0.2
    echo.
    set "NET_LOCAL_IP="
    set /p "NET_LOCAL_IP=  IP for THIS PC: "
    if "!NET_LOCAL_IP!"=="" goto :eof

    echo  [..] Setting static IP !NET_LOCAL_IP! on !NET_IFACE!...
    netsh interface ip set address "!NET_IFACE!" static !NET_LOCAL_IP! 255.255.255.0 >nul 2>&1
    if !errorlevel! neq 0 (
        echo  [!!] Failed to set IP. Check interface name.
        goto :eof
    )

    echo  [OK] Set !NET_LOCAL_IP! on !NET_IFACE!
    set "DIRECT_SETUP_OK=1"
    goto :eof

:fn_restore_dhcp
    if not defined NET_IFACE goto :eof
    if "!NET_IFACE!"=="" goto :eof
    echo  [..] Restoring DHCP on "!NET_IFACE!" ...
    netsh interface ip set address "!NET_IFACE!" dhcp >nul 2>&1
    set "RC=!errorlevel!"
    netsh interface ip set dns "!NET_IFACE!" dhcp >nul 2>&1
    if !RC! neq 0 (
        echo  [!!] Failed to restore DHCP on "!NET_IFACE!". Check manually via ncpa.cpl.
    ) else (
        echo  [OK] DHCP restored. Network will obtain new IP.
    )
    set "NET_IFACE="
    set "NET_LOCAL_IP="
    goto :eof

:fn_input_credentials
    set "INPUT_OK=0"
    echo.
    set "DEST_IP="
    set /p "DEST_IP=  Remote PC IP (e.g. 192.168.0.2): "
    if "!DEST_IP!"=="" goto :eof

    set "DEST_SHARE="
    set /p "DEST_SHARE=  Share name (e.g. C$, D$, Backup): "
    if "!DEST_SHARE!"=="" goto :eof

    set "NETWORK_PATH=\\!DEST_IP!\!DEST_SHARE!"

    set "NET_USER="
    set /p "NET_USER=  Username (e.g. Administrator): "
    if "!NET_USER!"=="" goto :eof

    echo  [--] Enter password:
    set "NET_PASS="
    for /f "tokens=*" %%P in ('powershell -Command "$p = Read-Host -AsSecureString; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p))" 2^>nul') do set "NET_PASS=%%P"
    if "!NET_PASS!"=="" (
        set /p "NET_PASS=  Password (plaintext fallback): "
    )
    if "!NET_PASS!"=="" goto :eof

    set "INPUT_OK=1"
    goto :eof

:fn_test_connection
    set "NET_PING_OK=0"
    echo.
    echo  [--] Pinging %~1 ...
    set "_ping_result="
    for /f "tokens=*" %%L in ('ping -n 2 -w 1500 "%~1" 2^>nul') do (
        echo "%%L" | find "TTL=" >nul 2>&1 && set "_ping_result=OK"
    )
    if "!_ping_result!"=="OK" (
        echo  [OK] %~1 is reachable.
        set "NET_PING_OK=1"
    ) else (
        echo  [!!] Cannot reach %~1
    )
    goto :eof

:fn_map_credentials
    set "NET_MAP_OK=0"
    echo  [--] Mapping \\%~1\!DEST_SHARE!...
    net use "!NETWORK_PATH!" /user:"%~2" "%~3" /persistent:no >nul 2>&1
    if !errorlevel! neq 0 (
        echo  [!!] Authentication failed.
        goto :eof
    )
    echo  [OK] Mapped successfully.
    set "NET_MAP_OK=1"
    set "NET_STATUS=CONNECTED"
    goto :eof

:fn_unmap_credentials
    echo  [--] Unmapping \\%~1\!DEST_SHARE!...
    net use "!NETWORK_PATH!" /delete /yes >nul 2>&1
    goto :eof

:fn_cleanup_all
    if defined DEST_IP call :fn_unmap_credentials "!DEST_IP!"
    if defined NET_IFACE call :fn_restore_dhcp
    set "NET_PASS="
    set "NET_STATUS=NOT_CONNECTED"
    set "NET_MAP_OK="
    goto :eof

:: === STATUS FUNCTIONS =============================================

:fn_get_connection_status
    set "NET_STATUS=NOT_CONNECTED"
    if not defined NETWORK_PATH goto :eof
    if "!NETWORK_PATH!"=="" goto :eof
    if not defined NET_MAP_OK goto :eof
    if "!NET_MAP_OK!"=="1" (
        set "NET_STATUS=CONNECTED"
    )
    goto :eof

:fn_show_status
    call :fn_get_connection_status
    echo.
    echo  [^>^>] NETWORK STATUS
    echo  ────────────────────────────────────────────────────────
    if "!NET_STATUS!"=="CONNECTED" (
        echo  [OK] Status   : CONNECTED
        echo  [--] Target   : !NETWORK_PATH!
        echo  [--] User     : !NET_USER!
        echo  [--] Mode     : !NET_TYPE!
        if defined NET_IFACE (
            echo  [--] Interface: !NET_IFACE! ^(Static IP: !NET_LOCAL_IP!^)
        )
    ) else (
        echo  [--] Status   : NOT CONNECTED
        echo  [--] Use Network Setup to configure connection.
    )
    echo  ────────────────────────────────────────────────────────
    echo.
    goto :eof

:: === DISCOVERY FUNCTIONS =========================================

:fn_detect_profiles
    set /a PROFILE_COUNT=0
    if not exist "C:\Users" goto :eof
    for /d %%U in (C:\Users\*) do (
        set "_uname=%%~nxU"
        if /i not "!_uname!"=="Public" (
        if /i not "!_uname!"=="Default" (
        if /i not "!_uname!"=="Default User" (
        if /i not "!_uname!"=="All Users" (
            set /a PROFILE_COUNT+=1
            set "PROFILE_!PROFILE_COUNT!_PATH=%%U"
            set "PROFILE_!PROFILE_COUNT!_NAME=!_uname!"
        ))))
    )
    goto :eof

:fn_detect_partitions
    set /a PART_COUNT=0
    for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        if exist "%%D:\" (
            set "_dtype=Fixed"
            set "_dlabel=Fixed Disk"
            for /f "tokens=*" %%T in ('fsutil fsinfo drivetype %%D: 2^>nul') do (
                set "_line=%%T"
                echo "!_line!" | find "Removable" >nul 2>&1 && (
                    set "_dtype=USB"
                    set "_dlabel=USB/Removable"
                )
                echo "!_line!" | find "CD-ROM" >nul 2>&1 && set "_dtype=CDROM"
            )
            if /i not "!_dtype!"=="CDROM" (
                set /a PART_COUNT+=1
                set "PART_!PART_COUNT!_PATH=%%D:\"
                set "PART_!PART_COUNT!_NAME=%%D: ^(!_dlabel!^)"
                set "PART_!PART_COUNT!_TYPE=!_dtype!"
            )
        )
    )
    goto :eof

:fn_detect_remote
    set /a REMOTE_COUNT=0
    if "%~1"=="" goto :eof
    for /d %%D in ("%~1\*") do (
        set /a REMOTE_COUNT+=1
        set "REMOTE_!REMOTE_COUNT!_PATH=%%D"
        set "REMOTE_!REMOTE_COUNT!_NAME=%%~nxD"
    )
    if !REMOTE_COUNT! equ 0 (
        echo  [--] Khong tim thay thu muc nao trong %~1
    )
    goto :eof

:fn_detect_profile_subdirs
    set /a SUBDIR_COUNT=0
    if "%~1"=="" goto :eof
    if not exist "%~1" goto :eof
    for %%F in (Desktop Documents Downloads Pictures Videos Music Favorites Links Contacts) do (
        if exist "%~1\%%F" (
            set /a SUBDIR_COUNT+=1
            set "SUBDIR_!SUBDIR_COUNT!_NAME=%%F"
        )
    )
    if exist "%~1\AppData\Roaming" (
        set /a SUBDIR_COUNT+=1
        set "SUBDIR_!SUBDIR_COUNT!_NAME=AppData\Roaming"
    )
    goto :eof

:: === ENGINE FUNCTIONS =============================================

:fn_get_timestamp
    set "_t=%time: =0%"
    set "TIMESTAMP=%date:~6,4%%date:~3,2%%date:~0,2%_%_t:~0,2%%_t:~3,2%%_t:~6,2%"
    set "TIMESTAMP=!TIMESTAMP:/=!"
    set "TIMESTAMP=!TIMESTAMP:-=!"
    set "TIMESTAMP=!TIMESTAMP: =0!"
    goto :eof

:fn_run_robocopy
    set "_rc_src=%~1"
    set "_rc_dst=%~2"
    set "_rc_type=%~3"

    if "!_rc_src!"=="" (
        echo  [!!] Source path trong. Huy.
        set "LAST_RC_STATUS=FAILED"
        goto :eof
    )
    if "!_rc_dst!"=="" (
        echo  [!!] Destination path trong. Huy.
        set "LAST_RC_STATUS=FAILED"
        goto :eof
    )
    if not exist "!_rc_src!" (
        echo  [!!] Source khong ton tai: !_rc_src!
        set "LAST_RC_STATUS=FAILED"
        goto :eof
    )
    REM Source = Destination guard (prevent self-copy)
    if "!_rc_src!"=="!_rc_dst!" (
        echo  [!!] Source and Destination are the same path. Aborting.
        set "LAST_RC_STATUS=FAILED"
        set "LAST_RC_CODE=99"
        goto :eof
    )

    if not exist "!_rc_dst!" (
        mkdir "!_rc_dst!" 2>nul
        if not exist "!_rc_dst!" (
            echo  [!!] Khong the tao thu muc dich: !_rc_dst!
            set "LAST_RC_STATUS=FAILED"
            goto :eof
        )
    )

    call :fn_get_timestamp
    if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" 2>nul
    set "_log_file=%LOG_DIR%\RS_!TIMESTAMP!.log"

    call :fn_build_flags "!_rc_type!"

    echo.
    echo  [^>^>] ROBOCOPY ENGINE
    echo  [--] Source : !_rc_src!
    echo  [--] Dest   : !_rc_dst!
    echo  [--] Type   : !_rc_type!
    echo  [--] Log    : !_log_file!
    echo.

    robocopy "!_rc_src!" "!_rc_dst!" !_BUILD_FLAGS! /LOG+:"!_log_file!" /TEE /V

    set "LAST_RC_CODE=!errorlevel!"

    echo.
    if !LAST_RC_CODE! LEQ 3 (
        set "LAST_RC_STATUS=SUCCESS"
        echo  [OK] Hoan tat. Code=!LAST_RC_CODE!
    ) else if !LAST_RC_CODE! LEQ 7 (
        set "LAST_RC_STATUS=WARNING"
        echo  [!!] Hoan tat voi canh bao. Code=!LAST_RC_CODE!
    ) else (
        set "LAST_RC_STATUS=FAILED"
        echo  [!!] LOI NGHIEM TRONG. Code=!LAST_RC_CODE!
    )
    echo  [--] Log: !_log_file!

    if /i "!LAST_RC_STATUS!"=="WARNING" pause
    if /i "!LAST_RC_STATUS!"=="FAILED" pause
    goto :eof

:fn_build_flags
    set "_btype=%~1"
    set "_BUILD_FLAGS="

    if /i "!_btype!"=="RESTORE_MERGE" (
        set "_BUILD_FLAGS=/E /Z /MT:16 /R:2 /W:1 /NP /ETA"
        goto :eof
    )
    if /i "!_btype!"=="RESTORE_MIRROR" (
        set "_BUILD_FLAGS=/MIR /Z /MT:16 /R:2 /W:1 /NP /ETA"
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "$Recycle.Bin""
        goto :eof
    )

    set "_BUILD_FLAGS=/MIR /Z /MT:16 /R:2 /W:1 /NP /ETA"

    if /i "!_btype!"=="PROFILE" (
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /ZB /XJ"
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "$Recycle.Bin""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "System Volume Information""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Temp""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\Windows\INetCache""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\Windows\Explorer""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\WindowsApps""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Packages""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Programs""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\CrashDumps""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\Windows\WER""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\Windows\Notifications""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\D3DSCache""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Google\Chrome\User Data\Default\Cache""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Google\Chrome\User Data\Default\Code Cache""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Microsoft\Edge\User Data\Default\Cache""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "AppData\Local\Mozilla\Firefox""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XF "ntuser.dat.LOG*" "*.tmp" "Thumbs.db" "desktop.ini""
        goto :eof
    )
    if /i "!_btype!"=="PARTITION" (
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "$Recycle.Bin" "System Volume Information""
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XF "pagefile.sys" "hiberfil.sys" "swapfile.sys""
        goto :eof
    )
    if /i "!_btype!"=="USB" (
        set "_BUILD_FLAGS=/MIR /MT:8 /R:1 /W:0 /NP /ETA"
        set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "$Recycle.Bin""
        goto :eof
    )

    set "_BUILD_FLAGS=!_BUILD_FLAGS! /XD "$Recycle.Bin""
    goto :eof
