@echo off
:: ================================================================
:: ROBOSYNC v2.0.0 — PRODUCTION BACKUP & RESTORE UTILITY
:: Engine : Robocopy  |  Auth : Net Use  |  Format : Pure CMD
::
:: ================================================================
:: VARIABLE SCOPING CONTRACT (3-Tier System)
:: ================================================================
::
:: TIER 1 — GLOBAL (Set once at startup. Never cleared.)
::   APP_VERSION    : Version string
::   SCRIPT_DIR     : %~dp0 (thu muc goc)
::   LIBS           : %SCRIPT_DIR%lib (duong dan module)
::   LOG_DIR        : %SCRIPT_DIR%logs
::
:: TIER 2 — PIPELINE (Set per-job. Cleared at :MainMenu.)
::   BACKUP_MODE    : PUSH / PULL / LOCAL
::   NET_TYPE       : DIRECT / DHCP
::   DEST_IP        : IP may dich
::   DEST_SHARE     : Ten thu muc share
::   NET_USER       : Username xac thuc
::   NET_PASS       : Password (ZERO-LEAK: xoa ngay sau net use)
::   NETWORK_PATH   : \\IP\Share (full UNC)
::   BACKUP_DEST    : Duong dan dich cuoi cung
::   NET_IFACE      : Interface da set static (de phuc hoi DHCP)
::   NET_LOCAL_IP   : IP tinh da set
::
:: TIER 3 — SELECTED (Set khi user chon source. Cleared o loop.)
::   SELECTED_SRC   : Duong dan nguon da chon
::   SELECTED_NAME  : Ten folder dich
::   SELECTED_TYPE  : PROFILE / PARTITION / CUSTOM
::   FINAL_DEST     : Duong dan dich da tinh toan
::
:: LOCAL (Chi ton tai trong function, dung _prefix)
::   _rc_src, _idx, _btype, _p, _n, _custom, v.v.
::
:: ================================================================

:: --- UNICODE SUPPORT ---
:: chcp 65001 cho phep hien thi va xu ly file/folder tieng Viet
chcp 65001 >nul 2>&1

:: --- ADMIN CHECK (bat buoc cho C$, D$, profile access) ---
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
:: TIER 1: GLOBALS (set once, never cleared)
:: ================================================================
setlocal enabledelayedexpansion

set "APP_VERSION=v2.0.0"
set "SCRIPT_DIR=%~dp0"
set "LIBS=%SCRIPT_DIR%lib"
set "LOG_DIR=%SCRIPT_DIR%logs"
set "NET_STATUS=NOT_CONNECTED"

:: Fail-fast: Kiem tra modules
for %%M in (engine network discover ui) do (
    if not exist "%LIBS%\%%M.bat" (
        echo  [!!] Missing module: lib\%%M.bat
        pause
        exit /b 1
    )
)

REM ================================================================
REM MAIN MENU
REM Note: Network session vars (DEST_IP, NET_USER, NETWORK_PATH,
REM       NET_STATUS, NET_TYPE, NET_IFACE, NET_LOCAL_IP) are NOT
REM       cleared here — they persist across backup operations.
REM       Only backup pipeline vars (Tier 2b + Tier 3) are cleared.
REM ================================================================
:MainMenu
    :: --- Clear Pipeline vars (Tier 2b: per-job) ---
    set "BACKUP_MODE="
    set "BACKUP_DEST="
    set "NET_PASS="
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
:: DISPLAY: Main Menu (separated from logic per cmdToolForHelpdesk)
:: ================================================================
:displayMainMenu
    call "%LIBS%\ui.bat" fn_banner

    echo        ========================================================
    echo        [1] Backup PUSH          - Local to Remote     : Press 1
    echo        [2] Backup PULL          - Remote to Local     : Press 2
    echo        [3] Backup LOCAL         - Local to Local      : Press 3
    echo        [4] Restore Profile      - Recover data        : Press 4
    echo        [5] Network Setup        - Configure network   : Press 5
    echo        [6] Exit                                       : Press 6
    echo        ========================================================
    call "%LIBS%\ui.bat" fn_status_bar
    echo.
    goto :eof

:: ================================================================
:: NETWORK SETUP MENU (Optional — user-driven)
:: ================================================================
:NetworkMenu
    cls
    echo.
    echo  [>>] NETWORK SETUP
    call "%LIBS%\ui.bat" fn_separator
    call "%LIBS%\network.bat" fn_show_status
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
    call "%LIBS%\network.bat" fn_setup_direct_cable
    if "!DIRECT_SETUP_OK!"=="0" (
        call "%LIBS%\ui.bat" fn_pause_msg "Direct cable setup failed."
        goto :NetworkMenu
    )
    call "%LIBS%\network.bat" fn_input_credentials
    if "!INPUT_OK!"=="0" (
        call "%LIBS%\ui.bat" fn_pause_msg "Invalid input."
        goto :NetworkMenu
    )
    call "%LIBS%\network.bat" fn_test_connection "!DEST_IP!"
    if "!NET_PING_OK!"=="0" (
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :NetworkMenu
    )
    call "%LIBS%\network.bat" fn_map_credentials "!DEST_IP!" "!NET_USER!" "!NET_PASS!"
    set "NET_PASS="
    if "!NET_MAP_OK!"=="0" (
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :NetworkMenu
    )
    set "NETWORK_PATH=\\!DEST_IP!\!DEST_SHARE!"
    call "%LIBS%\ui.bat" fn_pause_msg "[OK] Network connected successfully."
    goto :NetworkMenu

:NetworkConnectDHCP
    set "NET_TYPE=DHCP"
    call "%LIBS%\network.bat" fn_input_credentials
    if "!INPUT_OK!"=="0" (
        call "%LIBS%\ui.bat" fn_pause_msg "Invalid input."
        goto :NetworkMenu
    )
    call "%LIBS%\network.bat" fn_test_connection "!DEST_IP!"
    if "!NET_PING_OK!"=="0" (
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :NetworkMenu
    )
    call "%LIBS%\network.bat" fn_map_credentials "!DEST_IP!" "!NET_USER!" "!NET_PASS!"
    set "NET_PASS="
    if "!NET_MAP_OK!"=="0" (
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :NetworkMenu
    )
    set "NETWORK_PATH=\\!DEST_IP!\!DEST_SHARE!"
    call "%LIBS%\ui.bat" fn_pause_msg "[OK] Network connected successfully."
    goto :NetworkMenu

:NetworkDisconnect
    call "%LIBS%\network.bat" fn_cleanup_all
    set "DEST_IP="
    set "DEST_SHARE="
    set "NET_USER="
    set "NET_PASS="
    set "NETWORK_PATH="
    set "NET_TYPE="
    call "%LIBS%\ui.bat" fn_pause_msg "[OK] Disconnected. All connections cleared."
    goto :NetworkMenu

:NetworkShowStatus
    cls
    echo.
    call "%LIBS%\network.bat" fn_show_status
    call "%LIBS%\ui.bat" fn_pause_msg
    goto :NetworkMenu

:: ================================================================
:: NETWORK SETUP (Chung cho PUSH va PULL)
:: Flow: Chon loai mang -> Setup IP (neu Direct) -> Input creds
::       -> Ping -> Map credentials
:: ================================================================
:NetworkSetup
    :: Step 1: Chon loai ket noi
    call "%LIBS%\network.bat" fn_select_network_type

    :: Step 1b: Handle cancel
    if "!NET_TYPE!"=="CANCEL" goto :MainMenu

    :: Step 2: If Direct Cable, setup Static IP first
    if "!NET_TYPE!"=="DIRECT" (
        call "%LIBS%\network.bat" fn_setup_direct_cable
        if "!DIRECT_SETUP_OK!"=="0" (
            call "%LIBS%\ui.bat" fn_pause_msg "Direct cable setup failed."
            goto :MainMenu
        )
    )

    :: Step 3: Nhap Share / User / Pass
    call "%LIBS%\network.bat" fn_input_credentials
    if "!INPUT_OK!"=="0" (
        call "%LIBS%\ui.bat" fn_pause_msg "Invalid input."
        goto :CleanupAndMenu
    )

    :: Step 4: Ping
    call "%LIBS%\network.bat" fn_test_connection "!DEST_IP!"
    if "!NET_PING_OK!"=="0" (
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :CleanupAndMenu
    )

    :: Step 5: Map credentials
    call "%LIBS%\network.bat" fn_map_credentials "!DEST_IP!" "!NET_USER!" "!NET_PASS!"
    :: ZERO-LEAK: Xoa pass NGAY
    set "NET_PASS="
    if "!NET_MAP_OK!"=="0" (
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :CleanupAndMenu
    )
    goto :eof

:: ================================================================
:: MODE 1: PUSH (Local -> Remote)
:: ================================================================
:ModePush
    set "BACKUP_MODE=PUSH"
    title RoboSync - PUSH
    cls
    echo.
    echo  [^>^>] BACKUP PUSH (Local -^> Remote)
    call "%LIBS%\ui.bat" fn_separator

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
    title RoboSync - PULL
    cls
    echo.
    echo  [^>^>] BACKUP PULL (Remote -^> Local)
    call "%LIBS%\ui.bat" fn_separator

    REM Reuse existing network session if available (EC-2.1)
    if "!NET_STATUS!"=="CONNECTED" (
        echo  [OK] Using existing connection: !NETWORK_PATH!
        echo.
        choice /n /c YN /m "  Continue with this connection? [Y/N]: "
        if !errorlevel! equ 2 call :NetworkSetup
    ) else (
        call :NetworkSetup
    )

    :: Nhap local dest
    echo.
    set "BACKUP_DEST="
    set /p "BACKUP_DEST=  Local save path (e.g. D:\Restore): "
    if "!BACKUP_DEST!"=="" (
        echo  [!!] Path is empty. Cancelled.
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
    title RoboSync - LOCAL
    cls
    echo.
    echo  [^>^>] BACKUP LOCAL (Local -^> Local)
    call "%LIBS%\ui.bat" fn_separator
    echo.
    set "BACKUP_DEST="
    set /p "BACKUP_DEST=  Destination path (e.g. E:\Backup): "
    if "!BACKUP_DEST!"=="" (
        echo  [!!] Path is empty. Cancelled.
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :MainMenu
    )
    goto :SelectSource

:: ================================================================
:: SELECT SOURCE (PUSH + LOCAL)
:: ================================================================
:SelectSource
    cls
    echo.
    echo  [^>^>] SELECT BACKUP SOURCE
    echo  [--] Destination: !BACKUP_DEST!
    call "%LIBS%\ui.bat" fn_separator
    echo.

    call "%LIBS%\discover.bat" fn_detect_profiles
    call "%LIBS%\discover.bat" fn_detect_partitions

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
            REM Dung dung type: USB hoac PARTITION (Fixed)
            if /i "!_dt!"=="USB" (
                set "SRC_!_TOTAL!_TYPE=USB"
            ) else (
                set "SRC_!_TOTAL!_TYPE=PARTITION"
            )
            echo   [!_TOTAL!] !_n!  ^|  !_p!
        )
        echo.
    )

    echo   --- TUY CHON ---
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
    call "%LIBS%\ui.bat" fn_separator

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
            call "%LIBS%\engine.bat" fn_run_robocopy "!SELECTED_SRC!" "!FINAL_DEST!" "PROFILE"
        )
        call "%LIBS%\ui.bat" fn_pause_msg "[OK] All Profiles backed up."
        goto :SelectSource
    )

    if "!_SC!"=="!_IDX_ALL_D!" (
        for /l %%i in (1,1,!PART_COUNT!) do (
            call set "SELECTED_SRC=%%PART_%%i_PATH%%"
            call set "SELECTED_NAME=%%PART_%%i_NAME%%"
            set "FINAL_DEST=!BACKUP_DEST!\!SELECTED_NAME!"
            if not exist "!FINAL_DEST!" mkdir "!FINAL_DEST!" 2>nul
            call "%LIBS%\engine.bat" fn_run_robocopy "!SELECTED_SRC!" "!FINAL_DEST!" "PARTITION"
        )
        call "%LIBS%\ui.bat" fn_pause_msg "[OK] All Partitions backed up."
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
:: SELECT REMOTE SOURCE (PULL mode)
:: ================================================================
:SelectRemoteSource
    cls
    echo.
    echo  [^>^>] SELECT REMOTE SOURCE
    echo  [--] Remote: !REMOTE_SOURCE!
    echo  [--] Local:  !BACKUP_DEST!
    call "%LIBS%\ui.bat" fn_separator
    echo.

    call "%LIBS%\discover.bat" fn_detect_remote "!REMOTE_SOURCE!"

    set /a _TOTAL=0
    if !REMOTE_COUNT! gtr 0 (
        echo   --- THU MUC ---
        for /l %%i in (1,1,!REMOTE_COUNT!) do (
            set /a _TOTAL+=1
            call set "_rname=%%REMOTE_%%i_NAME%%"
            echo   [!_TOTAL!] !_rname!
        )
        echo.
    )

    echo   --- TUY CHON ---
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
        call "%LIBS%\engine.bat" fn_run_robocopy "!REMOTE_SOURCE!" "!BACKUP_DEST!" "CUSTOM"
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :SelectRemoteSource
    )

    if "!_RC!"=="!_IDX_CUSTOM!" (
        set "_custom="
        set /p "_custom=  Remote path: "
        if "!_custom!"=="" goto :SelectRemoteSource
        call "%LIBS%\engine.bat" fn_run_robocopy "!_custom!" "!BACKUP_DEST!" "CUSTOM"
        call "%LIBS%\ui.bat" fn_pause_msg
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
    call "%LIBS%\engine.bat" fn_run_robocopy "!SELECTED_SRC!" "!_rdst!" "CUSTOM"
    call "%LIBS%\ui.bat" fn_pause_msg
    goto :SelectRemoteSource

:: ================================================================
:: CONFIRM AND RUN (unified)
:: ================================================================
:ConfirmAndRun
    set "FINAL_DEST=!BACKUP_DEST!\!SELECTED_NAME!"
    echo.
    echo  [^>^>] CONFIRM BACKUP
    call "%LIBS%\ui.bat" fn_separator
    echo  [--] Source : !SELECTED_SRC!
    echo  [--] Dest   : !FINAL_DEST!
    echo  [--] Type   : !SELECTED_TYPE!
    call "%LIBS%\ui.bat" fn_separator
    echo.
    choice /n /c YN /m "  Run backup? [Y/N]: "
    if !errorlevel! equ 2 goto :SelectSource

    if not exist "!FINAL_DEST!" mkdir "!FINAL_DEST!" 2>nul
    call "%LIBS%\engine.bat" fn_run_robocopy "!SELECTED_SRC!" "!FINAL_DEST!" "!SELECTED_TYPE!"
    call "%LIBS%\ui.bat" fn_pause_msg
    goto :SelectSource

:: ================================================================
:: MODE 4: RESTORE USER PROFILE
:: Flow: Chon source backup -> Chon che do restore -> Thuc thi
:: ================================================================
:ModeRestore
    set "BACKUP_MODE=RESTORE"
    title RoboSync - RESTORE
    cls
    echo.
    echo  [^>^>] RESTORE USER PROFILE
    call "%LIBS%\ui.bat" fn_separator
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
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :ModeRestore
    )
    if not exist "!RESTORE_BASE!" (
        echo  [!!] Path does not exist: !RESTORE_BASE!
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :ModeRestore
    )
    goto :SelectRestoreSource

:RestoreFromNetwork
    call :NetworkSetup
    set "RESTORE_BASE=!NETWORK_PATH!"
    goto :SelectRestoreSource

:: ================================================================
:: SELECT RESTORE SOURCE (chon backup profile)
:: ================================================================
:SelectRestoreSource
    cls
    echo.
    echo  [^>^>] SELECT BACKUP PROFILE TO RESTORE
    echo  [--] Folder: !RESTORE_BASE!
    call "%LIBS%\ui.bat" fn_separator
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
        call "%LIBS%\ui.bat" fn_pause_msg
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

    :: Chon che do restore
    echo.
    echo  [^>^>] SELECT RESTORE MODE
    call "%LIBS%\ui.bat" fn_separator
    echo  [--] Source: !SELECTED_NAME!
    echo.
    echo   [A] Restore into existing Profile
    echo       Merge subfolders: Desktop, Documents, Downloads...
    echo       Does NOT overwrite ntuser.dat, does NOT delete old files.
    echo.
    echo   [B] Restore to designated path
    echo       Full mirror copy to a folder you specify.
    echo.
    echo   [0] Go back
    echo.
    choice /n /c AB0 /m "  Choose [A/B/0]: "
    if !errorlevel! equ 3 goto :SelectRestoreSource
    if !errorlevel! equ 2 goto :RestoreToPath
    if !errorlevel! equ 1 goto :RestoreIntoProfile
    goto :SelectRestoreSource

:: ================================================================
:: UC4: RESTORE INTO EXISTING PROFILE (Subfolder Mapping)
:: Dung /E (merge) KHONG /MIR (tranh xoa file moi cua user)
:: ================================================================
:RestoreIntoProfile
    cls
    echo.
    echo  [^>^>] RESTORE INTO EXISTING PROFILE
    echo  [--] Backup: !SELECTED_SRC!
    call "%LIBS%\ui.bat" fn_separator
    echo.

    :: Phat hien profiles tren may
    call "%LIBS%\discover.bat" fn_detect_profiles
    if !PROFILE_COUNT! equ 0 (
        echo  [!!] No profiles found on this PC.
        call "%LIBS%\ui.bat" fn_pause_msg
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
    call set "_dest_name=%%PROFILE_!_RP!_NAME%%"
    if "!_dest_profile!"=="" (
        echo  [!!] Invalid selection.
        timeout /t 2 >nul
        goto :RestoreIntoProfile
    )

    :: Phat hien subdirs co the restore
    call "%LIBS%\discover.bat" fn_detect_profile_subdirs "!SELECTED_SRC!"
    if !SUBDIR_COUNT! equ 0 (
        echo  [!!] No subfolders found in backup.
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :SelectRestoreSource
    )

    :: Xac nhan
    echo.
    echo  [^>^>] CONFIRM RESTORE
    call "%LIBS%\ui.bat" fn_separator
    echo  [--] Backup source : !SELECTED_SRC!
    echo  [--] Restore into  : !_dest_profile!
    echo  [--] Mode          : MERGE ^(/E - keeps existing files^)
    echo  [--] Folders:
    for /l %%i in (1,1,!SUBDIR_COUNT!) do (
        call set "_sd=%%SUBDIR_%%i_NAME%%"
        echo       - !_sd!
    )
    call "%LIBS%\ui.bat" fn_separator
    echo.
    choice /n /c YN /m "  Start restore? [Y/N]: "
    if !errorlevel! equ 2 goto :SelectRestoreSource

    :: Thuc thi tung subfolder
    echo.
    for /l %%i in (1,1,!SUBDIR_COUNT!) do (
        call set "_sd=%%SUBDIR_%%i_NAME%%"
        set "_s=!SELECTED_SRC!\!_sd!"
        set "_d=!_dest_profile!\!_sd!"
        echo  [--] Restoring: !_sd!
        if not exist "!_d!" mkdir "!_d!" 2>nul
        call "%LIBS%\engine.bat" fn_run_robocopy "!_s!" "!_d!" "RESTORE_MERGE"
    )

    echo.
    call "%LIBS%\ui.bat" fn_pause_msg "[OK] Restore hoan tat."
    goto :SelectRestoreSource

:: ================================================================
:: UC5: RESTORE TO DESIGNATED PATH (Full Mirror)
:: ================================================================
:RestoreToPath
    echo.
    set "_rdest="
    set /p "_rdest=  Destination path (e.g. D:\Restored\Admin): "
    if "!_rdest!"=="" (
        echo  [!!] Duong dan trong.
        call "%LIBS%\ui.bat" fn_pause_msg
        goto :SelectRestoreSource
    )

    echo.
    echo  [^>^>] CONFIRM RESTORE
    call "%LIBS%\ui.bat" fn_separator
    echo  [--] Source : !SELECTED_SRC!
    echo  [--] Dest   : !_rdest!
    echo  [--] Mode   : MIRROR ^(/MIR - full copy^)
    call "%LIBS%\ui.bat" fn_separator
    echo.
    choice /n /c YN /m "  Start restore? [Y/N]: "
    if !errorlevel! equ 2 goto :SelectRestoreSource

    call "%LIBS%\engine.bat" fn_run_robocopy "!SELECTED_SRC!" "!_rdest!" "RESTORE_MIRROR"

    echo.
    call "%LIBS%\ui.bat" fn_pause_msg "[OK] Restore hoan tat."
    goto :SelectRestoreSource

:: ================================================================
:: CLEANUP AND MENU
:: ================================================================
:CleanupAndMenu
    if defined DEST_IP (
        call "%LIBS%\network.bat" fn_unmap_credentials "!DEST_IP!"
    )
    if defined NET_IFACE (
        call "%LIBS%\network.bat" fn_restore_dhcp
    )
    goto :MainMenu

:: ================================================================
:: EXIT
:: ================================================================
:ExitApp
    cls
    echo.
    call "%LIBS%\network.bat" fn_cleanup_all
    echo.
    echo  Thank you for using RoboSync!
    echo.
    timeout /t 2 >nul
    endlocal
    exit /b 0
